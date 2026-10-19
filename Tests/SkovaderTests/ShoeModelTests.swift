import XCTest
import SwiftData
import SkovaderEngine
@testable import Skovader

final class ShoeModelTests: XCTestCase {
    func testNewShoeGetsTypeDefaults() {
        let shoe = Shoe(name: "Vinterkängor", type: .winterBoots)

        XCTAssertEqual(shoe.type, .winterBoots)
        XCTAssertTrue(shoe.isWaterproof)
        XCTAssertEqual(shoe.warmth, .warm)
        XCTAssertEqual(shoe.minTemperature, -30)
        XCTAssertEqual(shoe.maxTemperature, 5)
        XCTAssertTrue(shoe.isActive)
    }

    func testChangingTypeRefillsDefaults() {
        let shoe = Shoe(name: "Mina skor", type: .sandals)
        shoe.applyDefaults(for: .rubberBoots)

        XCTAssertEqual(shoe.typeRaw, "rubberBoots")
        XCTAssertTrue(shoe.isWaterproof)
        XCTAssertEqual(shoe.warmth, .light)
        XCTAssertEqual(shoe.minTemperature, 0)
        XCTAssertEqual(shoe.maxTemperature, 20)
    }

    func testProfileMirrorsEditedFields() {
        let shoe = Shoe(name: "Rosa Converse", type: .sneakers)
        shoe.isWaterproof = true
        shoe.warmth = .medium
        shoe.minTemperature = 5
        shoe.isActive = false

        let profile = shoe.profile

        XCTAssertEqual(profile.id, shoe.id)
        XCTAssertEqual(profile.name, "Rosa Converse")
        XCTAssertEqual(profile.type, .sneakers)
        XCTAssertTrue(profile.isWaterproof)
        XCTAssertEqual(profile.warmth, .medium)
        XCTAssertEqual(profile.minTemperature, 5)
        XCTAssertEqual(profile.maxTemperature, 30)
        XCTAssertFalse(profile.isActive)
    }

    func testUnknownStoredTypeFallsBackSafely() {
        let shoe = Shoe(name: "Okänd", type: .boots)
        shoe.typeRaw = "somethingNew"

        XCTAssertEqual(shoe.type, .sneakers)
    }

    func testTitleFallsBackToTypeName() {
        XCTAssertEqual(Shoe(name: "", type: .rubberBoots).title, "Gummistövlar")
        XCTAssertEqual(Shoe(name: "Stövlar", type: .rubberBoots).title, "Stövlar")
    }

    func testUpdateFromProfileTrimsNameAndOrdersTemperatures() {
        var profile = ShoeProfile(name: "  Kängor ", type: .boots)
        profile.minTemperature = 10
        profile.maxTemperature = 2

        let shoe = Shoe(profile: profile)

        XCTAssertEqual(shoe.id, profile.id)
        XCTAssertEqual(shoe.name, "Kängor")
        XCTAssertEqual(shoe.minTemperature, 2)
        XCTAssertEqual(shoe.maxTemperature, 10)
    }

    @MainActor
    func testShoeAndWearLogArePersisted() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let shoe = Shoe(name: "Kängor", type: .boots)
        context.insert(shoe)
        let log = WearLog(shoe: shoe, date: Date())
        context.insert(log)
        try context.save()

        let shoes = try context.fetch(FetchDescriptor<Shoe>())
        XCTAssertEqual(shoes.map(\.name), ["Kängor"])
        XCTAssertEqual(log.entry?.shoeID, shoe.id)
    }
}
