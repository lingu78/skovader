import Foundation

/// Vädret för tidsfönstret 07–18, sammanfattat till det regelmotorn använder.
public struct DayWeather: Equatable, Sendable {
    /// Lägsta kända temperatur ("feels like"), °C.
    public var feelsLikeMin: Double
    /// Högsta kända temperatur ("feels like"), °C.
    public var feelsLikeMax: Double
    /// Total nederbörd i mm (vattenmängd, även för snö).
    public var precipitationMM: Double
    public var precipitationType: PrecipitationType
    /// Högsta vindstyrka i m/s.
    public var maxWindSpeed: Double

    public init(
        feelsLikeMin: Double,
        feelsLikeMax: Double,
        precipitationMM: Double = 0,
        precipitationType: PrecipitationType = .none,
        maxWindSpeed: Double = 0
    ) {
        self.feelsLikeMin = min(feelsLikeMin, feelsLikeMax)
        self.feelsLikeMax = max(feelsLikeMin, feelsLikeMax)
        self.precipitationMM = max(0, precipitationMM)
        self.precipitationType = precipitationType
        self.maxWindSpeed = max(0, maxWindSpeed)
    }
}

public enum PrecipitationType: String, Codable, Sendable {
    case none
    case rain
    case snow
    /// Snöblandat regn: både regn- och snöreglerna gäller.
    case sleet

    var involvesRain: Bool { self == .rain || self == .sleet }
    var involvesSnow: Bool { self == .snow || self == .sleet }
}

extension DayWeather {
    func isRainy(_ config: RecommendationConfig) -> Bool {
        precipitationType.involvesRain && precipitationMM >= config.rainThresholdMM
    }

    func isHeavyRain(_ config: RecommendationConfig) -> Bool {
        precipitationType.involvesRain && precipitationMM >= config.heavyRainThresholdMM
    }

    func isSnowy(_ config: RecommendationConfig) -> Bool {
        precipitationType.involvesSnow && precipitationMM >= config.snowThresholdMM
    }

    func isDry(_ config: RecommendationConfig) -> Bool {
        precipitationMM < config.rainThresholdMM
    }

    func isWindy(_ config: RecommendationConfig) -> Bool {
        maxWindSpeed >= config.windyThresholdMS
    }

    var midTemperature: Double { (feelsLikeMin + feelsLikeMax) / 2 }
}
