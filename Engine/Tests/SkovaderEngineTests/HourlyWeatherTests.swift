import XCTest
@testable import SkovaderEngine

/// Sammanfattningen av timdata till fönstret 07–18.
final class HourlyWeatherTests: XCTestCase {
    let calendar = Calendar.stockholm
    lazy var day = calendar.date(2026, 10, 19, 6, 30)

    /// 24 timmar för `day` där varje värde kommer från `values(hour)`.
    func hours(
        on date: Date? = nil,
        _ values: (Int) -> (temp: Double, precip: Double, rain: Double, snow: Double, wind: Double)
    ) -> [HourlyWeather] {
        let base = date ?? day
        return (0..<24).map { hour in
            let v = values(hour)
            let components = calendar.dateComponents([.year, .month, .day], from: base)
            let time = calendar.date(components.year!, components.month!, components.day!, hour, 0)
            return HourlyWeather(time: time, apparentTemperature: v.temp, precipitationMM: v.precip, rainMM: v.rain, snowfallCM: v.snow, windSpeed: v.wind)
        }
    }

    func testTemperatureAndWindUseHoursSevenToEighteen() throws {
        let data = hours { hour in (Double(hour), 0, 0, 0, Double(hour) / 2) }

        let weather = try XCTUnwrap(DayWeather.summarizing(data, on: day, calendar: calendar))

        XCTAssertEqual(weather.feelsLikeMin, 7)
        XCTAssertEqual(weather.feelsLikeMax, 18)
        XCTAssertEqual(weather.maxWindSpeed, 9)
    }

    func testPrecipitationCoversSevenToEighteen() throws {
        // Värdet kl. 08 gäller 07–08 och värdet kl. 18 gäller 17–18: 11 timmar.
        let data = hours { _ in (5, 1, 1, 0, 0) }

        let weather = try XCTUnwrap(DayWeather.summarizing(data, on: day, calendar: calendar))

        XCTAssertEqual(weather.precipitationMM, 11, accuracy: 0.0001)
        XCTAssertEqual(weather.precipitationType, .rain)
    }

    func testOtherDaysAreIgnored() throws {
        let tomorrow = calendar.date(2026, 10, 20, 12, 0)
        let data = hours { _ in (10, 0, 0, 0, 2) } + hours(on: tomorrow) { _ in (-20, 30, 0, 21, 25) }

        let weather = try XCTUnwrap(DayWeather.summarizing(data, on: day, calendar: calendar))

        XCTAssertEqual(weather.feelsLikeMin, 10)
        XCTAssertEqual(weather.precipitationMM, 0)
        XCTAssertEqual(weather.precipitationType, .none)
        XCTAssertEqual(weather.maxWindSpeed, 2)
    }

    func testSnowfallIsConvertedToWater() throws {
        // 0,7 cm snö i timmen = 1 mm vatten.
        let data = hours { _ in (-4, 1, 0, 0.7, 3) }

        let weather = try XCTUnwrap(DayWeather.summarizing(data, on: day, calendar: calendar))

        XCTAssertEqual(weather.precipitationType, .snow)
        XCTAssertEqual(weather.precipitationMM, 11, accuracy: 0.0001)
    }

    func testMixedRainAndSnowIsSleet() throws {
        let data = hours { _ in (1, 1, 0.5, 0.35, 0) }

        let weather = try XCTUnwrap(DayWeather.summarizing(data, on: day, calendar: calendar))

        XCTAssertEqual(weather.precipitationType, .sleet)
    }

    func testMostlySnowWithALittleRainIsSnow() throws {
        let data = hours { hour in hour == 9 ? (-1, 0.2, 0.2, 0, 0) : (-1, 1, 0, 0.7, 0) }

        let weather = try XCTUnwrap(DayWeather.summarizing(data, on: day, calendar: calendar))

        XCTAssertEqual(weather.precipitationType, .snow)
    }

    func testRainOutsideWindowIsIgnored() throws {
        let data = hours { hour in (8, hour < 7 || hour > 18 ? 4 : 0, hour < 7 || hour > 18 ? 4 : 0, 0, 0) }

        let weather = try XCTUnwrap(DayWeather.summarizing(data, on: day, calendar: calendar))

        XCTAssertEqual(weather.precipitationMM, 0)
        XCTAssertEqual(weather.precipitationType, .none)
    }

    func testNoHoursInWindowGivesNil() {
        let tomorrow = calendar.date(2026, 10, 20, 12, 0)

        XCTAssertNil(DayWeather.summarizing([], on: day, calendar: calendar))
        XCTAssertNil(DayWeather.summarizing(hours(on: tomorrow) { _ in (5, 0, 0, 0, 0) }, on: day, calendar: calendar))
    }

    func testWindowHoursComeFromConfig() throws {
        var config = RecommendationConfig()
        config.weatherWindowStartHour = 10
        config.weatherWindowEndHour = 12
        let data = hours { hour in (Double(hour), 0, 0, 0, 0) }

        let weather = try XCTUnwrap(DayWeather.summarizing(data, on: day, calendar: calendar, config: config))

        XCTAssertEqual(weather.feelsLikeMin, 10)
        XCTAssertEqual(weather.feelsLikeMax, 12)
    }

    func testSummaryFeedsTheEngine() throws {
        // Hela kedjan: timdata → DayWeather → förslag.
        let data = hours { hour in (Double(3 + hour / 4), 0.6, 0.6, 0, 4) }
        let weather = try XCTUnwrap(DayWeather.summarizing(data, on: day, calendar: calendar))

        let result = try suggestion(RecommendationEngine().recommend(shoes: Wardrobe.all, weather: weather))

        XCTAssertEqual(weather.precipitationMM, 6.6, accuracy: 0.0001)
        XCTAssertEqual(result.primary.shoe, Wardrobe.rubberBoots)
    }
}
