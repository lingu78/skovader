import SwiftData
import UIKit
@testable import Skovader

/// Enfärgad testbild med skala 1, så att storlek i punkter = pixlar.
func makeImage(width: CGFloat, height: CGFloat, color: UIColor = .systemTeal) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
        color.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

/// Bildlager i en egen tillfällig mapp.
func makeTemporaryImageStore() -> ImageStore {
    ImageStore(directory: FileManager.default.temporaryDirectory
        .appending(path: "SkovaderTests-\(UUID().uuidString)", directoryHint: .isDirectory))
}

/// Databas i minnet. Behåll containern så länge dess `mainContext` används.
func makeInMemoryContainer() throws -> ModelContainer {
    try ModelContainer(
        for: Shoe.self, WearLog.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}
