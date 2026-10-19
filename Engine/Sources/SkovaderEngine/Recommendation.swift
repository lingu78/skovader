import Foundation

/// Resultatet av regelmotorn för en dag.
public enum Recommendation: Equatable, Sendable {
    /// Användaren har inte lagt in några skor (F10).
    case noShoes
    /// Det finns skor, men alla är markerade som inaktiva.
    case noActiveShoes
    case suggestion(Suggestion)
}

public struct Suggestion: Equatable, Sendable {
    public let weather: DayWeather
    public let primary: ScoredShoe
    /// Upp till `maxAlternatives` alternativ, bäst först.
    public let alternatives: [ScoredShoe]
    /// Falskt när ingen sko har över `goodFitThreshold` poäng, eller när alla
    /// skor föll bort i filtreringen. `primary` är då den som passar bäst ändå.
    public let isGoodFit: Bool

    /// "Inga av dina skor passar riktigt idag – närmast är …", eller nil.
    public var poorFitMessage: String? {
        isGoodFit ? nil : L10n.format("poorFit.message", primary.shoe.displayName)
    }
}

/// En sko med poäng, vilka regler som slog in och motivering i klartext.
public struct ScoredShoe: Equatable, Sendable, Identifiable {
    public var id: UUID { shoe.id }
    public let shoe: ShoeProfile
    public let score: Double
    public let hits: [RuleHit]
    /// Om skon klarade steg 1 (aktiv och inom ±tolerans).
    public let passedFilter: Bool
    public let reason: ShoeReason
    /// T.ex. "Det blir 4 grader och regn – dina Gummistövlar håller fötterna torra."
    public let explanation: String

    public func hit(_ kind: RuleHit.Kind) -> RuleHit? {
        hits.first { $0.kind == kind }
    }
}

/// En regel från steg 2 som påverkade poängen.
public struct RuleHit: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case colderThanRange
        case warmerThanRange
        case rainNotWaterproof
        case heavyRainRubberBoots
        case snowLowWarmth
        case snowWinterBoots
        case dryWarmDayWinterShoe
        case wornYesterday
        case wornTwoDaysInRow
    }

    public let kind: Kind
    /// Poängförändring, negativ för avdrag.
    public let points: Double
    /// Grader utanför intervallet för temperaturreglerna, annars 0.
    public let degrees: Double

    public init(kind: Kind, points: Double, degrees: Double = 0) {
        self.kind = kind
        self.points = points
        self.degrees = degrees
    }
}

/// Huvudskälet som motiveringen bygger på.
public enum ShoeReason: Equatable, Sendable {
    case heavyRainRubberBoots
    case snowWinterBoots
    case notWaterproof
    case tooColdForSnow
    case keepsDry
    case unnecessarilyWarm
    case mightBeCold
    case mightBeWarm
    case warmDay
    case coldDay
    case goodFit
}

extension ShoeProfile {
    /// Namnet, eller typens namn om användaren lämnat det tomt.
    public var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.string("shoeType.\(type.rawValue).short") : trimmed
    }
}
