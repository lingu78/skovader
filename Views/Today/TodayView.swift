import SwiftData
import SwiftUI
import SkovaderEngine

/// Idag (flöde C): dagens väder 07–18, rekommenderade skor med motivering,
/// upp till två alternativ och "Jag tar dessa".
struct TodayView: View {
    let weather: WeatherStore
    var onAddShoe: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Shoe.createdAt) private var shoes: [Shoe]
    @Query private var wearLogs: [WearLog]
    @AppStorage(SettingsKey.useManualPlace) private var useManualPlace = false
    @AppStorage(SettingsKey.manualPlace) private var manualPlaceData = Data()

    @State private var showSettings = false
    @State private var showPlaceSearch = false

    private let engine = RecommendationEngine()

    private var preference: LocationPreference {
        LocationPreference(useManualPlace: useManualPlace, placeData: manualPlaceData)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    weatherSection
                    if let problem = weather.problem {
                        problemCard(problem)
                    }
                    shoeSection
                    Link("Väderdata från Open-Meteo.com", destination: URL(string: "https://open-meteo.com/")!)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .refreshable {
                await weather.refresh(preference: preference, force: true)
            }
            .navigationTitle("Idag")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Inställningar", systemImage: "gearshape") {
                        showSettings = true
                    }
                }
            }
            .task {
                await weather.refresh(preference: preference)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await weather.refresh(preference: preference) }
                }
            }
            .onChange(of: preference) { _, newPreference in
                Task { await weather.refresh(preference: newPreference) }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(weather: weather)
            }
            .sheet(isPresented: $showPlaceSearch) {
                PlaceSearchView { place in
                    manualPlaceData = place.encoded
                    useManualPlace = true
                }
            }
        }
    }

    // MARK: - Väder

    @ViewBuilder
    private var weatherSection: some View {
        if let forecast = weather.forecast, let day = weather.dayWeather(), let condition = weather.condition() {
            WeatherCard(day: day, condition: condition, placeName: placeName, updatedAt: forecast.fetchedAt)
        } else if weather.isLoading {
            ProgressView("Hämtar vädret …")
                .frame(maxWidth: .infinity, minHeight: 160)
        }
    }

    private var placeName: String {
        if case .manual(let place?) = preference {
            return place.name
        }
        return String(localized: "Din plats")
    }

    @ViewBuilder
    private func problemCard(_ problem: WeatherStore.Problem) -> some View {
        switch problem {
        case .needsLocationPermission:
            MessageCard(
                systemImage: "location.fill",
                title: "Var är du?",
                message: "Tillåt plats så hämtas vädret där du är, eller välj en ort."
            ) {
                Button("Använd min plats") {
                    Task {
                        if await weather.requestLocationAuthorization() {
                            await weather.refresh(preference: preference)
                        } else {
                            showPlaceSearch = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                Button("Välj ort") { showPlaceSearch = true }
            }
        case .needsPlace:
            MessageCard(
                systemImage: "mappin.and.ellipse",
                title: "Välj en ort",
                message: weather.isLocationDenied
                    ? "Skoväder får inte använda din plats. Välj en ort så hämtas vädret där."
                    : "Välj en ort så hämtas vädret där."
            ) {
                Button("Välj ort") { showPlaceSearch = true }
                    .buttonStyle(.borderedProminent)
            }
        case .locationUnavailable:
            MessageCard(
                systemImage: "location.slash.fill",
                title: "Hittade inte din plats",
                message: "Försök igen om en stund, eller välj en ort."
            ) {
                Button("Försök igen") {
                    Task { await weather.refresh(preference: preference, force: true) }
                }
                .buttonStyle(.borderedProminent)
                Button("Välj ort") { showPlaceSearch = true }
            }
        case .offline:
            Label("Kunde inte uppdatera vädret. Visar senaste prognosen.", systemImage: "wifi.slash")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .noForecast:
            MessageCard(
                systemImage: "wifi.slash",
                title: "Kunde inte hämta vädret",
                message: "Kontrollera att telefonen är ansluten till internet."
            ) {
                Button("Försök igen") {
                    Task { await weather.refresh(preference: preference, force: true) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Skor

    @ViewBuilder
    private var shoeSection: some View {
        if shoes.isEmpty {
            // F10: inga skor – uppmaning i stället för rekommendation.
            MessageCard(
                systemImage: "shoe.2.fill",
                title: "Lägg till dina skor",
                message: "Fotografera dina skor, så föreslår Skoväder varje morgon vilka som passar vädret."
            ) {
                Button("Lägg till sko", action: onAddShoe)
                    .buttonStyle(.borderedProminent)
            }
        } else if let day = weather.dayWeather() {
            recommendation(for: day)
        }
    }

    @ViewBuilder
    private func recommendation(for day: DayWeather) -> some View {
        let today = Date()
        let history = WearHistory(entries: wearLogs.compactMap(\.entry), today: today)
        let chosenID = WearLibrary.chosenShoeID(on: today, among: wearLogs)

        switch engine.recommend(shoes: shoes.map(\.profile), weather: day, history: history) {
        case .noShoes:
            EmptyView()
        case .noActiveShoes:
            MessageCard(
                systemImage: "shoe.2.fill",
                title: "Alla skor är inaktiva",
                message: "Markera några skor som aktiva under Mina skor, så kan Skoväder föreslå dem."
            ) {
                EmptyView()
            }
        case .suggestion(let suggestion):
            SuggestionView(suggestion: suggestion, shoes: shoes, chosenID: chosenID) { shoe in
                try? WearLibrary.choose(shoe, in: modelContext)
            }
        }
    }
}

#Preview {
    TodayView(weather: .live())
        .modelContainer(for: [Shoe.self, WearLog.self], inMemory: true)
}
