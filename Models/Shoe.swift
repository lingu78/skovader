import Foundation
import SwiftData
import SkovaderEngine

/// Ett skopar (F3). Alla fält har standardvärden och inga unika index, så att
/// modellen kan synkas med iCloud senare utan migrering av befintliga data.
@Model
final class Shoe {
    var id: UUID = UUID()
    var name: String = ""
    /// `ShoeType.rawValue`. Läs och skriv via `type`.
    var typeRaw: String = ShoeType.sneakers.rawValue
    var isWaterproof: Bool = false
    /// `WarmthLevel.rawValue` (1–3). Läs och skriv via `warmth`.
    var warmthRaw: Int = WarmthLevel.light.rawValue
    var minTemperature: Int = 8
    var maxTemperature: Int = 30
    var isActive: Bool = true
    /// Bildens filnamn i appens Documents-mapp. Relativt, eftersom den absoluta
    /// sökvägen till appens mapp kan ändras mellan installationer.
    var imageFileName: String?
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \WearLog.shoe)
    var wearLogs: [WearLog]? = []

    /// Ny sko med typens standardvärden (F4).
    init(name: String, type: ShoeType, imageFileName: String? = nil) {
        self.id = UUID()
        self.name = name
        self.imageFileName = imageFileName
        self.createdAt = Date()
        applyDefaults(for: type)
    }

    /// Ny sko från redigerarens utkast.
    init(profile: ShoeProfile, imageFileName: String? = nil) {
        self.id = profile.id
        self.imageFileName = imageFileName
        self.createdAt = Date()
        update(from: profile)
    }

    var type: ShoeType {
        get { ShoeType(rawValue: typeRaw) ?? .sneakers }
        set { typeRaw = newValue.rawValue }
    }

    var warmth: WarmthLevel {
        get { WarmthLevel(rawValue: warmthRaw) ?? .medium }
        set { warmthRaw = newValue.rawValue }
    }

    /// Byter typ och fyller i typens standardvärden. Användaren kan sedan
    /// ändra varje fält för sig.
    func applyDefaults(for type: ShoeType) {
        let defaults = type.defaults
        self.type = type
        isWaterproof = defaults.isWaterproof
        warmth = defaults.warmth
        minTemperature = defaults.minTemperature
        maxTemperature = defaults.maxTemperature
    }

    /// Skriver in utkastets fält. `id` ändras inte.
    func update(from profile: ShoeProfile) {
        name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        type = profile.type
        isWaterproof = profile.isWaterproof
        warmth = profile.warmth
        minTemperature = min(profile.minTemperature, profile.maxTemperature)
        maxTemperature = max(profile.minTemperature, profile.maxTemperature)
        isActive = profile.isActive
    }

    /// Namnet, eller typens namn om skon saknar namn.
    var title: String {
        name.isEmpty ? type.localizedName : name
    }

    /// Det regelmotorn behöver.
    var profile: ShoeProfile {
        ShoeProfile(
            id: id,
            name: name,
            type: type,
            isWaterproof: isWaterproof,
            warmth: warmth,
            minTemperature: minTemperature,
            maxTemperature: maxTemperature,
            isActive: isActive
        )
    }
}
