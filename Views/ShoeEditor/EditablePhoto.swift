import Observation
import UIKit

/// En nyss vald bild i redigeraren: nedskalat original och eventuell
/// utklippt version. Bearbetningen sker utanför huvudtråden.
@Observable
final class EditablePhoto {
    private(set) var original: UIImage?
    private(set) var cutout: UIImage?
    private(set) var isProcessing = false
    private var cutoutAttempted = false

    var hasImage: Bool { original != nil }

    /// Bilden som visas och sparas. Misslyckad utklippning ger originalet (F2).
    func image(useCutout: Bool) -> UIImage? {
        useCutout ? (cutout ?? original) : original
    }

    func isCutout(useCutout: Bool) -> Bool {
        useCutout && cutout != nil
    }

    @MainActor
    func load(_ image: UIImage, cutOut: Bool) async {
        isProcessing = true
        let scaled = await Task.detached(priority: .userInitiated) {
            ImageProcessor.downscaled(image)
        }.value
        original = scaled
        cutout = nil
        cutoutAttempted = false
        if cutOut {
            await makeCutoutIfNeeded()
        }
        isProcessing = false
    }

    /// Klipper ut skon om det inte redan är gjort för den här bilden.
    @MainActor
    func makeCutoutIfNeeded() async {
        guard let original, !cutoutAttempted else { return }
        cutoutAttempted = true
        isProcessing = true
        cutout = await Task.detached(priority: .userInitiated) {
            ImageProcessor.cutOut(original)
        }.value
        isProcessing = false
    }
}
