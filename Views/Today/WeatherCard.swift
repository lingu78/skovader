import SwiftUI
import SkovaderEngine

/// Dagens väder för 07–18: ikon, känd temperatur, nederbörd och vind.
struct WeatherCard: View {
    let day: DayWeather
    let condition: WeatherCondition
    let placeName: String
    let updatedAt: Date

    private let config = RecommendationConfig.standard

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(placeName, systemImage: "location.fill")
                    .lineLimit(1)
                Spacer()
                Text("Uppdaterad kl. \(updatedAt.formatted(date: .omitted, time: .shortened))")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Image(systemName: condition.systemImage)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 56))
                    .accessibilityLabel(condition.label)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: temperatureText)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Känns som, kl. \(hour(config.weatherWindowStartHour))–\(hour(config.weatherWindowEndHour))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 20) {
                Label(precipitationText, systemImage: "drop.fill")
                Label("\(Int(day.maxWindSpeed.rounded())) m/s", systemImage: "wind")
            }
            .font(.subheadline)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("CardBackground"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var temperatureText: String {
        let low = Int(day.feelsLikeMin.rounded())
        let high = Int(day.feelsLikeMax.rounded())
        return low == high ? "\(low)°" : "\(low)° – \(high)°"
    }

    private var precipitationText: String {
        guard day.precipitationMM >= config.rainThresholdMM else {
            return String(localized: "Uppehåll")
        }
        let amount = day.precipitationMM.formatted(.number.precision(.fractionLength(0...1)))
        switch day.precipitationType {
        case .snow: return String(localized: "\(amount) mm snö")
        case .sleet: return String(localized: "\(amount) mm snöblandat regn")
        case .rain, .none: return String(localized: "\(amount) mm regn")
        }
    }

    private func hour(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}

extension WeatherCondition {
    var label: LocalizedStringKey {
        switch self {
        case .clear: "Sol"
        case .partlyCloudy: "Halvklart"
        case .cloudy: "Mulet"
        case .fog: "Dimma"
        case .rain: "Regn"
        case .heavyRain: "Mycket regn"
        case .snow: "Snö"
        case .sleet: "Snöblandat regn"
        case .thunder: "Åska"
        case .windy: "Blåsigt"
        }
    }
}
