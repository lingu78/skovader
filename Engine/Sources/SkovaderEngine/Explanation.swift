import Foundation

/// Bygger motiveringen från mallar i Localizable.strings utifrån vilka
/// regler som slog in, t.ex. "Det blir 4 grader och regn – dina
/// Gummistövlar håller fötterna torra."
public struct ExplanationBuilder: Sendable {
    public var config: RecommendationConfig

    public init(config: RecommendationConfig = .standard) {
        self.config = config
    }

    public func explanation(shoe: ShoeProfile, reason: ShoeReason, weather: DayWeather) -> String {
        L10n.format("explanation.format", weatherSentence(weather), shoeSentence(shoe: shoe, reason: reason))
    }

    /// "Det blir 4 grader och regn", "Det blir -8 till -3 grader och snö".
    public func weatherSentence(_ weather: DayWeather) -> String {
        let low = Int(weather.feelsLikeMin.rounded())
        let high = Int(weather.feelsLikeMax.rounded())

        let temperature: String
        if high - low <= config.temperatureRangeTextSpread {
            let mid = Int(weather.midTemperature.rounded())
            temperature = L10n.format(abs(mid) == 1 ? "weather.temperature.single.one" : "weather.temperature.single", mid)
        } else {
            temperature = L10n.format("weather.temperature.range", low, high)
        }

        var conditions: [String] = []
        if weather.isSnowy(config) {
            conditions.append(L10n.string(weather.precipitationType == .sleet ? "weather.sleet" : "weather.snow"))
        } else if weather.isRainy(config) {
            let heavy = weather.precipitationMM >= config.heavyRainTextThresholdMM
            conditions.append(L10n.string(heavy ? "weather.heavyRain" : "weather.rain"))
        }
        if weather.isWindy(config) {
            conditions.append(L10n.string("weather.windy"))
        }

        switch conditions.count {
        case 0: return temperature
        case 1: return L10n.format("weather.join.one", temperature, conditions[0])
        default: return L10n.format("weather.join.two", temperature, conditions[0], conditions[1])
        }
    }

    public func shoeSentence(shoe: ShoeProfile, reason: ShoeReason) -> String {
        L10n.format("reason.\(reason.key)", shoe.displayName)
    }
}

extension ShoeReason {
    var key: String {
        switch self {
        case .heavyRainRubberBoots: "heavyRainRubberBoots"
        case .snowWinterBoots: "snowWinterBoots"
        case .notWaterproof: "notWaterproof"
        case .tooColdForSnow: "tooColdForSnow"
        case .keepsDry: "keepsDry"
        case .unnecessarilyWarm: "unnecessarilyWarm"
        case .mightBeCold: "mightBeCold"
        case .mightBeWarm: "mightBeWarm"
        case .warmDay: "warmDay"
        case .coldDay: "coldDay"
        case .goodFit: "goodFit"
        }
    }
}
