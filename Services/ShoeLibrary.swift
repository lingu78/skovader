import Foundation
import SwiftData
import SkovaderEngine

/// Sparar och tar bort skor tillsammans med deras bildfiler.
@MainActor
enum ShoeLibrary {
    /// Skapar en ny sko eller uppdaterar en befintlig. `newImage` ersätter en
    /// eventuell tidigare bild, som då tas bort från disken.
    @discardableResult
    static func save(
        _ profile: ShoeProfile,
        image newImage: (data: Data, fileExtension: String)?,
        existing: Shoe?,
        in context: ModelContext,
        images: ImageStore = .shared
    ) throws -> Shoe {
        var fileName = existing?.imageFileName
        if let newImage {
            let newFileName = try images.save(newImage.data, fileExtension: newImage.fileExtension)
            if let fileName { images.delete(fileName) }
            fileName = newFileName
        }

        let shoe: Shoe
        if let existing {
            existing.update(from: profile)
            shoe = existing
        } else {
            shoe = Shoe(profile: profile)
            context.insert(shoe)
        }
        shoe.imageFileName = fileName
        try context.save()
        return shoe
    }

    /// Tar bort skon, dess bild och dess historik.
    static func delete(_ shoe: Shoe, from context: ModelContext, images: ImageStore = .shared) {
        if let fileName = shoe.imageFileName {
            images.delete(fileName)
        }
        context.delete(shoe)
        try? context.save()
    }
}
