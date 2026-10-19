import XCTest
@testable import SkovaderEngine

/// Hela kedjan (filtrera → poängsätt → välj) för typiska dagar, med en
/// garderob som har en sko av varje typ med standardvärden.
final class WeatherScenarioTests: XCTestCase {
    let engine = RecommendationEngine()

    // MARK: Sol och värme

    func testWarmSunPicksSandals() throws {
        let result = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: Weather.warmSun))

        XCTAssertEqual(result.primary.shoe, Wardrobe.sandals)
        XCTAssertEqual(result.primary.score, 100)
        XCTAssertEqual(names(result.alternatives), ["Rosa Converse", "Lädersneakers"])
        XCTAssertEqual(result.alternatives.map(\.score), [100, 75])
        XCTAssertTrue(result.isGoodFit)
        XCTAssertEqual(result.primary.explanation, "Det blir 22 till 30 grader – perfekt väder för dina Sandaler.")
    }

    func testWarmSunNeverSuggestsWinterBoots() throws {
        let result = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: Weather.warmSun))
        let suggested = [result.primary] + result.alternatives

        XCTAssertFalse(suggested.contains { $0.shoe == Wardrobe.winterBoots })
        XCTAssertFalse(engine.score(Wardrobe.winterBoots, weather: Weather.warmSun).passedFilter)
    }

    func testCoolSummerDayPicksSneakers() throws {
        let result = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: Weather.coolSummer))

        XCTAssertEqual(result.primary.shoe, Wardrobe.sneakers)
        XCTAssertEqual(names(result.alternatives), ["Lädersneakers", "Vattentäta löparskor"])
        // Sandaler: 12 °C är 6 grader under 18 → bortfiltrerade.
        XCTAssertFalse(engine.score(Wardrobe.sandals, weather: Weather.coolSummer).passedFilter)
    }

    // MARK: Regn

    func testChillyHeavyRainPicksRubberBoots() throws {
        let result = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: Weather.chillyHeavyRain))

        XCTAssertEqual(result.primary.shoe, Wardrobe.rubberBoots)
        XCTAssertEqual(result.primary.score, 120)
        XCTAssertEqual(names(result.alternatives), ["Kängor", "Vattentäta löparskor"])
        XCTAssertEqual(result.primary.reason, .heavyRainRubberBoots)
        XCTAssertEqual(result.primary.explanation, "Det blir 3 till 7 grader och mycket regn – dina Gummistövlar klarar alla vattenpölar.")
    }

    func testChillyHeavyRainPenalisesFabricShoes() {
        XCTAssertEqual(engine.score(Wardrobe.sneakers, weather: Weather.chillyHeavyRain).score, 35)  // −25 kyla, −40 regn
        XCTAssertEqual(engine.score(Wardrobe.leather, weather: Weather.chillyHeavyRain).score, 60)   // −40 regn
    }

    func testMildLightRainPicksWaterproofRunners() throws {
        let result = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: Weather.mildLightRain))

        XCTAssertEqual(result.primary.shoe, Wardrobe.runners)
        XCTAssertEqual(names(result.alternatives), ["Gummistövlar", "Kängor"])
        // Under 5 mm ger gummistövlarna ingen bonus.
        XCTAssertNil(engine.score(Wardrobe.rubberBoots, weather: Weather.mildLightRain).hit(.heavyRainRubberBoots))
        XCTAssertEqual(result.primary.explanation, "Det blir 9 till 13 grader och regn – dina Vattentäta löparskor håller fötterna torra.")
    }

    func testSpecExampleFourDegreesAndRain() throws {
        let weather = DayWeather(feelsLikeMin: 3.6, feelsLikeMax: 5.2, precipitationMM: 2, precipitationType: .rain)
        let result = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: weather))

        XCTAssertEqual(result.primary.shoe, Wardrobe.boots)
        XCTAssertEqual(result.primary.explanation, "Det blir 4 grader och regn – dina Kängor håller fötterna torra.")
    }

    // MARK: Snö och kyla

    func testSnowPicksWinterBoots() throws {
        let result = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: Weather.snow))

        XCTAssertEqual(result.primary.shoe, Wardrobe.winterBoots)
        XCTAssertEqual(result.primary.score, 120)
        XCTAssertEqual(names(result.alternatives), ["Kängor"])
        XCTAssertEqual(result.alternatives.first?.score, 55)  // −15 kyla, −30 snö
        XCTAssertEqual(result.primary.explanation, "Det blir -8 till -3 grader och snö – dina Vinterkängor håller fötterna varma och torra.")
    }

    func testColdDryDayPicksWinterBootsWithoutAlternatives() throws {
        let result = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: Weather.coldDry))

        XCTAssertEqual(result.primary.shoe, Wardrobe.winterBoots)
        XCTAssertEqual(result.alternatives, [])
        XCTAssertTrue(result.isGoodFit)
        XCTAssertEqual(result.primary.reason, .coldDay)
    }

    func testSleetAppliesBothRainAndSnowRules() throws {
        let result = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: Weather.sleet))

        XCTAssertEqual(result.primary.shoe, Wardrobe.winterBoots)
        let leather = engine.score(Wardrobe.leather, weather: Weather.sleet)
        XCTAssertNotNil(leather.hit(.rainNotWaterproof))
        XCTAssertNotNil(leather.hit(.snowLowWarmth))
        XCTAssertEqual(leather.score, 15)  // −15 kyla, −40 regn, −30 snö
        XCTAssertEqual(result.primary.explanation, "Det blir 1 grad och snöblandat regn – dina Vinterkängor håller fötterna varma och torra.")
    }

    // MARK: Blåst

    func testWindyDayPicksBootsAndMentionsWind() throws {
        let result = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: Weather.windy))

        XCTAssertEqual(result.primary.shoe, Wardrobe.boots)
        XCTAssertEqual(names(result.alternatives), ["Vinterkängor", "Gummistövlar"])
        XCTAssertEqual(result.primary.explanation, "Det blir -2 till 3 grader och blåsigt – dina Kängor håller fötterna varma.")
    }

    func testWindItselfDoesNotChangeScores() {
        var calm = Weather.windy
        calm.maxWindSpeed = 0

        for shoe in Wardrobe.all {
            XCTAssertEqual(
                engine.score(shoe, weather: Weather.windy).score,
                engine.score(shoe, weather: calm).score,
                shoe.name
            )
        }
    }

    func testWindyRainMentionsBoth() throws {
        let result = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: Weather.windyRain))

        XCTAssertEqual(result.primary.shoe, Wardrobe.boots)
        XCTAssertEqual(result.primary.explanation, "Det blir 5 grader, regn och blåsigt – dina Kängor håller fötterna torra.")
    }

    // MARK: Tomma och svåra lägen

    func testNoShoes() {
        XCTAssertEqual(engine.recommend(shoes: [], weather: Weather.warmSun), .noShoes)
    }

    func testOnlyInactiveShoes() {
        var sneakers = Wardrobe.sneakers
        sneakers.isActive = false

        XCTAssertEqual(engine.recommend(shoes: [sneakers], weather: Weather.warmSun), .noActiveShoes)
    }

    func testAllShoesWornRecentlyKeepsOrderAndStillSuggests() throws {
        let history = WearHistory(daysAgo: Dictionary(uniqueKeysWithValues: Wardrobe.all.map { ($0.id, [1, 2]) }))
        let fresh = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: Weather.chillyHeavyRain))
        let worn = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: Weather.chillyHeavyRain, history: history))

        XCTAssertEqual(worn.primary.shoe, fresh.primary.shoe)
        XCTAssertEqual(names(worn.alternatives), names(fresh.alternatives))
        XCTAssertEqual(worn.primary.score, fresh.primary.score - 20)
        XCTAssertTrue(([worn.primary] + worn.alternatives).allSatisfy { $0.hit(.wornTwoDaysInRow) != nil })
        XCTAssertTrue(worn.isGoodFit)
    }

    func testHeatWaveWithOnlyWinterShoesShowsClosestAnyway() throws {
        let result = try suggestion(engine.recommend(shoes: [Wardrobe.winterBoots, Wardrobe.boots], weather: Weather.warmSun))

        XCTAssertFalse(result.isGoodFit)
        XCTAssertEqual(result.primary.shoe, Wardrobe.boots)
        XCTAssertFalse(result.primary.passedFilter)
        XCTAssertEqual(result.poorFitMessage, "Inga av dina skor passar riktigt idag – närmast är Kängor.")
    }

    func testColdRainWithOnlySandalsShowsPoorFit() throws {
        let weather = DayWeather(feelsLikeMin: 2, feelsLikeMax: 6, precipitationMM: 4, precipitationType: .rain)
        let result = try suggestion(engine.recommend(shoes: [Wardrobe.sandals], weather: weather))

        XCTAssertFalse(result.isGoodFit)
        XCTAssertEqual(result.primary.shoe, Wardrobe.sandals)
        XCTAssertEqual(result.alternatives, [])
        XCTAssertEqual(result.primary.reason, .notWaterproof)
    }
}
