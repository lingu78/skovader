import Foundation
import SkovaderEngine

/// Dagens väder i en ikon. Nederbörd och blåst kommer från samma gränser
/// som regelmotorn; sol/moln från timmarnas WMO-koder.
enum WeatherCondition: Equatable, Sendable {
    case clear
    case partlyCloudy
    case cloudy
    case fog
    case rain
    case heavyRain
    case snow
    case sleet
    case thunder
    case windy

    static func forDay(_ day: DayWeather, codes: [Int], config: RecommendationConfig = .standard) -> WeatherCondition {
        if day.precipitationMM >= config.rainThresholdMM {
            if codes.contains(where: { (95...99).contains($0) }) { return .thunder }
            switch day.precipitationType {
            case .snow: return .snow
            case .sleet: return .sleet
            case .rain, .none:
                return day.precipitationMM >= config.heavyRainThresholdMM ? .heavyRain : .rain
            }
        }
        if day.maxWindSpeed >= config.windyThresholdMS { return .windy }

        // Vanligaste himlen under dagen. Vid lika antal vinner den soligaste.
        let skies: [(WeatherCondition, ClosedRange<Int>)] = [
            (.clear, 0...1),
            (.partlyCloudy, 2...2),
            (.cloudy, 3...3),
            (.fog, 45...48),
        ]
        let counts = skies.map { sky in (sky.0, codes.filter { sky.1.contains($0) }.count) }
        guard let best = counts.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return .partlyCloudy }
        return counts.first { $0.1 == best.1 }?.0 ?? best.0
    }

    /// SF Symbol.
    var systemImage: String {
        switch self {
        case .clear: "sun.max.fill"
        case .partlyCloudy: "cloud.sun.fill"
        case .cloudy: "cloud.fill"
        case .fog: "cloud.fog.fill"
        case .rain: "cloud.rain.fill"
        case .heavyRain: "cloud.heavyrain.fill"
        case .snow: "cloud.snow.fill"
        case .sleet: "cloud.sleet.fill"
        case .thunder: "cloud.bolt.rain.fill"
        case .windy: "wind"
        }
    }
}
