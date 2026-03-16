import os
import SwiftUI
import UniformTypeIdentifiers

/// Goal-editing screen for daily calorie and macronutrient targets, with database export.
struct GoalsView: View {
    /// UserDefaults key for the last export timestamp.
    private static let lastExportKey = "lastExportDate"

    /// Number of days after which the export warning turns orange.
    private static let exportWarningDays = 7

    let current: NutritionGoal
    let onSave: (NutritionGoal) -> Void
    let userStore: UserStore?

    @State private var kcalText: String
    @State private var proteinsText: String
    @State private var carbsText: String
    @State private var fatText: String
    @State private var sugarsText: String
    @State private var saltText: String
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showImportConfirm = false
    @State private var importURL: URL?

    @Environment(\.dismiss) private var dismiss

    init(current: NutritionGoal, onSave: @escaping (NutritionGoal) -> Void, userStore: UserStore? = nil) {
        self.current = current
        self.onSave = onSave
        self.userStore = userStore
        _kcalText = State(initialValue: current.kcal.map { String(Int($0)) } ?? "")
        _proteinsText = State(initialValue: current.proteins.map { String(Int($0)) } ?? "")
        _carbsText = State(initialValue: current.carbs.map { String(Int($0)) } ?? "")
        _fatText = State(initialValue: current.fat.map { String(Int($0)) } ?? "")
        _sugarsText = State(initialValue: current.sugars.map { String(Int($0)) } ?? "")
        _saltText = State(initialValue: current.salt.map { String(Int($0)) } ?? "")
    }

    /// Parses a text field into a positive `Double`, returning `nil` for empty or invalid input.
    private func parseGoal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let value = Double(trimmed), value > 0 else { return nil }
        return value
    }

    /// Builds a `NutritionGoal` from the current text field values.
    private var goal: NutritionGoal {
        NutritionGoal(
            kcal: parseGoal(kcalText),
            proteins: parseGoal(proteinsText),
            carbs: parseGoal(carbsText),
            fat: parseGoal(fatText),
            sugars: parseGoal(sugarsText),
            salt: parseGoal(saltText)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Hero kcal card
                VStack(spacing: 12) {
                    Text("CALORIES")
                        .font(.kcLabel)
                        .foregroundStyle(Color.kcWolf)
                        .kerning(Theme.labelKerning)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        KcNumericField(placeholder: "2000", text: $kcalText, font: .kcNumberLarge, color: .kcFeather, width: 110, decimals: false)

                        Text("kcal")
                            .font(.kcSecondary)
                            .foregroundStyle(Color.kcWolf)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .kcCard()

                // MARK: - Macros grid
                Text("MACRONUTRIMENTS")
                    .font(.kcLabel)
                    .foregroundStyle(Color.kcWolf)
                    .kerning(Theme.labelKerning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ], spacing: 12) {
                    MacroCard(label: "Protéines", unit: "g", text: $proteinsText, color: .kcCardinal)
                    MacroCard(label: "Glucides", unit: "g", text: $carbsText, color: .kcMacaw)
                    MacroCard(label: "Lipides", unit: "g", text: $fatText, color: .kcBee)
                    MacroCard(label: "Sucres", unit: "g", text: $sugarsText, color: .kcFox)
                    MacroCard(label: "Sel", unit: "g", text: $saltText, color: .kcHare)
                }

                // MARK: - Save
                KcPrimaryButton(label: "Enregistrer") {
                    onSave(goal)
                    dismiss()
                }
                .padding(.top, 8)

                // MARK: - Export
                if userStore != nil {
                    Button { showExporter = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.kcIconMedium)
                            Text("Exporter mes données")
                                .font(.kcBody)
                        }
                        .foregroundStyle(Color.kcWolf)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .padding(.top, 16)

                    Button { showImporter = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.kcIconMedium)
                            Text("Importer des données")
                                .font(.kcBody)
                        }
                        .foregroundStyle(Color.kcWolf)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }

                    if let lastExport = UserDefaults.standard.object(forKey: Self.lastExportKey) as? Date {
                        let days = Calendar.current.dateComponents([.day], from: lastExport, to: .now).day ?? 0
                        Text("Dernier export : il y a \(days) jour\(days > 1 ? "s" : "")")
                            .font(.kcCaption)
                            .foregroundStyle(days > Self.exportWarningDays ? Color.kcFox : Color.kcHare)
                    }
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.top, Theme.horizontalPadding)
            .padding(.bottom, 32)
        }
        .background(Color.kcPolar)
        .navigationTitle("Objectifs")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $showExporter,
            document: JsonExportDocument(userStore: userStore),
            contentType: .json,
            defaultFilename: "kcalz-\(Date.now.kcDateString).json"
        ) { result in
            if case .success = result {
                UserDefaults.standard.set(Date.now, forKey: Self.lastExportKey)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                importURL = url
                showImportConfirm = true
            }
        }
        .alert("Import réussi", isPresented: $showImportSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Vos données ont été importées.")
        }
        .alert("Erreur d'import", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK") {}
        } message: {
            Text(importError ?? "")
        }
        .alert("Remplacer les données ?", isPresented: $showImportConfirm) {
            Button("Annuler", role: .cancel) { importURL = nil }
            Button("Remplacer", role: .destructive) {
                if let url = importURL {
                    importDatabase(from: url)
                    importURL = nil
                }
            }
        } message: {
            Text("Toutes vos données actuelles seront remplacées par le fichier importé. Cette action est irréversible.")
        }
    }

    @State private var showImportSuccess = false
    @State private var importError: String?

    /// Reads JSON export and imports all data into the active database.
    private func importDatabase(from url: URL) {
        guard let userStore else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            try userStore.importJSON(from: data)
            showImportSuccess = true
        } catch {
            importError = error.localizedDescription
            Logger(subsystem: "com.kcalz", category: "Import").error("Import failed: \(error)")
        }
    }
}

// MARK: - Macro card

private struct MacroCard: View {
    let label: String
    let unit: String
    @Binding var text: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: Theme.dotSize, height: Theme.dotSize)
                Text(label)
                    .font(.kcSmallLabel)
                    .foregroundStyle(Color.kcEel)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                KcNumericField(placeholder: "—", text: $text, font: .kcNumberSmall, width: 50, decimals: false)

                Text(unit)
                    .font(.kcUnit)
                    .foregroundStyle(Color.kcWolf)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .kcCard(radius: Theme.cornerRadiusL)
    }
}

// MARK: - JSON document export

/// `FileDocument` that exports all user data as JSON for sharing/backup.
struct JsonExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    private let jsonData: Data

    init(userStore: UserStore?) {
        self.jsonData = (try? userStore?.exportJSON()) ?? Data("{}".utf8)
    }

    init(configuration: ReadConfiguration) throws {
        self.jsonData = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: jsonData)
    }
}
