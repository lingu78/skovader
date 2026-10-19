import SwiftData
import UserNotifications
import XCTest
import SkovaderEngine
@testable import Skovader

final class WearLibraryTests: XCTestCase {
    @MainActor
    func testChoosingMarksShoeAsWornToday() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let shoe = Shoe(name: "Kängor", type: .boots)
        context.insert(shoe)
        let morning = stockholmDate(2026, 10, 19, 7, 15)

        try WearLibrary.choose(shoe, on: morning, in: context, calendar: stockholm)

        let logs = try context.fetch(FetchDescriptor<WearLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(WearLibrary.chosenShoeID(on: morning, among: logs, calendar: stockholm), shoe.id)
    }

    @MainActor
    func testChoosingAgainTheSameDayReplacesTheChoice() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let boots = Shoe(name: "Kängor", type: .boots)
        let sneakers = Shoe(name: "Rosa Converse", type: .sneakers)
        context.insert(boots)
        context.insert(sneakers)

        try WearLibrary.choose(boots, on: stockholmDate(2026, 10, 19, 7, 0), in: context, calendar: stockholm)
        try WearLibrary.choose(sneakers, on: stockholmDate(2026, 10, 19, 7, 5), in: context, calendar: stockholm)
        try WearLibrary.choose(sneakers, on: stockholmDate(2026, 10, 19, 7, 6), in: context, calendar: stockholm)

        let logs = try context.fetch(FetchDescriptor<WearLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.shoe?.id, sneakers.id)
    }

    @MainActor
    func testEarlierDaysAreKeptAndFeedRotation() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let shoe = Shoe(name: "Rosa Converse", type: .sneakers)
        context.insert(shoe)
        let today = stockholmDate(2026, 10, 19, 7)

        try WearLibrary.choose(shoe, on: stockholmDate(2026, 10, 17, 7), in: context, calendar: stockholm)
        try WearLibrary.choose(shoe, on: stockholmDate(2026, 10, 18, 7), in: context, calendar: stockholm)

        let logs = try context.fetch(FetchDescriptor<WearLog>())
        let history = WearHistory(entries: logs.compactMap(\.entry), today: today, calendar: stockholm)
        XCTAssertEqual(logs.count, 2)
        XCTAssertTrue(history.wasWorn(shoe.id, daysAgo: 1))
        XCTAssertTrue(history.wasWorn(shoe.id, daysAgo: 2))
        XCTAssertNil(WearLibrary.chosenShoeID(on: today, among: logs, calendar: stockholm))
    }
}

final class MorningNotificationTests: XCTestCase {
    func testDefaultTimeIsSevenOClock() {
        XCTAssertEqual(MorningNotification.defaultMinutes, 7 * 60)
    }

    func testRequestRepeatsDailyAtChosenTimeWithSpecText() throws {
        let request = MorningNotification.makeRequest(minutesAfterMidnight: 6 * 60 + 45)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)

        XCTAssertEqual(request.content.body, "Dags att välja skor – öppna Skoväder")
        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 6)
        XCTAssertEqual(trigger.dateComponents.minute, 45)
        XCTAssertEqual(request.identifier, MorningNotification.identifier)
    }
}
