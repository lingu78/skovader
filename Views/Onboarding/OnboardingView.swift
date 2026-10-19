import SwiftUI

/// Första start (flöde A): välkomst, platstillstånd eller ort, och en
/// uppmaning att lägga till första skon.
struct OnboardingView: View {
    let weather: WeatherStore
    /// Anropas när introduktionen är klar. Sant om användaren vill lägga
    /// till sin första sko direkt.
    var onFinish: (_ addShoe: Bool) -> Void

    @AppStorage(SettingsKey.useManualPlace) private var useManualPlace = false
    @AppStorage(SettingsKey.manualPlace) private var manualPlaceData = Data()

    @State private var step = Step.welcome
    @State private var showPlaceSearch = false
    @State private var locationDenied = false

    private enum Step {
        case welcome
        case location
        case firstShoe
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            switch step {
            case .welcome:
                page(
                    systemImage: "shoe.2.fill",
                    title: "Välkommen till Skoväder",
                    message: "Varje morgon föreslår Skoväder vilka av dina skor som passar dagens väder."
                )
                Spacer()
                Button {
                    step = .location
                } label: {
                    Text("Kom igång").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            case .location:
                page(
                    systemImage: "location.circle.fill",
                    title: "Var är du?",
                    message: locationDenied
                        ? "Okej! Skriv in din ort i stället, så hämtas vädret där."
                        : "Skoväder hämtar vädret där du är. Positionen avrundas till ungefär en kilometer och sparas inte."
                )
                Spacer()
                VStack(spacing: 12) {
                    Button {
                        Task { await useMyLocation() }
                    } label: {
                        Text("Använd min plats").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(locationDenied)

                    Button("Skriv in ort i stället") {
                        showPlaceSearch = true
                    }
                    .controlSize(.large)
                }

            case .firstShoe:
                page(
                    systemImage: "camera.circle.fill",
                    title: "Lägg till din första sko",
                    message: "Fotografera ett par skor och välj vilken sort det är. Det tar under en halv minut."
                )
                Spacer()
                VStack(spacing: 12) {
                    Button {
                        onFinish(true)
                    } label: {
                        Text("Lägg till sko").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Senare") { onFinish(false) }
                        .controlSize(.large)
                }
            }
        }
        .padding(32)
        .animation(.default, value: step)
        .sheet(isPresented: $showPlaceSearch) {
            PlaceSearchView { place in
                manualPlaceData = place.encoded
                useManualPlace = true
                step = .firstShoe
            }
        }
    }

    private func page(systemImage: String, title: LocalizedStringKey, message: LocalizedStringKey) -> some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(message)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private func useMyLocation() async {
        if await weather.requestLocationAuthorization() {
            useManualPlace = false
            step = .firstShoe
        } else {
            locationDenied = true
            showPlaceSearch = true
        }
    }
}
