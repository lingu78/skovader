import Foundation

/// Skotyperna från kravspecen. `rawValue` sparas i databasen och får inte ändras.
public enum ShoeType: String, CaseIterable, Codable, Sendable, Identifiable {
    case sandals
    case sneakers
    case leatherSneakers
    case waterproofSneakers
    case boots
    case winterBoots
    case rubberBoots

    public var id: String { rawValue }

    /// Standardvärden som fylls i när användaren väljer typ (F4).
    public var defaults: ShoeDefaults {
        RecommendationConfig.typeDefaults[self] ?? RecommendationConfig.fallbackDefaults
    }

    /// Visningsnamn, t.ex. "Vinterkängor / fodrade".
    public var localizedName: String {
        L10n.string("shoeType.\(rawValue)")
    }
}

/// Värdena i tabellen "Standardvärden per skotyp".
public struct ShoeDefaults: Equatable, Sendable {
    public var isWaterproof: Bool
    public var warmth: WarmthLevel
    public var minTemperature: Int
    public var maxTemperature: Int

    public init(isWaterproof: Bool, warmth: WarmthLevel, minTemperature: Int, maxTemperature: Int) {
        self.isWaterproof = isWaterproof
        self.warmth = warmth
        self.minTemperature = minTemperature
        self.maxTemperature = maxTemperature
    }
}

/// Värmenivå 1 lätt / 2 mellan / 3 varm (F3).
public enum WarmthLevel: Int, CaseIterable, Codable, Sendable, Comparable, Identifiable {
    case light = 1
    case medium = 2
    case warm = 3

    public var id: Int { rawValue }

    public var localizedName: String {
        L10n.string("warmth.\(rawValue)")
    }

    public static func < (lhs: WarmthLevel, rhs: WarmthLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
