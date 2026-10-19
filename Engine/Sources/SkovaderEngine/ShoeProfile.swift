import Foundation

/// Det regelmotorn behöver veta om en sko. Appens SwiftData-modell `Shoe`
/// översätts till detta så att motorn inte beror på databasen.
public struct ShoeProfile: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var type: ShoeType
    public var isWaterproof: Bool
    public var warmth: WarmthLevel
    public var minTemperature: Int
    public var maxTemperature: Int
    public var isActive: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        type: ShoeType,
        isWaterproof: Bool,
        warmth: WarmthLevel,
        minTemperature: Int,
        maxTemperature: Int,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isWaterproof = isWaterproof
        self.warmth = warmth
        self.minTemperature = minTemperature
        self.maxTemperature = maxTemperature
        self.isActive = isActive
    }

    /// En sko med typens standardvärden.
    public init(id: UUID = UUID(), name: String, type: ShoeType, isActive: Bool = true) {
        let defaults = type.defaults
        self.init(
            id: id,
            name: name,
            type: type,
            isWaterproof: defaults.isWaterproof,
            warmth: defaults.warmth,
            minTemperature: defaults.minTemperature,
            maxTemperature: defaults.maxTemperature,
            isActive: isActive
        )
    }

    /// Byter typ och fyller i typens standardvärden (F4). Namn och aktiv behålls.
    public mutating func applyDefaults(for type: ShoeType) {
        let defaults = type.defaults
        self.type = type
        isWaterproof = defaults.isWaterproof
        warmth = defaults.warmth
        minTemperature = defaults.minTemperature
        maxTemperature = defaults.maxTemperature
    }
}
