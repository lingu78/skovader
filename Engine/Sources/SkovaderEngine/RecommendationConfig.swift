import Foundation

/// Alla tal i regelmotorn samlade på ett ställe så att de kan justeras
/// efter testveckan. Avsnitt "Rekommendationslogik" i kravspecen.
public struct RecommendationConfig: Equatable, Sendable {

    // MARK: Steg 1 – filtrering

    /// En sko filtreras bort om dagens min ligger mer än så här många grader
    /// under skons min, eller dagens max mer än så här över skons max.
    public var filterToleranceDegrees: Double = 5

    // MARK: Steg 2 – poäng

    public var startScore: Double = 100

    /// Avdrag per grad som dagen ligger utanför skons temperaturintervall.
    public var pointsPerDegreeOutsideRange: Double = 5

    /// Nederbörd (mm, 07–18) som räknas som regn. Under detta är det "torrt".
    public var rainThresholdMM: Double = 1
    public var rainNotWaterproofPenalty: Double = 40

    public var heavyRainThresholdMM: Double = 5
    public var heavyRainRubberBootsBonus: Double = 20

    /// Nederbörd (mm vatten, 07–18) som krävs för att snöreglerna ska slå in.
    public var snowThresholdMM: Double = 1
    /// Värmenivå som krävs för att slippa snöavdraget.
    public var snowRequiredWarmth: WarmthLevel = .warm
    public var snowLowWarmthPenalty: Double = 30
    public var snowWinterBootsBonus: Double = 20

    /// Torrt och dagens max över detta: vattentäta skor med värme 3 får avdrag.
    public var dryWarmDayThreshold: Double = 10
    public var dryWarmDayWinterShoePenalty: Double = 20

    public var wornYesterdayPenalty: Double = 10
    /// Ersätter `wornYesterdayPenalty` när skon använts både igår och i förrgår.
    public var wornTwoDaysInRowPenalty: Double = 20

    // MARK: Steg 3 – resultat

    /// Om ingen sko har mer än så här många poäng visas "passar inte riktigt".
    public var goodFitThreshold: Double = 50
    public var maxAlternatives: Int = 2

    // MARK: Motivering

    /// Max vindstyrka (m/s) då motiveringen nämner att det blåser.
    /// Påverkar inte poängen – vinden finns redan med i den kända temperaturen.
    public var windyThresholdMS: Double = 10
    /// Mer nederbörd än så här (mm) beskrivs som "mycket regn".
    public var heavyRainTextThresholdMM: Double = 5
    /// Över denna kända max-temperatur beskrivs dagen som varm.
    public var warmDayTextThreshold: Double = 18
    /// Under denna kända min-temperatur beskrivs dagen som kall.
    public var coldDayTextThreshold: Double = 5
    /// Så här många grader utanför intervallet innan motiveringen varnar
    /// för att det kan bli för kallt/varmt.
    public var temperatureWarningDegrees: Double = 2
    /// Visa ett intervall ("2 till 9 grader") när skillnaden är större än så här.
    public var temperatureRangeTextSpread: Int = 3

    public init() {}

    public static let standard = RecommendationConfig()

    // MARK: Standardvärden per skotyp (F4)

    public static let typeDefaults: [ShoeType: ShoeDefaults] = [
        .sandals: ShoeDefaults(isWaterproof: false, warmth: .light, minTemperature: 18, maxTemperature: 40),
        .sneakers: ShoeDefaults(isWaterproof: false, warmth: .light, minTemperature: 8, maxTemperature: 30),
        .leatherSneakers: ShoeDefaults(isWaterproof: false, warmth: .medium, minTemperature: 3, maxTemperature: 25),
        .waterproofSneakers: ShoeDefaults(isWaterproof: true, warmth: .medium, minTemperature: 0, maxTemperature: 22),
        .boots: ShoeDefaults(isWaterproof: true, warmth: .medium, minTemperature: -5, maxTemperature: 15),
        .winterBoots: ShoeDefaults(isWaterproof: true, warmth: .warm, minTemperature: -30, maxTemperature: 5),
        .rubberBoots: ShoeDefaults(isWaterproof: true, warmth: .light, minTemperature: 0, maxTemperature: 20),
    ]

    static let fallbackDefaults = ShoeDefaults(isWaterproof: false, warmth: .medium, minTemperature: 5, maxTemperature: 25)
}
