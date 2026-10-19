import Foundation
import Observation
import SkovaderEngine

enum LocationAuthorization: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}

/// Telefonens position, bakom ett protokoll så att WeatherStore kan testas.
@MainActor
protocol LocationProviding: AnyObject {
    var authorization: LocationAuthorization { get }
    /// Frågar användaren om tillstånd om det inte redan är besvarat.
    func requestAuthorization() async -> LocationAuthorization
    func currentCoordinate() async throws -> Coordinate
}

/// Håller dagens prognos (F6): hämtar vid appstart och neddragning, cachar
/// i en timme och visar senaste cachen när det inte går att hämta.
@Observable
@MainActor
final class WeatherStore {
    enum Problem: Equatable {
        /// Användaren har inte svarat på frågan om plats.
        case needsLocationPermission
        /// Platstillstånd saknas och ingen ort är vald.
        case needsPlace
        case locationUnavailable
        /// Kunde inte hämta; visar senaste prognosen.
        case offline
        /// Kunde inte hämta och har ingen sparad prognos.
        case noForecast
    }

    static let cacheLifetime: TimeInterval = 60 * 60

    private(set) var forecast: WeatherForecast?
    private(set) var isLoading = false
    private(set) var problem: Problem?

    private let service: WeatherService
    private let location: LocationProviding
    private let cache: WeatherCache
    private let now: () -> Date

    init(
        service: WeatherService,
        location: LocationProviding,
        cache: WeatherCache,
        now: @escaping () -> Date = { Date() }
    ) {
        self.service = service
        self.location = location
        self.cache = cache
        self.now = now
        self.forecast = cache.load()
    }

    var isLocationDenied: Bool {
        location.authorization == .denied
    }

    /// Frågar om platstillstånd. Sant om appen får använda platsen.
    func requestLocationAuthorization() async -> Bool {
        await location.requestAuthorization() == .authorized
    }

    /// Dagens väder 07–18, om prognosen täcker idag.
    func dayWeather(config: RecommendationConfig = .standard) -> DayWeather? {
        forecast?.dayWeather(on: now(), config: config)
    }

    func condition(config: RecommendationConfig = .standard) -> WeatherCondition? {
        guard let forecast, let day = dayWeather(config: config) else { return nil }
        return WeatherCondition.forDay(day, codes: forecast.weatherCodes(on: now(), config: config), config: config)
    }

    /// Hämtar en ny prognos om cachen är äldre än en timme, gäller en annan
    /// plats eller inte täcker idag. `force` hämtar alltid (neddragning).
    func refresh(preference: LocationPreference, force: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        guard let coordinate = await coordinate(for: preference) else { return }

        if !force, let forecast, forecast.coordinate == coordinate,
           now().timeIntervalSince(forecast.fetchedAt) < Self.cacheLifetime,
           forecast.dayWeather(on: now()) != nil {
            problem = nil
            return
        }

        do {
            let fresh = try await service.forecast(for: coordinate)
            forecast = fresh
            problem = nil
            try? cache.save(fresh)
        } catch {
            problem = forecast == nil ? .noForecast : .offline
        }
    }

    private func coordinate(for preference: LocationPreference) async -> Coordinate? {
        switch preference {
        case .manual(let place):
            guard let place else {
                problem = .needsPlace
                return nil
            }
            return place.coordinate
        case .automatic:
            switch location.authorization {
            case .notDetermined:
                // Frågan ställs bara när användaren själv trycker på en knapp.
                problem = .needsLocationPermission
                return nil
            case .denied:
                problem = .needsPlace
                return nil
            case .authorized:
                do {
                    return try await location.currentCoordinate()
                } catch {
                    if let last = forecast?.coordinate { return last }
                    problem = .locationUnavailable
                    return nil
                }
            }
        }
    }
}
