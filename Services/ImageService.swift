import CoreImage
import UIKit
import Vision

/// Sparar och läser skobilder som filer i Documents/ShoeImages (F1).
/// Modellen sparar bara filnamnet.
struct ImageStore {
    let directory: URL

    static let shared = ImageStore(
        directory: URL.documentsDirectory.appending(path: "ShoeImages", directoryHint: .isDirectory)
    )

    /// Sparar datan under ett nytt unikt filnamn och returnerar det.
    func save(_ data: Data, fileExtension: String) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        try data.write(to: url(for: fileName), options: .atomic)
        return fileName
    }

    func url(for fileName: String) -> URL {
        directory.appending(path: fileName, directoryHint: .notDirectory)
    }

    func image(named fileName: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: fileName).path(percentEncoded: false))
    }

    /// Läser och avkodar bilden utanför huvudtråden.
    func loadImage(named fileName: String?) async -> UIImage? {
        guard let fileName else { return nil }
        let store = self
        return await Task.detached(priority: .userInitiated) {
            store.image(named: fileName)?.preparingForDisplay()
        }.value
    }

    func delete(_ fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }
}

/// Nedskalning och utklippning av skobilder (F1, F2).
enum ImageProcessor {
    static let maxLongSide: CGFloat = 1024
    static let jpegQuality: CGFloat = 0.8

    /// Storlek i pixlar med längsta sidan högst `maxLongSide`. Mindre bilder
    /// förstoras inte.
    static func fittedSize(for size: CGSize, maxLongSide: CGFloat = maxLongSide) -> CGSize {
        let longSide = max(size.width, size.height)
        guard longSide > maxLongSide else {
            return CGSize(width: size.width.rounded(), height: size.height.rounded())
        }
        let scale = maxLongSide / longSide
        return CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    }

    /// Skalar ner till högst 1024 px lång sida och ritar om bilden så att
    /// den står rätt (kamerabilder har ofta en rotationsflagga).
    static func downscaled(_ image: UIImage) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let target = fittedSize(for: pixelSize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Klipper ut skon från bakgrunden med Vision och returnerar en bild med
    /// transparent bakgrund, beskuren runt skon. Nil om det inte går – då
    /// används originalbilden utan felmeddelande (F2). I simulatorn går det
    /// aldrig, eftersom Vision behöver telefonens Neural Engine.
    static func cutOut(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        do {
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
                return nil
            }
            let buffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: true
            )
            let masked = CIImage(cvPixelBuffer: buffer)
            guard let output = CIContext().createCGImage(masked, from: masked.extent) else { return nil }
            return UIImage(cgImage: output)
        } catch {
            return nil
        }
    }

    /// Utklippta bilder sparas som PNG (transparens), övriga som JPEG.
    static func encode(_ image: UIImage, isCutout: Bool) -> (data: Data, fileExtension: String)? {
        if isCutout {
            return image.pngData().map { ($0, "png") }
        }
        return image.jpegData(compressionQuality: jpegQuality).map { ($0, "jpg") }
    }
}
