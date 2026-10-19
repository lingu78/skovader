import XCTest
@testable import Skovader

final class ImageProcessorTests: XCTestCase {
    func testFittedSizeKeepsAspectRatioWithin1024() {
        XCTAssertEqual(ImageProcessor.fittedSize(for: CGSize(width: 4032, height: 3024)), CGSize(width: 1024, height: 768))
        XCTAssertEqual(ImageProcessor.fittedSize(for: CGSize(width: 3024, height: 4032)), CGSize(width: 768, height: 1024))
    }

    func testSmallImagesAreNotEnlarged() {
        XCTAssertEqual(ImageProcessor.fittedSize(for: CGSize(width: 800, height: 600)), CGSize(width: 800, height: 600))
    }

    func testDownscaledImageHasLongSideAtMost1024Pixels() {
        let scaled = ImageProcessor.downscaled(makeImage(width: 3000, height: 2000))

        XCTAssertEqual(scaled.scale, 1)
        XCTAssertEqual(scaled.size, CGSize(width: 1024, height: 683))
    }

    func testCutoutIsSavedAsPNGAndPhotoAsJPEG() throws {
        let image = makeImage(width: 100, height: 50)

        let cutout = try XCTUnwrap(ImageProcessor.encode(image, isCutout: true))
        let photo = try XCTUnwrap(ImageProcessor.encode(image, isCutout: false))

        XCTAssertEqual(cutout.fileExtension, "png")
        XCTAssertEqual(photo.fileExtension, "jpg")
        XCTAssertEqual(Array(cutout.data.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
        XCTAssertEqual(Array(photo.data.prefix(2)), [0xFF, 0xD8])
    }

    func testCutoutFailureReturnsNilInsteadOfThrowing() {
        // I simulatorn kan Vision inte klippa ut; det ska ge nil, inte krascha.
        // En enfärgad bild har ingen förgrund att klippa ut på en telefon heller.
        XCTAssertNil(ImageProcessor.cutOut(makeImage(width: 200, height: 200)))
    }
}

final class ImageStoreTests: XCTestCase {
    func testSaveLoadAndDelete() async throws {
        let store = makeTemporaryImageStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        let data = try XCTUnwrap(makeImage(width: 40, height: 30).pngData())

        let fileName = try store.save(data, fileExtension: "png")

        XCTAssertTrue(fileName.hasSuffix(".png"))
        XCTAssertNotNil(store.image(named: fileName))
        let loaded = await store.loadImage(named: fileName)
        XCTAssertEqual(loaded?.size, CGSize(width: 40, height: 30))

        store.delete(fileName)
        XCTAssertNil(store.image(named: fileName))
    }

    func testEverySaveGetsAUniqueFileName() throws {
        let store = makeTemporaryImageStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }

        let first = try store.save(Data([1]), fileExtension: "jpg")
        let second = try store.save(Data([1]), fileExtension: "jpg")

        XCTAssertNotEqual(first, second)
    }

    func testMissingFileGivesNil() async {
        let store = makeTemporaryImageStore()

        let missing = await store.loadImage(named: "finns-inte.png")
        let none = await store.loadImage(named: nil)

        XCTAssertNil(missing)
        XCTAssertNil(none)
    }
}
