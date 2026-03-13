import SwiftUI
import Charts
import Combine

struct WeightView: View {
    let userStore: UserStore
    let currentDate: Date

    @State private var weightText = ""
    @State private var entries: [WeightEntry] = []
    @State private var selectedPeriod: Period = .month
    @State private var selectedEntry: WeightEntry?
    @State private var saved = false
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
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.bottom, 32)
        }
        .background(Color.kcPolar)
        .navigationTitle("Poids")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let kg = try? userStore.loadWeight(for: currentDate) {
                weightText = formatKg(kg)
            }
            loadEntries()
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
                HStack(spacing: 4) {
                    TextField("0.0", text: $weightText)
                        .font(.kcNumberMedium)
                        .foregroundStyle(Color.kcEel)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 100)
                        .onReceive(Just(weightText)) { new in
                            let filtered = new.filter { "0123456789.,".contains($0) }
                                .replacingOccurrences(of: ",", with: ".")
                            if filtered != new { weightText = filtered }
                        }

                    Text("kg")
                        .font(.kcSecondary)
                        .foregroundStyle(Color.kcWolf)
                }
                .padding(.horizontal, Theme.cardInnerPadding)
                .padding(.vertical, 16)
                .background(Color.kcSnow)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusL, style: .continuous))
                .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)

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
            .background(Color.kcSnow)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusXL, style: .continuous))
            .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)
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

                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("Poids", entry.kg)
                    )
                    .foregroundStyle(selectedEntry?.id == entry.id ? Color.kcWing : Color.kcFeather)
                    .symbolSize(selectedEntry?.id == entry.id ? 80 : 40)
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
            .background(Color.kcSnow)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusXL, style: .continuous))
            .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)
        }
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
