import XCTest
@testable import SkovaderEngine

final class ExplanationTests: XCTestCase {
    let builder = ExplanationBuilder()

    func testSingleTemperatureWhenSpreadIsSmall() {
        XCTAssertEqual(builder.weatherSentence(DayWeather(feelsLikeMin: 3.6, feelsLikeMax: 6.4)), "Det blir 5 grader")
    }

    func testRangeWhenSpreadIsLarge() {
        XCTAssertEqual(builder.weatherSentence(DayWeather(feelsLikeMin: 2.4, feelsLikeMax: 9.2)), "Det blir 2 till 9 grader")
    }

    func testSingularDegree() {
        XCTAssertEqual(builder.weatherSentence(DayWeather(feelsLikeMin: 0.5, feelsLikeMax: 1.5)), "Det blir 1 grad")
        XCTAssertEqual(builder.weatherSentence(DayWeather(feelsLikeMin: -1.5, feelsLikeMax: -0.5)), "Det blir -1 grad")
    }

    func testDryLightRainIsNotMentioned() {
        let weather = DayWeather(feelsLikeMin: 10, feelsLikeMax: 12, precipitationMM: 0.5, precipitationType: .rain)

        XCTAssertEqual(builder.weatherSentence(weather), "Det blir 11 grader")
    }

    func testEmptyNameFallsBackToTypeName() {
        let shoe = ShoeProfile(name: "  ", type: .rubberBoots)

        XCTAssertEqual(shoe.displayName, "gummistövlar")
        XCTAssertEqual(builder.shoeSentence(shoe: shoe, reason: .keepsDry), "dina gummistövlar håller fötterna torra")
    }

    func testEveryReasonHasATemplate() {
        let reasons: [ShoeReason] = [
            .heavyRainRubberBoots, .snowWinterBoots, .notWaterproof, .tooColdForSnow, .keepsDry,
            .unnecessarilyWarm, .mightBeCold, .mightBeWarm, .warmDay, .coldDay, .goodFit,
        ]
        for reason in reasons {
            let sentence = builder.shoeSentence(shoe: Wardrobe.boots, reason: reason)
            XCTAssertTrue(sentence.contains("Kängor"), sentence)
            XCTAssertFalse(sentence.hasPrefix("reason."), "Mall saknas för \(reason)")
        }
    }

    func testCaveatWhenShoeIsTooCold() {
        let weather = DayWeather(feelsLikeMin: 4, feelsLikeMax: 9)
        let scored = RecommendationEngine().score(Wardrobe.sneakers, weather: weather)  // 4 grader under 8

        XCTAssertEqual(scored.reason, .mightBeCold)
        XCTAssertEqual(scored.explanation, "Det blir 4 till 9 grader – det kan bli lite kallt i dina Rosa Converse.")
    }

    func testMildDryDayUsesNeutralReason() {
        let scored = RecommendationEngine().score(Wardrobe.leather, weather: DayWeather(feelsLikeMin: 8, feelsLikeMax: 14))

        XCTAssertEqual(scored.reason, .goodFit)
        XCTAssertEqual(scored.explanation, "Det blir 8 till 14 grader – dina Lädersneakers passar bra idag.")
    }
}

final class ShoeTypeDefaultsTests: XCTestCase {
    /// Tabellen "Standardvärden per skotyp" i kravspecen (F4).
    func testDefaultsMatchSpecTable() {
        let expected: [(ShoeType, Bool, WarmthLevel, Int, Int)] = [
            (.sandals, false, .light, 18, 40),
            (.sneakers, false, .light, 8, 30),
            (.leatherSneakers, false, .medium, 3, 25),
            (.waterproofSneakers, true, .medium, 0, 22),
            (.boots, true, .medium, -5, 15),
            (.winterBoots, true, .warm, -30, 5),
            (.rubberBoots, true, .light, 0, 20),
        ]
        XCTAssertEqual(expected.count, ShoeType.allCases.count)

        for (type, waterproof, warmth, min, max) in expected {
            XCTAssertEqual(type.defaults, ShoeDefaults(isWaterproof: waterproof, warmth: warmth, minTemperature: min, maxTemperature: max), "\(type)")
        }
    }

    func testProfileFromTypeUsesDefaults() {
        let shoe = ShoeProfile(name: "Stövlar", type: .rubberBoots)

        XCTAssertTrue(shoe.isWaterproof)
        XCTAssertEqual(shoe.warmth, .light)
        XCTAssertEqual(shoe.minTemperature, 0)
        XCTAssertEqual(shoe.maxTemperature, 20)
        XCTAssertTrue(shoe.isActive)
    }

    func testTypesHaveSwedishNames() {
        XCTAssertEqual(ShoeType.winterBoots.localizedName, "Vinterkängor / fodrade")
        XCTAssertEqual(WarmthLevel.medium.localizedName, "Mellan")
        for type in ShoeType.allCases {
            XCTAssertFalse(type.localizedName.hasPrefix("shoeType."), "\(type)")
        }
    }

    func testRawValuesAreStable() {
        // Sparas i databasen – får inte ändras.
        XCTAssertEqual(ShoeType.allCases.map(\.rawValue), [
            "sandals", "sneakers", "leatherSneakers", "waterproofSneakers", "boots", "winterBoots", "rubberBoots",
        ])
    }
}
