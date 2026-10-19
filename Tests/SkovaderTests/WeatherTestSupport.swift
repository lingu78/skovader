import Foundation
@testable import Skovader

let stockholm: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
    return calendar
}()

func stockholmDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    stockholm.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

let testCoordinate = Coordinate(latitude: 59.33, longitude: 18.07)

/// Prognos med 24 timmar för dagen `day` (Stockholmstid).
func makeForecast(
    coordinate: Coordinate = testCoordinate,
    fetchedAt: Date,
    day: Date,
    temperature: Double = 10,
    rain: Double = 0,
    weatherCode: Int = 1
) -> WeatherForecast {
    let start = stockholm.startOfDay(for: day)
    let hours = (0..<24).map { hour in
        ForecastHour(
            time: stockholm.date(byAdding: .hour, value: hour, to: start)!,
            apparentTemperature: temperature,
            precipitation: rain,
            rain: rain,
            showers: 0,
            snowfall: 0,
            windSpeed: 3,
            weatherCode: weatherCode
        )
    }
    return WeatherForecast(coordinate: coordinate, timeZoneIdentifier: "Europe/Stockholm", fetchedAt: fetchedAt, hours: hours)
}

func makeTemporaryWeatherCache() -> WeatherCache {
    WeatherCache(fileURL: FileManager.default.temporaryDirectory
        .appending(path: "SkovaderTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        .appending(path: "weather.json", directoryHint: .notDirectory))
}

struct TestError: Error {}

final class FakeWeatherService: WeatherService {
    var result: Result<WeatherForecast, Error>
    private(set) var requested: [Coordinate] = []

    init(result: Result<WeatherForecast, Error>) {
        self.result = result
    }

    func forecast(for coordinate: Coordinate) async throws -> WeatherForecast {
        requested.append(coordinate)
        return try result.get()
    }
}

@MainActor
final class FakeLocation: LocationProviding {
    var authorization: LocationAuthorization
    var coordinate: Coordinate?
    private(set) var authorizationRequests = 0

    init(authorization: LocationAuthorization = .authorized, coordinate: Coordinate? = testCoordinate) {
        self.authorization = authorization
        self.coordinate = coordinate
    }

    func requestAuthorization() async -> LocationAuthorization {
        authorizationRequests += 1
        return authorization
    }

    func currentCoordinate() async throws -> Coordinate {
        guard let coordinate else { throw TestError() }
        return coordinate
    }
}

/// Open-Meteo-svar med 48 timmar från 19 oktober 2026 kl. 00 lokal tid.
/// Temperaturen är timmen själv; timme 30 saknar temperatur.
func openMeteoFixture() -> Data {
    let times = (0..<48).map { index -> String in
        let day = 19 + index / 24
        return String(format: "2026-10-%02dT%02d:00", day, index % 24)
    }
    let temperatures: [Any] = (0..<48).map { $0 == 30 ? NSNull() : Double($0 % 24) as Any }
    let json: [String: Any] = [
        "latitude": 59.34,
        "longitude": 18.06,
        "utc_offset_seconds": 7200,
        "timezone": "Europe/Stockholm",
        "timezone_abbreviation": "GMT+2",
        "hourly_units": ["time": "iso8601"],
        "hourly": [
            "time": times,
            "apparent_temperature": temperatures,
            "precipitation": Array(repeating: 0.5, count: 48),
            "rain": Array(repeating: 0.3, count: 48),
            "showers": Array(repeating: 0.2, count: 48),
            "snowfall": Array(repeating: 0.0, count: 48),
            "wind_speed_10m": (0..<48).map { Double($0 % 24) / 4 },
            "weather_code": Array(repeating: 61, count: 48),
        ] as [String: Any],
    ]
    return try! JSONSerialization.data(withJSONObject: json)
}
