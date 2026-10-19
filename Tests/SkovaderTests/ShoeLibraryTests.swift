import SwiftData
import XCTest
import SkovaderEngine
@testable import Skovader

final class ShoeLibraryTests: XCTestCase {
    @MainActor
    func testSaveNewShoeReplaceImageAndDelete() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let store = makeTemporaryImageStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        // Ny sko med foto.
        var draft = ShoeProfile(name: "  Rosa Converse ", type: .sneakers)
        let photo = try XCTUnwrap(ImageProcessor.encode(makeImage(width: 10, height: 10), isCutout: false))
        let shoe = try ShoeLibrary.save(draft, image: photo, existing: nil, in: context, images: store)
        let firstFile = try XCTUnwrap(shoe.imageFileName)

        XCTAssertEqual(shoe.name, "Rosa Converse")
        XCTAssertEqual(shoe.id, draft.id)
        XCTAssertNotNil(store.image(named: firstFile))

        // Redigering med ny, utklippt bild: den gamla filen tas bort.
        draft.isWaterproof = true
        let cutout = try XCTUnwrap(ImageProcessor.encode(makeImage(width: 10, height: 10), isCutout: true))
        try ShoeLibrary.save(draft, image: cutout, existing: shoe, in: context, images: store)
        let secondFile = try XCTUnwrap(shoe.imageFileName)

        XCTAssertTrue(shoe.isWaterproof)
        XCTAssertTrue(secondFile.hasSuffix(".png"))
        XCTAssertNil(store.image(named: firstFile))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Shoe>()), 1)

        // Borttagning tar bilden och historiken också.
        context.insert(WearLog(shoe: shoe))
        try context.save()
        ShoeLibrary.delete(shoe, from: context, images: store)

        XCTAssertNil(store.image(named: secondFile))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Shoe>()), 0)
    }

    @MainActor
    func testSavingWithoutNewImageKeepsTheOldOne() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let store = makeTemporaryImageStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let photo = try XCTUnwrap(ImageProcessor.encode(makeImage(width: 10, height: 10), isCutout: false))
        var draft = ShoeProfile(name: "Kängor", type: .boots)
        let shoe = try ShoeLibrary.save(draft, image: photo, existing: nil, in: context, images: store)
        let fileName = shoe.imageFileName

        draft.name = "Bruna kängor"
        try ShoeLibrary.save(draft, image: nil, existing: shoe, in: context, images: store)

        XCTAssertEqual(shoe.name, "Bruna kängor")
        XCTAssertEqual(shoe.imageFileName, fileName)
        XCTAssertNotNil(fileName.flatMap(store.image(named:)))
    }

    @MainActor
    func testShoeWithoutPhotoCanBeSaved() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let shoe = try ShoeLibrary.save(ShoeProfile(name: "", type: .rubberBoots), image: nil, existing: nil, in: context)

        XCTAssertNil(shoe.imageFileName)
        XCTAssertEqual(shoe.title, "Gummistövlar")
    }
}
