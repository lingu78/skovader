import Foundation
import SkovaderEngine
#if canImport(FoundationNetworking)
import FoundationNetworking  // URLSession i Linux, där väderlogiken också testas
#endif

/// En position avrundad till 2 decimaler (ca 1 km). Bara sådana skickas
/// till vädertjänsten.
struct Coordinate: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = (latitude * 100).rounded() / 100
        self.longitude = (longitude * 100).rounded() / 100
    }
}

/// En timme ur en sparad prognos.
struct ForecastHour: Codable, Equatable, Sendable {
    var time: Date
    var apparentTemperature: Double
    var precipitation: Double
    var rain: Double
    var showers: Double
    var snowfall: Double
    var windSpeed: Double
    /// WMO-kod, används bara för väderikonen.
    var weatherCode: Int?

    var engineHour: HourlyWeather {
        HourlyWeather(
            time: time,
            apparentTemperature: apparentTemperature,
            precipitationMM: precipitation,
            rainMM: rain + showers,
            snowfallCM: snowfall,
            windSpeed: windSpeed
        )
    }
}

/// Prognosen som hämtats för en position. Sparas i cachen som JSON.
struct WeatherForecast: Codable, Equatable, Sendable {
    var coordinate: Coordinate
    var timeZoneIdentifier: String
    var fetchedAt: Date
    var hours: [ForecastHour]

    /// Kalender i platsens tidszon, så att 07–18 gäller lokal tid där.
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return calendar
    }

    func dayWeather(on day: Date, config: RecommendationConfig = .standard) -> DayWeather? {
        DayWeather.summarizing(hours.map(\.engineHour), on: day, calendar: calendar, config: config)
    }

    /// WMO-koderna för timmarna 07–18, för väderikonen.
    func weatherCodes(on day: Date, config: RecommendationConfig = .standard) -> [Int] {
        let calendar = calendar
        let window = config.weatherWindowStartHour...config.weatherWindowEndHour
        return hours
            .filter { calendar.isDate($0.time, inSameDayAs: day) && window.contains(calendar.component(.hour, from: $0.time)) }
            .compactMap(\.weatherCode)
    }
}

/// Vädertjänsten bakom ett protokoll, så att Open-Meteo kan bytas mot
/// t.ex. WeatherKit eller MET Norway.
protocol WeatherService {
    func forecast(for coordinate: Coordinate) async throws -> WeatherForecast
}

enum WeatherServiceError: Error, Equatable {
    case badResponse(statusCode: Int)
    case invalidData
}

/// Open-Meteo: gratis, ingen API-nyckel. https://open-meteo.com
struct OpenMeteoWeatherService: WeatherService {
    var session: URLSession = .shared

    static let endpoint = URL(string: "https://api.open-meteo.com/v1/forecast")!
    static let hourlyFields = ["apparent_temperature", "precipitation", "rain", "showers", "snowfall", "wind_speed_10m", "weather_code"]

    func forecast(for coordinate: Coordinate) async throws -> WeatherForecast {
        let (data, response) = try await session.data(from: Self.url(for: coordinate))
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw WeatherServiceError.badResponse(statusCode: http.statusCode)
        }
        return try Self.decode(data, coordinate: coordinate, fetchedAt: Date())
    }

    /// Idag och imorgon, så att en prognos hämtad på kvällen räcker offline
    /// nästa morgon.
    static func url(for coordinate: Coordinate) -> URL {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", coordinate.longitude)),
            URLQueryItem(name: "hourly", value: hourlyFields.joined(separator: ",")),
            URLQueryItem(name: "wind_speed_unit", value: "ms"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "2"),
        ]
        return components.url!
    }

    static func decode(_ data: Data, coordinate: Coordinate, fetchedAt: Date) throws -> WeatherForecast {
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw WeatherServiceError.invalidData
        }
        let timeZone = TimeZone(identifier: response.timezone)
            ?? TimeZone(secondsFromGMT: response.utcOffsetSeconds)
            ?? .current

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        let hourly = response.hourly
        var hours: [ForecastHour] = []
        for (index, timeString) in hourly.time.enumerated() {
            guard let time = formatter.date(from: timeString),
                  let temperature = hourly.apparentTemperature.value(at: index) else { continue }
            hours.append(ForecastHour(
                time: time,
                apparentTemperature: temperature,
                precipitation: hourly.precipitation.value(at: index) ?? 0,
                rain: hourly.rain.value(at: index) ?? 0,
                showers: hourly.showers.value(at: index) ?? 0,
                snowfall: hourly.snowfall.value(at: index) ?? 0,
                windSpeed: hourly.windSpeed.value(at: index) ?? 0,
                weatherCode: hourly.weatherCode.value(at: index)
            ))
        }
        guard !hours.isEmpty else { throw WeatherServiceError.invalidData }

        return WeatherForecast(
            coordinate: coordinate,
            timeZoneIdentifier: timeZone.identifier,
            fetchedAt: fetchedAt,
            hours: hours
        )
    }

    private struct Response: Decodable {
        let timezone: String
        let utcOffsetSeconds: Int
        let hourly: Hourly

        enum CodingKeys: String, CodingKey {
            case timezone
            case utcOffsetSeconds = "utc_offset_seconds"
            case hourly
        }
    }

    private struct Hourly: Decodable {
        let time: [String]
        let apparentTemperature: [Double?]
        let precipitation: [Double?]
        let rain: [Double?]
        let showers: [Double?]
        let snowfall: [Double?]
        let windSpeed: [Double?]
        let weatherCode: [Int?]

        enum CodingKeys: String, CodingKey {
            case time
            case apparentTemperature = "apparent_temperature"
            case precipitation
            case rain
            case showers
            case snowfall
            case windSpeed = "wind_speed_10m"
            case weatherCode = "weather_code"
        }
    }
}

private extension Array {
    func value<T>(at index: Int) -> T? where Element == T? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Senast hämtade prognos, sparad på disk så att appen fungerar offline (F6).
struct WeatherCache {
    let fileURL: URL

    static let shared = WeatherCache(
        fileURL: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "weather.json", directoryHint: .notDirectory)
    )

    func load() -> WeatherForecast? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(WeatherForecast.self, from: data)
    }

    func save(_ forecast: WeatherForecast) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(forecast).write(to: fileURL, options: .atomic)
    }
}
