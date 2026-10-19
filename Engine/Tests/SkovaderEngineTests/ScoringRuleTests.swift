import XCTest
@testable import SkovaderEngine

/// En regel i taget, med gränsvärden.
final class ScoringRuleTests: XCTestCase {
    let engine = RecommendationEngine()

    // MARK: Steg 1 – filter

    func testFilterKeepsShoeExactlyFiveDegreesBelowMin() {
        let weather = DayWeather(feelsLikeMin: 3, feelsLikeMax: 12)
        let scored = engine.score(Wardrobe.sneakers, weather: weather)  // min 8

        XCTAssertTrue(scored.passedFilter)
        XCTAssertEqual(scored.score, 75)
    }

    func testFilterRemovesShoeMoreThanFiveDegreesBelowMin() {
        let weather = DayWeather(feelsLikeMin: 2.9, feelsLikeMax: 12)

        XCTAssertFalse(engine.score(Wardrobe.sneakers, weather: weather).passedFilter)
    }

    func testFilterRemovesShoeMoreThanFiveDegreesAboveMax() {
        let weather = DayWeather(feelsLikeMin: 10, feelsLikeMax: 20.5)

        XCTAssertFalse(engine.score(Wardrobe.boots, weather: weather).passedFilter)  // max 15
        XCTAssertTrue(engine.score(Wardrobe.boots, weather: DayWeather(feelsLikeMin: 10, feelsLikeMax: 20)).passedFilter)
    }

    func testInactiveShoeIsNeverSuggestedEvenIfBest() throws {
        var rubberBoots = Wardrobe.rubberBoots
        rubberBoots.isActive = false
        let shoes = Wardrobe.all.filter { $0 != Wardrobe.rubberBoots } + [rubberBoots]

        let result = try suggestion(engine.recommend(shoes: shoes, weather: Weather.chillyHeavyRain))
        let suggested = [result.primary] + result.alternatives

        XCTAssertFalse(suggested.contains { $0.id == rubberBoots.id })
        XCTAssertEqual(result.primary.shoe, Wardrobe.boots)
    }

    // MARK: Steg 2 – temperatur

    func testFivePointsPerDegreeOutsideRangeOnBothSides() {
        let shoe = ShoeProfile(name: "Smal", type: .sneakers, isWaterproof: false, warmth: .light, minTemperature: 10, maxTemperature: 15)
        let scored = engine.score(shoe, weather: DayWeather(feelsLikeMin: 8, feelsLikeMax: 17))

        XCTAssertEqual(scored.hit(.colderThanRange)?.points, -10)
        XCTAssertEqual(scored.hit(.warmerThanRange)?.points, -10)
        XCTAssertEqual(scored.score, 80)
    }

    func testFractionalDegreesGiveFractionalPoints() {
        let scored = engine.score(Wardrobe.sneakers, weather: DayWeather(feelsLikeMin: 6.5, feelsLikeMax: 12))

        XCTAssertEqual(scored.score, 92.5, accuracy: 0.0001)
    }

    // MARK: Steg 2 – regn

    func testRainBelowOneMillimetreCountsAsDry() {
        let weather = DayWeather(feelsLikeMin: 12, feelsLikeMax: 16, precipitationMM: 0.9, precipitationType: .rain)

        XCTAssertNil(engine.score(Wardrobe.sneakers, weather: weather).hit(.rainNotWaterproof))
    }

    func testRainFromOneMillimetrePenalisesNonWaterproofShoes() {
        let weather = DayWeather(feelsLikeMin: 12, feelsLikeMax: 16, precipitationMM: 1.0, precipitationType: .rain)

        XCTAssertEqual(engine.score(Wardrobe.sneakers, weather: weather).hit(.rainNotWaterproof)?.points, -40)
        XCTAssertNil(engine.score(Wardrobe.runners, weather: weather).hit(.rainNotWaterproof))
    }

    func testRubberBootsBonusFromFiveMillimetres() {
        func bonus(_ mm: Double) -> Double? {
            let weather = DayWeather(feelsLikeMin: 8, feelsLikeMax: 12, precipitationMM: mm, precipitationType: .rain)
            return engine.score(Wardrobe.rubberBoots, weather: weather).hit(.heavyRainRubberBoots)?.points
        }

        XCTAssertNil(bonus(4.9))
        XCTAssertEqual(bonus(5.0), 20)
    }

    func testRubberBootsBonusOnlyForRubberBootsType() {
        let weather = DayWeather(feelsLikeMin: 8, feelsLikeMax: 12, precipitationMM: 8, precipitationType: .rain)

        XCTAssertNil(engine.score(Wardrobe.boots, weather: weather).hit(.heavyRainRubberBoots))
    }

    // MARK: Steg 2 – snö

    func testSnowDoesNotTriggerRainRule() {
        let weather = DayWeather(feelsLikeMin: -2, feelsLikeMax: 1, precipitationMM: 3, precipitationType: .snow)
        let leather = engine.score(Wardrobe.leather, weather: weather)

        XCTAssertNil(leather.hit(.rainNotWaterproof))
        XCTAssertEqual(leather.hit(.snowLowWarmth)?.points, -30)
    }

    func testSnowPenaltyNeedsWarmthThree() {
        let weather = DayWeather(feelsLikeMin: -6, feelsLikeMax: -2, precipitationMM: 2, precipitationType: .snow)
        let lined = ShoeProfile(name: "Fodrade boots", type: .boots, isWaterproof: true, warmth: .warm, minTemperature: -15, maxTemperature: 8)

        XCTAssertNil(engine.score(lined, weather: weather).hit(.snowLowWarmth))
        // Bonusen gäller bara typen vinterkängor.
        XCTAssertNil(engine.score(lined, weather: weather).hit(.snowWinterBoots))
        XCTAssertEqual(engine.score(Wardrobe.winterBoots, weather: weather).hit(.snowWinterBoots)?.points, 20)
    }

    func testTraceOfSnowBelowThresholdIsIgnored() {
        let weather = DayWeather(feelsLikeMin: -3, feelsLikeMax: 0, precipitationMM: 0.4, precipitationType: .snow)

        XCTAssertNil(engine.score(Wardrobe.boots, weather: weather).hit(.snowLowWarmth))
        XCTAssertNil(engine.score(Wardrobe.winterBoots, weather: weather).hit(.snowWinterBoots))
    }

    // MARK: Steg 2 – undvik vinterkängor i onödan

    func testDryDayAboveTenPenalisesWarmWaterproofShoes() {
        let lined = ShoeProfile(name: "Fodrade boots", type: .boots, isWaterproof: true, warmth: .warm, minTemperature: -10, maxTemperature: 15)
        let scored = engine.score(lined, weather: DayWeather(feelsLikeMin: 9, feelsLikeMax: 13))

        XCTAssertEqual(scored.hit(.dryWarmDayWinterShoe)?.points, -20)
        XCTAssertEqual(scored.score, 80)
        XCTAssertEqual(scored.reason, .unnecessarilyWarm)
    }

    func testWarmShoePenaltyNotAppliedAtExactlyTenOrWhenWet() {
        let lined = ShoeProfile(name: "Fodrade boots", type: .boots, isWaterproof: true, warmth: .warm, minTemperature: -10, maxTemperature: 15)

        XCTAssertNil(engine.score(lined, weather: DayWeather(feelsLikeMin: 6, feelsLikeMax: 10)).hit(.dryWarmDayWinterShoe))
        let wet = DayWeather(feelsLikeMin: 9, feelsLikeMax: 13, precipitationMM: 1, precipitationType: .rain)
        XCTAssertNil(engine.score(lined, weather: wet).hit(.dryWarmDayWinterShoe))
    }

    // MARK: Steg 3

    func testExactlyFiftyPointsIsNotAGoodFit() throws {
        // Sneakers (8–30) en dag med 6–10 grader och regn: −10 kyla, −40 regn = 50.
        let weather = DayWeather(feelsLikeMin: 6, feelsLikeMax: 10, precipitationMM: 2, precipitationType: .rain)
        let result = try suggestion(engine.recommend(shoes: [Wardrobe.sneakers], weather: weather))

        XCTAssertEqual(result.primary.score, 50)
        XCTAssertTrue(result.primary.passedFilter)
        XCTAssertFalse(result.isGoodFit)
        XCTAssertNotNil(result.poorFitMessage)
    }

    func testAtMostTwoAlternatives() throws {
        let result = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: Weather.coolSummer))

        XCTAssertEqual(result.alternatives.count, 2)
    }

    func testResultDoesNotDependOnInputOrder() throws {
        let expected = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: Weather.windy))

        for shoes in [Array(Wardrobe.all.reversed()), Wardrobe.all.shuffled(), Wardrobe.all.shuffled()] {
            let result = try suggestion(engine.recommend(shoes: shoes, weather: Weather.windy))
            XCTAssertEqual(result, expected)
        }
    }

    func testConstantsComeFromConfig() throws {
        var config = RecommendationConfig()
        config.rainNotWaterproofPenalty = 0
        config.maxAlternatives = 1
        config.goodFitThreshold = 99
        let custom = RecommendationEngine(config: config)
        let weather = DayWeather(feelsLikeMin: 12, feelsLikeMax: 16, precipitationMM: 3, precipitationType: .rain)

        XCTAssertEqual(custom.score(Wardrobe.sneakers, weather: weather).score, 100)
        let result = try suggestion(custom.recommend(shoes: Wardrobe.all, weather: weather))
        XCTAssertEqual(result.alternatives.count, 1)
        XCTAssertTrue(result.isGoodFit)
    }

    func testReversedTemperaturesAreNormalised() {
        let weather = DayWeather(feelsLikeMin: 20, feelsLikeMax: 10)

        XCTAssertEqual(weather.feelsLikeMin, 10)
        XCTAssertEqual(weather.feelsLikeMax, 20)
    }
}
