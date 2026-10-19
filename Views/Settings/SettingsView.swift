import SwiftUI

/// Plats (min plats eller vald ort) och morgonnotis (F9, F11).
struct SettingsView: View {
    let weather: WeatherStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(SettingsKey.useManualPlace) private var useManualPlace = false
    @AppStorage(SettingsKey.manualPlace) private var manualPlaceData = Data()
    @AppStorage(SettingsKey.morningNotificationEnabled) private var notificationEnabled = false
    @AppStorage(SettingsKey.morningNotificationMinutes) private var notificationMinutes = MorningNotification.defaultMinutes

    @State private var showPlaceSearch = false
    @State private var notificationsDenied = false

    private var manualPlace: Place? { Place(data: manualPlaceData) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Använd min plats", isOn: useLocationBinding)
                    if useManualPlace, let manualPlace {
                        LabeledContent("Ort", value: manualPlace.name)
                    }
                    Button(useManualPlace ? "Byt ort" : "Välj en ort i stället") {
                        showPlaceSearch = true
                    }
                } header: {
                    Text("Plats")
                } footer: {
                    Text("Till vädertjänsten skickas bara positionen avrundad till ungefär en kilometer.")
                }

                if !useManualPlace && weather.isLocationDenied {
                    Section {
                        Text("Skoväder får inte använda din plats. Slå på det i Inställningar, eller välj en ort.")
                        Button("Öppna Inställningar", action: openSystemSettings)
                    }
                }

                Section {
                    Toggle("Morgonnotis", isOn: $notificationEnabled)
                    if notificationEnabled {
                        DatePicker("Tid", selection: notificationTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Notis")
                } footer: {
                    Text("En påminnelse varje morgon: ”Dags att välja skor – öppna Skoväder”.")
                }

                Section {
                    Link("Väderdata från Open-Meteo.com", destination: URL(string: "https://open-meteo.com/")!)
                } footer: {
                    Text("Inga konton, ingen reklam och ingen analys. Bilder och skor lämnar aldrig telefonen.")
                }
            }
            .navigationTitle("Inställningar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { dismiss() }
                }
            }
            .onChange(of: notificationEnabled) { _, isOn in
                Task { await updateNotification(enabled: isOn) }
            }
            .onChange(of: notificationMinutes) { _, _ in
                Task { await updateNotification(enabled: notificationEnabled) }
            }
            .sheet(isPresented: $showPlaceSearch) {
                PlaceSearchView { place in
                    manualPlaceData = place.encoded
                    useManualPlace = true
                }
            }
            .alert("Notiser är avstängda", isPresented: $notificationsDenied) {
                Button("Öppna Inställningar", action: openSystemSettings)
                Button("OK", role: .cancel) {}
            } message: {
                Text("Slå på notiser för Skoväder i Inställningar för att få morgonpåminnelsen.")
            }
        }
    }

    /// Av: använd vald ort (eller sök fram en). På: fråga om platstillstånd vid behov.
    private var useLocationBinding: Binding<Bool> {
        Binding {
            !useManualPlace
        } set: { useLocation in
            if useLocation {
                useManualPlace = false
                Task { _ = await weather.requestLocationAuthorization() }
            } else if manualPlace == nil {
                showPlaceSearch = true
            } else {
                useManualPlace = true
            }
        }
    }

    private var notificationTime: Binding<Date> {
        Binding {
            Calendar.current.date(
                bySettingHour: notificationMinutes / 60,
                minute: notificationMinutes % 60,
                second: 0,
                of: Date()
            ) ?? Date()
        } set: { date in
            let time = Calendar.current.dateComponents([.hour, .minute], from: date)
            notificationMinutes = (time.hour ?? 7) * 60 + (time.minute ?? 0)
        }
    }

    private func updateNotification(enabled: Bool) async {
        guard enabled else {
            MorningNotification.cancel()
            return
        }
        if await MorningNotification.requestAuthorization() {
            try? await MorningNotification.schedule(minutesAfterMidnight: notificationMinutes)
        } else {
            notificationEnabled = false
            notificationsDenied = true
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}
