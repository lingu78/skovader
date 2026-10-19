import XCTest
@testable import SkovaderEngine

/// F8: "Jag tar dessa" och rotation mellan likvärdiga skor.
final class RotationTests: XCTestCase {
    let engine = RecommendationEngine()
    let mildDay = DayWeather(feelsLikeMin: 15, feelsLikeMax: 20)
    let pink = ShoeProfile(name: "Rosa Converse", type: .sneakers)
    let white = ShoeProfile(name: "Vita Converse", type: .sneakers)

    func testShoeWornYesterdayGivesWayToEquivalentShoe() throws {
        let history = WearHistory(daysAgo: [pink.id: [1]])
        let result = try suggestion(engine.recommend(shoes: [pink, white], weather: mildDay, history: history))

        XCTAssertEqual(result.primary.shoe, white)
        XCTAssertEqual(result.alternatives.first?.shoe, pink)
        XCTAssertEqual(result.alternatives.first?.hit(.wornYesterday)?.points, -10)
    }

    func testWornYesterdayAndDayBeforeGivesTwentyNotThirty() {
        let history = WearHistory(daysAgo: [pink.id: [1, 2]])
        let scored = engine.score(pink, weather: mildDay, history: history)

        XCTAssertEqual(scored.score, 80)
        XCTAssertNotNil(scored.hit(.wornTwoDaysInRow))
        XCTAssertNil(scored.hit(.wornYesterday))
    }

    func testWornOnlyDayBeforeYesterdayHasNoPenalty() {
        let history = WearHistory(daysAgo: [pink.id: [2]])

        XCTAssertEqual(engine.score(pink, weather: mildDay, history: history).score, 100)
    }

    func testWornTodayDoesNotAffectTodaysRecommendation() {
        let history = WearHistory(daysAgo: [pink.id: [0]])

        XCTAssertEqual(engine.score(pink, weather: mildDay, history: history).score, 100)
    }

    func testRotationDoesNotOverrideClearlyBetterShoe() throws {
        let history = WearHistory(daysAgo: [Wardrobe.rubberBoots.id: [1]])
        let result = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: Weather.chillyHeavyRain, history: history))

        XCTAssertEqual(result.primary.shoe, Wardrobe.rubberBoots)
        XCTAssertEqual(result.primary.score, 110)
    }

    func testTwoRainyDaysInRubberBootsLetsEquivalentBootsWin() throws {
        let history = WearHistory(daysAgo: [Wardrobe.rubberBoots.id: [1, 2]])
        let result = try suggestion(engine.recommend(shoes: Wardrobe.all, weather: Weather.chillyHeavyRain, history: history))

        XCTAssertEqual(result.primary.shoe, Wardrobe.boots)
        XCTAssertEqual(result.alternatives.first?.shoe, Wardrobe.rubberBoots)
        XCTAssertEqual(result.alternatives.first?.score, 100)
    }

    func testLeastRecentlyWornBreaksExactTie() throws {
        let history = WearHistory(daysAgo: [pink.id: [3], white.id: [5]])
        let result = try suggestion(engine.recommend(shoes: [pink, white], weather: mildDay, history: history))

        XCTAssertEqual(result.primary.shoe, white)
    }
}

final class WearHistoryTests: XCTestCase {
    let calendar = Calendar.stockholm
    let shoe = UUID()

    func testLateEveningYesterdayCountsAsYesterday() {
        let today = calendar.date(2026, 10, 19, 7, 5)
        let history = WearHistory(entries: [WearEntry(shoeID: shoe, date: calendar.date(2026, 10, 18, 23, 30))], today: today, calendar: calendar)

        XCTAssertTrue(history.wasWorn(shoe, daysAgo: 1))
        XCTAssertFalse(history.wasWorn(shoe, daysAgo: 0))
    }

    func testEarlyMorningTodayCountsAsToday() {
        let today = calendar.date(2026, 10, 19, 22, 0)
        let history = WearHistory(entries: [WearEntry(shoeID: shoe, date: calendar.date(2026, 10, 19, 0, 15))], today: today, calendar: calendar)

        XCTAssertTrue(history.wasWorn(shoe, daysAgo: 0))
        XCTAssertNil(history.daysSinceLastWorn(shoe))
    }

    func testDaysAgoAcrossDaylightSavingChange() {
        // Sommartiden slutar natten till 25 oktober 2026.
        let today = calendar.date(2026, 10, 26, 8, 0)
        let entries = [
            WearEntry(shoeID: shoe, date: calendar.date(2026, 10, 25, 8, 0)),
            WearEntry(shoeID: shoe, date: calendar.date(2026, 10, 24, 8, 0)),
        ]
        let history = WearHistory(entries: entries, today: today, calendar: calendar)

        XCTAssertTrue(history.wasWorn(shoe, daysAgo: 1))
        XCTAssertTrue(history.wasWorn(shoe, daysAgo: 2))
        XCTAssertEqual(history.daysSinceLastWorn(shoe), 1)
    }

    func testFutureEntriesAreIgnored() {
        let today = calendar.date(2026, 10, 19)
        let history = WearHistory(entries: [WearEntry(shoeID: shoe, date: calendar.date(2026, 10, 20))], today: today, calendar: calendar)

        XCTAssertNil(history.daysSinceLastWorn(shoe))
        XCTAssertFalse(history.wasWorn(shoe, daysAgo: -1))
    }

    func testUnknownShoeWasNeverWorn() {
        XCTAssertFalse(WearHistory.empty.wasWorn(shoe, daysAgo: 1))
        XCTAssertNil(WearHistory.empty.daysSinceLastWorn(shoe))
    }
}
