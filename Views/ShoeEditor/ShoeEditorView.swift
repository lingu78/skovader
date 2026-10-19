import PhotosUI
import SwiftData
import SwiftUI
import SkovaderEngine

/// Lägga till eller redigera en sko (flöde B, F1–F5).
struct ShoeEditorView: View {
    /// Nil betyder ny sko.
    let shoe: Shoe?
    /// Anropas när användaren bekräftat borttagning. Själva borttagningen
    /// görs av listan efter att arket stängts.
    var onDelete: (Shoe) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.autoCutout) private var autoCutout = true

    @State private var draft: ShoeProfile
    @State private var photo = EditablePhoto()
    @State private var storedImage: UIImage?
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var confirmDelete = false
    @State private var saveFailed = false

    init(shoe: Shoe?, onDelete: @escaping (Shoe) -> Void = { _ in }) {
        self.shoe = shoe
        self.onDelete = onDelete
        _draft = State(initialValue: shoe?.profile ?? ShoeProfile(name: "", type: .sneakers))
    }

    private var isNew: Bool { shoe == nil }

    private var displayedImage: UIImage? {
        photo.image(useCutout: autoCutout) ?? storedImage
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection

                Section {
                    TextField("Namn, t.ex. Rosa Converse", text: $draft.name)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    Picker("Typ", selection: $draft.type) {
                        ForEach(ShoeType.allCases) { type in
                            Text(type.localizedName).tag(type)
                        }
                    }
                } footer: {
                    Text("Typen fyller i förslag nedan. Du kan ändra allt.")
                }

                Section("Egenskaper") {
                    Toggle("Vattentät", isOn: $draft.isWaterproof)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Värme")
                        Picker("Värme", selection: $draft.warmth) {
                            ForEach(WarmthLevel.allCases) { level in
                                Text(level.localizedName).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }

                Section {
                    Stepper("Lägsta \(draft.minTemperature) °C", value: $draft.minTemperature, in: -40...40)
                    Stepper("Högsta \(draft.maxTemperature) °C", value: $draft.maxTemperature, in: -40...45)
                } header: {
                    Text("Temperatur")
                } footer: {
                    Text("Skon föreslås när den kända temperaturen ligger inom intervallet.")
                }

                Section {
                    Toggle("Aktiv", isOn: $draft.isActive)
                } footer: {
                    Text("Inaktiva skor föreslås inte, t.ex. om de har blivit för små.")
                }

                if !isNew {
                    Section {
                        Button("Ta bort sko", role: .destructive) {
                            confirmDelete = true
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Ny sko" : "Redigera sko")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara", action: save)
                        .disabled(photo.isProcessing)
                }
            }
            .onChange(of: draft.type) { _, newType in
                draft.applyDefaults(for: newType)
            }
            .onChange(of: draft.minTemperature) { _, value in
                if value > draft.maxTemperature { draft.maxTemperature = value }
            }
            .onChange(of: draft.maxTemperature) { _, value in
                if value < draft.minTemperature { draft.minTemperature = value }
            }
            .onChange(of: autoCutout) { _, isOn in
                if isOn { Task { await photo.makeCutoutIfNeeded() } }
            }
            .onChange(of: libraryItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await photo.load(image, cutOut: autoCutout)
                    }
                    libraryItem = nil
                }
            }
            .task {
                if let fileName = shoe?.imageFileName {
                    storedImage = await ImageStore.shared.loadImage(named: fileName)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    Task { await photo.load(image, cutOut: autoCutout) }
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showLibrary, selection: $libraryItem, matching: .images)
            .confirmationDialog("Ta bort skon?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Ta bort", role: .destructive) {
                    if let shoe { onDelete(shoe) }
                    dismiss()
                }
                Button("Avbryt", role: .cancel) {}
            } message: {
                Text("Bilden och historiken för skon tas också bort.")
            }
            .alert("Skon kunde inte sparas", isPresented: $saveFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Försök igen.")
            }
        }
    }

    // MARK: - Bild

    @ViewBuilder
    private var photoSection: some View {
        Section {
            if let image = displayedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .overlay {
                        if photo.isProcessing { ProgressView() }
                    }
                    .accessibilityLabel("Bild på skon")
                if photo.hasImage {
                    Toggle("Klipp ut skon automatiskt", isOn: $autoCutout)
                }
                Menu {
                    photoSourceButtons
                } label: {
                    Label("Byt bild", systemImage: "photo")
                }
            } else if photo.isProcessing {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                photoSourceButtons
            }
        } footer: {
            if displayedImage == nil && !photo.isProcessing {
                Text("Fotografera skon mot en lugn bakgrund, så klipps den ut automatiskt.")
            }
        }
    }

    @ViewBuilder
    private var photoSourceButtons: some View {
        if CameraPicker.isAvailable {
            Button {
                showCamera = true
            } label: {
                Label("Ta foto", systemImage: "camera")
            }
        }
        Button {
            showLibrary = true
        } label: {
            Label("Välj från bildbiblioteket", systemImage: "photo.on.rectangle")
        }
    }

    // MARK: - Spara

    private func save() {
        var newImage: (data: Data, fileExtension: String)?
        if let image = photo.image(useCutout: autoCutout) {
            newImage = ImageProcessor.encode(image, isCutout: photo.isCutout(useCutout: autoCutout))
        }
        do {
            try ShoeLibrary.save(draft, image: newImage, existing: shoe, in: modelContext)
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}

#Preview("Ny sko") {
    ShoeEditorView(shoe: nil)
        .modelContainer(for: [Shoe.self, WearLog.self], inMemory: true)
}
