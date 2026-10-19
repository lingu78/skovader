import Foundation

/// En timme ur prognosen, oberoende av vädertjänst. Momentana värden
/// (temperatur, vind) gäller vid `time`; nederbörden är summan för timmen
/// före `time`, som hos Open-Meteo, MET Norway och WeatherKit.
public struct HourlyWeather: Equatable, Sendable {
    public var time: Date
    /// Känd temperatur ("feels like"), °C.
    public var apparentTemperature: Double
    /// All nederbörd, mm vattenmängd.
    public var precipitationMM: Double
    /// Regn och skurar, mm.
    public var rainMM: Double
    /// Snö, cm.
    public var snowfallCM: Double
    /// Vind, m/s.
    public var windSpeed: Double

    public init(
        time: Date,
        apparentTemperature: Double,
        precipitationMM: Double = 0,
        rainMM: Double = 0,
        snowfallCM: Double = 0,
        windSpeed: Double = 0
    ) {
        self.time = time
        self.apparentTemperature = apparentTemperature
        self.precipitationMM = precipitationMM
        self.rainMM = rainMM
        self.snowfallCM = snowfallCM
        self.windSpeed = windSpeed
    }
}

extension DayWeather {
    /// 7 cm snö motsvarar ungefär 10 mm vatten.
    static let snowWaterMMPerCM = 10.0 / 7.0

    /// Sammanfattar timdata till fönstret 07–18 den dag `day` infaller i
    /// `calendar`s tidszon. Temperatur och vind tas från timmarna 07–18,
    /// nederbörd från timmarna 08–18 (som var och en gäller timmen före).
    /// Nil om prognosen saknar timmar i fönstret.
    public static func summarizing(
        _ hours: [HourlyWeather],
        on day: Date,
        calendar: Calendar,
        config: RecommendationConfig = .standard
    ) -> DayWeather? {
        let start = config.weatherWindowStartHour
        let end = config.weatherWindowEndHour
        let sameDay = hours.filter { calendar.isDate($0.time, inSameDayAs: day) }
        func hour(_ entry: HourlyWeather) -> Int { calendar.component(.hour, from: entry.time) }

        let instant = sameDay.filter { (start...end).contains(hour($0)) }
        guard let minTemperature = instant.map(\.apparentTemperature).min(),
              let maxTemperature = instant.map(\.apparentTemperature).max() else {
            return nil
        }

        let wet = sameDay.filter { (start + 1...max(start + 1, end)).contains(hour($0)) }
        let total = wet.reduce(0) { $0 + $1.precipitationMM }
        let liquid = wet.reduce(0) { $0 + $1.rainMM }
        let frozen = wet.reduce(0) { $0 + $1.snowfallCM } * snowWaterMMPerCM

        return DayWeather(
            feelsLikeMin: minTemperature,
            feelsLikeMax: maxTemperature,
            precipitationMM: max(total, liquid + frozen),
            precipitationType: precipitationType(liquid: liquid, frozen: frozen, total: total, config: config),
            maxWindSpeed: instant.map(\.windSpeed).max() ?? 0
        )
    }

    static func precipitationType(liquid: Double, frozen: Double, total: Double, config: RecommendationConfig) -> PrecipitationType {
        guard max(total, liquid + frozen) > 0 else { return .none }
        guard liquid + frozen > 0 else { return .rain }
        let snowShare = frozen / (liquid + frozen)
        if snowShare >= 1 - config.sleetMinimumShare { return .snow }
        if snowShare <= config.sleetMinimumShare { return .rain }
        return .sleet
    }
}
