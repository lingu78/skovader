import XCTest
import SkovaderEngine
@testable import Skovader

final class WeatherServiceTests: XCTestCase {
    func testCoordinatesAreRoundedToTwoDecimals() {
        let coordinate = Coordinate(latitude: 59.334_6, longitude: -0.127_8)

        XCTAssertEqual(coordinate.latitude, 59.33)
        XCTAssertEqual(coordinate.longitude, -0.13)
    }

    func testURLSendsOnlyRoundedCoordinatesAndNeededFields() throws {
        let url = OpenMeteoWeatherService.url(for: Coordinate(latitude: 59.334_591, longitude: 18.068_7))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(url.host, "api.open-meteo.com")
        XCTAssertEqual(query["latitude"], "59.33")
        XCTAssertEqual(query["longitude"], "18.07")
        XCTAssertEqual(query["hourly"], "apparent_temperature,precipitation,rain,showers,snowfall,wind_speed_10m,weather_code")
        XCTAssertEqual(query["wind_speed_unit"], "ms")
        XCTAssertEqual(query["timezone"], "auto")
        XCTAssertEqual(query["forecast_days"], "2")
        XCTAssertEqual(Set(query.keys).count, 6)
    }

    func testDecodeReadsLocalTimesAndSkipsHoursWithoutTemperature() throws {
        let fetchedAt = stockholmDate(2026, 10, 19, 6, 45)

        let forecast = try OpenMeteoWeatherService.decode(openMeteoFixture(), coordinate: testCoordinate, fetchedAt: fetchedAt)

        XCTAssertEqual(forecast.hours.count, 47)
        XCTAssertEqual(forecast.hours.first?.time, stockholmDate(2026, 10, 19, 0))
        XCTAssertEqual(forecast.hours.last?.time, stockholmDate(2026, 10, 20, 23))
        XCTAssertEqual(forecast.timeZoneIdentifier, "Europe/Stockholm")
        XCTAssertEqual(forecast.coordinate, testCoordinate)
        XCTAssertEqual(forecast.fetchedAt, fetchedAt)
        XCTAssertEqual(forecast.hours.first?.weatherCode, 61)
    }

    func testDecodedForecastSummarisesSevenToEighteen() throws {
        let forecast = try OpenMeteoWeatherService.decode(openMeteoFixture(), coordinate: testCoordinate, fetchedAt: Date())

        let today = try XCTUnwrap(forecast.dayWeather(on: stockholmDate(2026, 10, 19, 7, 30)))
        let tomorrow = try XCTUnwrap(forecast.dayWeather(on: stockholmDate(2026, 10, 20, 7, 30)))

        XCTAssertEqual(today.feelsLikeMin, 7)
        XCTAssertEqual(today.feelsLikeMax, 18)
        XCTAssertEqual(today.precipitationMM, 5.5, accuracy: 0.0001)  // 11 timmar à 0,5 mm
        XCTAssertEqual(today.precipitationType, .rain)
        XCTAssertEqual(today.maxWindSpeed, 4.5)
        XCTAssertEqual(tomorrow.feelsLikeMin, 7)  // timme 30 = kl. 06 imorgon saknas, påverkar inte
        XCTAssertEqual(forecast.weatherCodes(on: stockholmDate(2026, 10, 19)).count, 12)
    }

    func testGarbageIsRejected() {
        XCTAssertThrowsError(try OpenMeteoWeatherService.decode(Data("inte json".utf8), coordinate: testCoordinate, fetchedAt: Date())) { error in
            XCTAssertEqual(error as? WeatherServiceError, .invalidData)
        }
    }

    func testCacheRoundTrip() throws {
        let cache = makeTemporaryWeatherCache()
        defer { try? FileManager.default.removeItem(at: cache.fileURL.deletingLastPathComponent()) }
        let forecast = makeForecast(fetchedAt: stockholmDate(2026, 10, 19, 6), day: stockholmDate(2026, 10, 19))

        XCTAssertNil(cache.load())
        try cache.save(forecast)

        XCTAssertEqual(cache.load(), forecast)
    }

    func testPlaceSurvivesStorage() {
        let place = Place(name: "Tromsø", detail: "Troms, Norge", coordinate: Coordinate(latitude: 69.6492, longitude: 18.9553))

        XCTAssertEqual(Place(data: place.encoded), place)
        XCTAssertEqual(place.coordinate.latitude, 69.65)
        XCTAssertNil(Place(data: Data()))
    }

    func testLocationPreferenceFromSettings() {
        let place = Place(name: "Bergen", coordinate: Coordinate(latitude: 60.39, longitude: 5.32))

        XCTAssertEqual(LocationPreference(useManualPlace: false, placeData: place.encoded), .automatic)
        XCTAssertEqual(LocationPreference(useManualPlace: true, placeData: place.encoded), .manual(place))
        XCTAssertEqual(LocationPreference(useManualPlace: true, placeData: Data()), .manual(nil))
    }
}

final class WeatherConditionTests: XCTestCase {
    func condition(_ day: DayWeather, codes: [Int] = []) -> WeatherCondition {
        WeatherCondition.forDay(day, codes: codes)
    }

    func testPrecipitation() {
        XCTAssertEqual(condition(DayWeather(feelsLikeMin: 5, feelsLikeMax: 8, precipitationMM: 2, precipitationType: .rain)), .rain)
        XCTAssertEqual(condition(DayWeather(feelsLikeMin: 5, feelsLikeMax: 8, precipitationMM: 7, precipitationType: .rain)), .heavyRain)
        XCTAssertEqual(condition(DayWeather(feelsLikeMin: -5, feelsLikeMax: -1, precipitationMM: 2, precipitationType: .snow)), .snow)
        XCTAssertEqual(condition(DayWeather(feelsLikeMin: 0, feelsLikeMax: 2, precipitationMM: 2, precipitationType: .sleet)), .sleet)
        XCTAssertEqual(condition(DayWeather(feelsLikeMin: 15, feelsLikeMax: 20, precipitationMM: 3, precipitationType: .rain), codes: [3, 95]), .thunder)
    }

    func testLittlePrecipitationCountsAsDry() {
        let day = DayWeather(feelsLikeMin: 10, feelsLikeMax: 14, precipitationMM: 0.4, precipitationType: .rain)

        XCTAssertEqual(condition(day, codes: [0, 0, 1, 2]), .clear)
    }

    func testWindOnDryDay() {
        XCTAssertEqual(condition(DayWeather(feelsLikeMin: 0, feelsLikeMax: 4, maxWindSpeed: 12), codes: [0, 0]), .windy)
    }

    func testMostCommonSkyWinsAndTiesGoToTheSunnier() {
        let day = DayWeather(feelsLikeMin: 10, feelsLikeMax: 14)

        XCTAssertEqual(condition(day, codes: [3, 3, 3, 2, 0]), .cloudy)
        XCTAssertEqual(condition(day, codes: [45, 48, 45, 3]), .fog)
        XCTAssertEqual(condition(day, codes: [3, 3, 1, 0]), .clear)
        XCTAssertEqual(condition(day, codes: []), .partlyCloudy)
    }
}
