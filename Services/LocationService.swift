import CoreLocation

/// Telefonens position via CoreLocation, "När appen används". Noggrannhet
/// på kilometernivå räcker – positionen avrundas ändå till 2 decimaler.
@MainActor
final class LocationService: NSObject, LocationProviding, CLLocationManagerDelegate {
    enum LocationError: Error {
        case timeout
        case superseded
    }

    private let manager = CLLocationManager()
    private var authorizationContinuations: [CheckedContinuation<LocationAuthorization, Never>] = []
    private var locationContinuation: CheckedContinuation<Coordinate, Error>?
    private var locationRequestID = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var authorization: LocationAuthorization {
        Self.authorization(from: manager.authorizationStatus)
    }

    func requestAuthorization() async -> LocationAuthorization {
        let current = authorization
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            authorizationContinuations.append(continuation)
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentCoordinate() async throws -> Coordinate {
        try await withCheckedThrowingContinuation { continuation in
            finishLocation(with: .failure(LocationError.superseded))
            locationRequestID += 1
            let requestID = locationRequestID
            locationContinuation = continuation
            manager.requestLocation()

            Task { [weak self] in
                try? await Task.sleep(for: .seconds(15))
                guard let self, self.locationRequestID == requestID else { return }
                self.finishLocation(with: .failure(LocationError.timeout))
            }
        }
    }

    private func finishLocation(with result: Result<Coordinate, Error>) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(with: result)
    }

    private static func authorization(from status: CLAuthorizationStatus) -> LocationAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: .authorized
        default: .denied
        }
    }

    // MARK: CLLocationManagerDelegate (anropas på huvudtråden)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            let authorization = Self.authorization(from: status)
            guard authorization != .notDetermined else { return }
            let waiting = authorizationContinuations
            authorizationContinuations.removeAll()
            for continuation in waiting {
                continuation.resume(returning: authorization)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        MainActor.assumeIsolated {
            finishLocation(with: .success(coordinate))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let lastKnown = manager.location.map {
            Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        }
        MainActor.assumeIsolated {
            if let lastKnown {
                finishLocation(with: .success(lastKnown))
            } else {
                finishLocation(with: .failure(error))
            }
        }
    }
}

/// Sök ort med namn (F9) via CLGeocoder. Bara söktexten skickas till Apple.
enum PlaceSearch {
    static func search(_ query: String) async throws -> [Place] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        do {
            let placemarks = try await CLGeocoder().geocodeAddressString(trimmed)
            return placemarks.compactMap(Place.init(placemark:))
        } catch let error as CLError where error.code == .geocodeFoundNoResult {
            return []
        }
    }
}

extension Place {
    init?(placemark: CLPlacemark) {
        guard let location = placemark.location,
              let name = placemark.locality ?? placemark.name, !name.isEmpty else { return nil }
        let detail = [placemark.administrativeArea, placemark.country]
            .compactMap { $0 }
            .filter { $0 != name }
            .joined(separator: ", ")
        self.init(
            name: name,
            detail: detail.isEmpty ? nil : detail,
            coordinate: Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        )
    }
}

extension WeatherStore {
    /// Den riktiga kopplingen: Open-Meteo, CoreLocation och cachen på disk.
    static func live() -> WeatherStore {
        WeatherStore(service: OpenMeteoWeatherService(), location: LocationService(), cache: .shared)
    }
}
