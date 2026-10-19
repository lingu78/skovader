import Foundation

/// Regelmotorn: filtrera, poängsätt och välj skor för dagens väder.
/// Ingen AI – bara reglerna i `RecommendationConfig`.
public struct RecommendationEngine: Sendable {
    public var config: RecommendationConfig

    public init(config: RecommendationConfig = .standard) {
        self.config = config
    }

    public func recommend(
        shoes: [ShoeProfile],
        weather: DayWeather,
        history: WearHistory = .empty
    ) -> Recommendation {
        guard !shoes.isEmpty else { return .noShoes }

        let active = shoes.filter(\.isActive)
        guard !active.isEmpty else { return .noActiveShoes }

        let scored = active.map { score($0, weather: weather, history: history) }
        let passing = scored.filter(\.passedFilter)
        // Föll alla bort i steg 1 visar vi ändå den som ligger närmast.
        let pool = passing.isEmpty ? scored : passing
        let ranked = pool.sorted { ranksBefore($0, $1, weather: weather, history: history) }

        let primary = ranked[0]
        let alternatives = Array(ranked.dropFirst().prefix(config.maxAlternatives))
        let isGoodFit = !passing.isEmpty && primary.score > config.goodFitThreshold

        return .suggestion(Suggestion(
            weather: weather,
            primary: primary,
            alternatives: alternatives,
            isGoodFit: isGoodFit
        ))
    }

    /// Steg 1 och 2 för en enskild sko.
    public func score(_ shoe: ShoeProfile, weather: DayWeather, history: WearHistory = .empty) -> ScoredShoe {
        let c = config
        var hits: [RuleHit] = []

        let degreesBelow = max(0, Double(shoe.minTemperature) - weather.feelsLikeMin)
        let degreesAbove = max(0, weather.feelsLikeMax - Double(shoe.maxTemperature))
        if degreesBelow > 0 {
            hits.append(RuleHit(kind: .colderThanRange, points: -degreesBelow * c.pointsPerDegreeOutsideRange, degrees: degreesBelow))
        }
        if degreesAbove > 0 {
            hits.append(RuleHit(kind: .warmerThanRange, points: -degreesAbove * c.pointsPerDegreeOutsideRange, degrees: degreesAbove))
        }

        if weather.isRainy(c) && !shoe.isWaterproof {
            hits.append(RuleHit(kind: .rainNotWaterproof, points: -c.rainNotWaterproofPenalty))
        }
        if weather.isHeavyRain(c) && shoe.type == .rubberBoots {
            hits.append(RuleHit(kind: .heavyRainRubberBoots, points: c.heavyRainRubberBootsBonus))
        }

        if weather.isSnowy(c) && shoe.warmth < c.snowRequiredWarmth {
            hits.append(RuleHit(kind: .snowLowWarmth, points: -c.snowLowWarmthPenalty))
        }
        if weather.isSnowy(c) && shoe.type == .winterBoots {
            hits.append(RuleHit(kind: .snowWinterBoots, points: c.snowWinterBootsBonus))
        }

        if weather.isDry(c) && shoe.isWaterproof && shoe.warmth == .warm
            && weather.feelsLikeMax > c.dryWarmDayThreshold {
            hits.append(RuleHit(kind: .dryWarmDayWinterShoe, points: -c.dryWarmDayWinterShoePenalty))
        }

        if history.wasWorn(shoe.id, daysAgo: 1) {
            if history.wasWorn(shoe.id, daysAgo: 2) {
                hits.append(RuleHit(kind: .wornTwoDaysInRow, points: -c.wornTwoDaysInRowPenalty))
            } else {
                hits.append(RuleHit(kind: .wornYesterday, points: -c.wornYesterdayPenalty))
            }
        }

        let passedFilter = shoe.isActive
            && degreesBelow <= c.filterToleranceDegrees
            && degreesAbove <= c.filterToleranceDegrees

        let reason = reason(for: shoe, hits: hits, weather: weather)
        return ScoredShoe(
            shoe: shoe,
            score: c.startScore + hits.reduce(0) { $0 + $1.points },
            hits: hits,
            passedFilter: passedFilter,
            reason: reason,
            explanation: ExplanationBuilder(config: c).explanation(shoe: shoe, reason: reason, weather: weather)
        )
    }

    // MARK: - Steg 3

    /// Högst poäng först. Vid lika poäng: den vars intervall ligger närmast
    /// dagens temperatur, sedan den som inte använts på längst tid, sedan namn.
    private func ranksBefore(_ a: ScoredShoe, _ b: ScoredShoe, weather: DayWeather, history: WearHistory) -> Bool {
        if a.score != b.score { return a.score > b.score }

        let distanceA = abs(a.shoe.midTemperature - weather.midTemperature)
        let distanceB = abs(b.shoe.midTemperature - weather.midTemperature)
        if distanceA != distanceB { return distanceA < distanceB }

        let lastA = history.daysSinceLastWorn(a.shoe.id) ?? Int.max
        let lastB = history.daysSinceLastWorn(b.shoe.id) ?? Int.max
        if lastA != lastB { return lastA > lastB }

        let nameA = a.shoe.displayName.lowercased()
        let nameB = b.shoe.displayName.lowercased()
        if nameA != nameB { return nameA < nameB }

        return a.shoe.id.uuidString < b.shoe.id.uuidString
    }

    // MARK: - Motivering

    private func reason(for shoe: ShoeProfile, hits: [RuleHit], weather: DayWeather) -> ShoeReason {
        func has(_ kind: RuleHit.Kind) -> Bool { hits.contains { $0.kind == kind } }
        func degrees(_ kind: RuleHit.Kind) -> Double { hits.first { $0.kind == kind }?.degrees ?? 0 }

        if has(.heavyRainRubberBoots) { return .heavyRainRubberBoots }
        if has(.snowWinterBoots) { return .snowWinterBoots }
        if has(.rainNotWaterproof) { return .notWaterproof }
        if has(.snowLowWarmth) { return .tooColdForSnow }
        if shoe.isWaterproof && (weather.isRainy(config) || weather.isSnowy(config)) { return .keepsDry }
        if has(.dryWarmDayWinterShoe) { return .unnecessarilyWarm }
        if degrees(.colderThanRange) > config.temperatureWarningDegrees { return .mightBeCold }
        if degrees(.warmerThanRange) > config.temperatureWarningDegrees { return .mightBeWarm }
        if weather.feelsLikeMax >= config.warmDayTextThreshold { return .warmDay }
        if weather.feelsLikeMin < config.coldDayTextThreshold { return .coldDay }
        return .goodFit
    }
}

extension ShoeProfile {
    var midTemperature: Double { Double(minTemperature + maxTemperature) / 2 }
}
