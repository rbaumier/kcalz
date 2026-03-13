import SwiftUI

struct CopySheet: View {
    @State private var selectedDate: Date
    @State private var selectedMealType: MealType = .breakfast

    let onCopy: (Date, MealType) -> Void
    @Environment(\.dismiss) private var dismiss

    private let dates: [Date]

    init(onCopy: @escaping (Date, MealType) -> Void) {
        self.onCopy = onCopy
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let generated = (-30...30).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
        self.dates = generated
        self._selectedDate = State(initialValue: today)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE d MMM"
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    Picker("Date", selection: $selectedDate) {
                        ForEach(dates, id: \.self) { date in
                            Text(Self.formatDate(date))
                                .tag(date)
                        }
                    }
                    .pickerStyle(.wheel)

                    Picker("Repas", selection: $selectedMealType) {
                        ForEach(MealType.allCases) { type in
                            Text(type.displayName)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 140)
                }
                .frame(height: 180)

                KcPrimaryButton(label: "Copier") {
                    onCopy(selectedDate, selectedMealType)
                    dismiss()
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.bottom, 32)
            .background(Color.kcPolar)
            .navigationTitle("Copier vers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Aujourd'hui" }
        if cal.isDateInYesterday(date) { return "Hier" }
        if cal.isDateInTomorrow(date) { return "Demain" }
        return dayFormatter.string(from: date).capitalized
    }
}
