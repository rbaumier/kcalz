import SwiftUI
import Charts

struct WeightView: View {
    let userStore: UserStore
    let currentDate: Date

    @State private var weightText = ""
    @State private var entries: [WeightEntry] = []
    @State private var selectedPeriod: Period = .month
    @State private var selectedEntry: WeightEntry?
    @State private var saved = false
    @State private var todayWeight: Double?
    @State private var checkpoints: [UserStore.WeightCheckpoint] = []
    @State private var showNewCheckpoint = false
    @State private var checkpointTitle = ""
    @FocusState private var checkpointTitleFocused: Bool
    @State private var checkpointGoal: UserStore.CheckpointGoal = .loss
    @State private var checkpointToDelete: UserStore.WeightCheckpoint?
    @FocusState private var inputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    enum Period: String, CaseIterable, Identifiable {
        case week = "7j"
        case month = "30j"
        case quarter = "90j"
        case all = "Tout"

        var id: String { rawValue }

        var days: Int? {
            switch self {
            case .week: 7
            case .month: 30
            case .quarter: 90
            case .all: nil
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                inputSection
                periodPicker
                chartSection
                checkpointSection
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.bottom, 32)
        }
        .background(Color.kcPolar)
        .navigationTitle("Poids")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            todayWeight = try? userStore.loadWeight(for: currentDate)
            if let kg = todayWeight {
                weightText = formatKg(kg)
            }
            loadEntries()
            checkpoints = userStore.loadCheckpoints()
            inputFocused = true
        }
        .sheet(isPresented: $showNewCheckpoint) {
            newCheckpointSheet
        }
        .alert("Supprimer cet objectif ?", isPresented: Binding(
            get: { checkpointToDelete != nil },
            set: { if !$0 { checkpointToDelete = nil } }
        )) {
            Button("Annuler", role: .cancel) { checkpointToDelete = nil }
            Button("Supprimer", role: .destructive) {
                if let cp = checkpointToDelete {
                    try? userStore.deleteCheckpoint(id: cp.id)
                    checkpoints = userStore.loadCheckpoints()
                    checkpointToDelete = nil
                }
            }
        } message: {
            if let cp = checkpointToDelete {
                Text(cp.title)
            }
        }
    }

    // MARK: - Input

    @ViewBuilder
    private var inputSection: some View {
        VStack(spacing: 12) {
            Text("AUJOURD'HUI")
                .font(.kcLabel)
                .foregroundStyle(Color.kcWolf)
                .kerning(Theme.labelKerning)
                .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    KcNumericField(placeholder: "0.0", text: $weightText)
                                        .focused($inputFocused)

                    Text("kg")
                        .font(.kcSecondary)
                        .foregroundStyle(Color.kcWolf)
                }
                .padding(.horizontal, Theme.cardInnerPadding)
                .padding(.vertical, 16)
                .kcCard(radius: Theme.cornerRadiusL)

                Button {
                    saveWeight()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.kcIconMedium)
                        .foregroundStyle(Color.kcSnow)
                        .frame(width: Theme.buttonSize, height: Theme.buttonSize)
                        .background(saved ? Color.kcWing : Color.kcFeather)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusS, style: .continuous))
                }
                .buttonStyle(Kc3DButton(shadow: .kcWing))
                .disabled(Double(weightText.replacingOccurrences(of: ",", with: ".")) == nil)
                .opacity(Double(weightText.replacingOccurrences(of: ",", with: ".")) == nil ? 0.5 : 1)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Period picker

    @ViewBuilder
    private var periodPicker: some View {
        HStack(spacing: 8) {
            ForEach(Period.allCases) { period in
                Button {
                    selectedPeriod = period
                    loadEntries()
                } label: {
                    Text(period.rawValue)
                        .font(.kcSmallLabel)
                        .foregroundStyle(selectedPeriod == period ? Color.kcSnow : Color.kcEel)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedPeriod == period ? Color.kcFeather : Color.kcSnow)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartSection: some View {
        if entries.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "scalemass")
                    .font(.kcIcon)
                    .foregroundStyle(Color.kcHare)
                Text("Aucune donnée")
                    .font(.kcEmptyText)
                    .foregroundStyle(Color.kcHare)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .kcCard()
        } else {
            let minKg = (entries.map(\.kg).min() ?? 0) - 1
            let maxKg = (entries.map(\.kg).max() ?? 0) + 1

            VStack(alignment: .leading, spacing: 12) {
                if let selected = selectedEntry {
                    HStack(spacing: 8) {
                        Text(formatDateLabel(selected.date))
                            .font(.kcSmallLabel)
                            .foregroundStyle(Color.kcWolf)
                        Text("\(formatKg(selected.kg)) kg")
                            .font(.kcNumberSmall)
                            .foregroundStyle(Color.kcFeather)
                    }
                    .padding(.horizontal, 4)
                }

                Chart(entries) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Poids", entry.kg)
                    )
                    .foregroundStyle(Color.kcFeather)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(entries.count > 14 ? .catmullRom : .linear)

                    if entries.count <= 31 {
                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Poids", entry.kg)
                        )
                        .foregroundStyle(selectedEntry?.id == entry.id ? Color.kcWing : Color.kcFeather)
                        .symbolSize(selectedEntry?.id == entry.id ? 80 : 40)
                    }
                }
                .chartYScale(domain: minKg...maxKg)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let kg = value.as(Double.self) {
                                Text("\(Int(kg))")
                                    .font(.kcUnit)
                                    .foregroundStyle(Color.kcWolf)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                            .foregroundStyle(Color.kcSwan)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(formatAxisDate(date))
                                    .font(.kcUnit)
                                    .foregroundStyle(Color.kcWolf)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                guard let date: Date = proxy.value(atX: location.x) else { return }
                                if let closest = entries.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                    selectedEntry = selectedEntry?.id == closest.id ? nil : closest
                                }
                            }
                    }
                }
                .frame(height: 220)
            }
            .padding(Theme.cardInnerPadding)
            .kcCard()
        }
    }

    // MARK: - Objectifs

    @ViewBuilder
    private var checkpointSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Objectifs")
                    .font(.kcHeadline)
                    .foregroundStyle(Color.kcEel)
                Spacer()
                Button { showNewCheckpoint = true } label: {
                    Image(systemName: "plus")
                        .font(.kcIconMedium)
                        .foregroundStyle(Color.kcSnow)
                        .frame(width: Theme.buttonSize, height: 36)
                        .background(Color.kcFeather)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusS, style: .continuous))
                }
                .buttonStyle(Kc3DButton(shadow: .kcWing))
            }

            if checkpoints.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "flag")
                        .font(.kcIcon)
                        .foregroundStyle(Color.kcHare)
                    Text("Aucun objectif")
                        .font(.kcEmptyText)
                        .foregroundStyle(Color.kcHare)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .kcCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(checkpoints.enumerated()), id: \.element.id) { i, cp in
                        if i > 0 {
                            Rectangle()
                                .fill(Color.kcPolar)
                                .frame(height: 2)
                                .padding(.leading, Theme.cardInnerPadding)
                        }
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cp.title)
                                    .font(.kcBody)
                                    .foregroundStyle(Color.kcEel)
                                HStack(spacing: 6) {
                                    Text(formatDateLabel(cp.date))
                                        .font(.kcCaption)
                                        .foregroundStyle(Color.kcWolf)
                                    Text(cp.goal.label)
                                        .font(.kcCaption)
                                        .foregroundStyle(Color.kcHare)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(formatKg(cp.weightKg)) kg")
                                    .font(.kcNumberSmall)
                                    .foregroundStyle(Color.kcEel)

                                // Diff: vs next checkpoint (i-1) or vs current weight for latest
                                let refKg: Double? = i == 0 ? todayWeight : checkpoints[i - 1].weightKg
                                if let ref = refKg {
                                    let diff = ref - cp.weightKg
                                    let sign = diff >= 0 ? "+" : ""
                                    let color: Color = switch cp.goal {
                                    case .loss: diff <= 0 ? .kcFeather : .kcCardinal
                                    case .gain: diff >= 0 ? .kcFeather : .kcCardinal
                                    case .maintain: .kcHare
                                    }
                                    Text("\(sign)\(formatKg(diff)) kg")
                                        .font(.kcBadge)
                                        .foregroundStyle(color)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.cardInnerPadding)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        .onTapGesture { checkpointToDelete = cp }
                    }
                }
                .kcCard()
            }
        }
    }

    @ViewBuilder
    private var newCheckpointSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TextField("Ex : Sèche hiver", text: $checkpointTitle)
                    .font(.kcBody)
                    .focused($checkpointTitleFocused)
                    .padding(.horizontal, Theme.cardInnerPadding)
                    .padding(.vertical, 14)
                    .kcCard(radius: Theme.cornerRadiusM)

                Picker("Type", selection: $checkpointGoal) {
                    ForEach(UserStore.CheckpointGoal.allCases) { goal in
                        Text(goal.label).tag(goal)
                    }
                }
                .pickerStyle(.segmented)

                KcPrimaryButton(label: "Créer", icon: "flag", enabled: !checkpointTitle.trimmingCharacters(in: .whitespaces).isEmpty && todayWeight != nil) {
                    if let kg = todayWeight {
                        try? userStore.saveCheckpoint(title: checkpointTitle.trimmingCharacters(in: .whitespaces), weightKg: kg, date: currentDate, goal: checkpointGoal)
                        checkpoints = userStore.loadCheckpoints()
                        checkpointTitle = ""
                        showNewCheckpoint = false
                    }
                }

                Spacer()
            }
            .padding(Theme.horizontalPadding)
            .navigationTitle("Nouvel objectif")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showNewCheckpoint = false }
                }
            }
            .onAppear { checkpointTitleFocused = true }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func saveWeight() {
        guard let kg = Double(weightText.replacingOccurrences(of: ",", with: ".")) else { return }
        try? userStore.saveWeight(kg: kg, date: currentDate)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    private func loadEntries() {
        let cal = Calendar.current
        let end = cal.startOfDay(for: .now.addingTimeInterval(86400))
        if let days = selectedPeriod.days {
            let start = cal.date(byAdding: .day, value: -days, to: end) ?? end
            entries = (try? userStore.loadWeights(from: start, to: end)) ?? []
        } else {
            entries = (try? userStore.latestWeights(limit: 365)) ?? []
        }
    }

    private func formatKg(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(kg))" : String(format: "%.1f", kg)
    }

    private func formatDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Aujourd'hui" }
        if cal.isDateInYesterday(date) { return "Hier" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    private func formatAxisDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = selectedPeriod == .week ? "EEE" : "d/M"
        return f.string(from: date)
    }
}
