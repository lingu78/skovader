import Foundation
import SwiftData
import SkovaderEngine

/// En tryckning på "Jag tar dessa" (F8).
@Model
final class WearLog {
    var date: Date = Date()
    var shoe: Shoe?

    init(shoe: Shoe, date: Date = Date()) {
        self.shoe = shoe
        self.date = date
    }

    /// Det regelmotorn behöver, eller nil om skon har tagits bort.
    var entry: WearEntry? {
        shoe.map { WearEntry(shoeID: $0.id, date: date) }
    }
}
