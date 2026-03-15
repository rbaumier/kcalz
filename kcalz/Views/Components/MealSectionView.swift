import SwiftUI

// MARK: - Preference key for entry row frames

/// Collects per-entry frames so drag-to-select can hit-test entries by position.
private struct EntryFrameKey: PreferenceKey {
    // nonisolated(unsafe): required for static stored property in Sendable type;
    // safe here because the default is a value-type dictionary never mutated concurrently.
    nonisolated(unsafe) static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Displays a single meal (header + entry list) with support for
/// drag-to-select, long-press copy-previous, and inline entry management.
struct MealSectionView: View {
    fileprivate static let longPressDuration = 0.3
    private static let dragThreshold: CGFloat = 10
    let meal: Meal
    let onTitleTap: () -> Void
    let onAdd: () -> Void
    let onTap: (FoodEntry) -> Void
    let isSelecting: Bool
    @Binding var selectedIds: Set<UUID>
    let onLongPress: () -> Void
    var currentDate: Date = .now
    var previousMeal: (date: Date, entries: [FoodEntry])? = nil
    var onCopyPrevious: () -> Void = {}

    @State private var entryFrames: [UUID: CGRect] = [:]
    @State private var dragSelectActive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header — outside the card
            HStack(spacing: 12) {
                Button { onTitleTap() } label: {
                    Text(meal.type.displayName)
                        .font(.kcHeadline)
                        .foregroundStyle(Color.kcEel)
                }
                .buttonStyle(.plain)

                Spacer()

                if meal.totalKcal > 0 {
                    Text("\(Int(meal.totalKcal))")
                        .font(.kcNumberSmall)
                        .foregroundStyle(Color.kcFeather)
                }

                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus")
                        .font(.kcIconMedium)
                        .foregroundStyle(Color.kcSnow)
                        .frame(width: Theme.buttonSize, height: 36)
                        .background(Color.kcFeather)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusS, style: .continuous))
                }
                .buttonStyle(Kc3DButton(shadow: .kcWing))
                .accessibilityLabel("Ajouter un aliment à \(meal.type.displayName)")
            }
            .padding(.horizontal, 4)

            // Card body — entries only
            if meal.entries.isEmpty {
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "fork.knife")
                            .font(.kcIcon)
                            .foregroundStyle(Color.kcHare)
                        Text("Aucun aliment")
                            .font(.kcEmptyText)
                            .foregroundStyle(Color.kcHare)
                    }

                    if let prev = previousMeal {
                        let daysAgo = Calendar.current.dateComponents([.day], from: prev.date, to: currentDate).day ?? 0
                        let timeLabel = daysAgo == 1 ? "hier" : "il y a \(daysAgo)j"
                        let totalKcal = Int(round(prev.entries.reduce(0.0) { $0 + $1.kcal }))
                        let name = meal.type.displayName.lowercased()

                        Text("Maintiens pour copier le \(name) d'\(timeLabel) (\(totalKcal) kcal)")
                            .font(.kcCaption)
                            .foregroundStyle(Color.kcHare)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
                .kcCard()
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: Self.longPressDuration)
                        .onEnded { _ in
                            guard previousMeal != nil else { return }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onCopyPrevious()
                        }
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(meal.entries.enumerated()), id: \.element.id) { i, entry in
                        if i > 0 {
                            Rectangle()
                                .fill(Color.kcPolar)
                                .frame(height: 2)
                                .padding(.leading, Theme.cardInnerPadding)
                        }

                        EntryRowButton(
                            entry: entry,
                            isSelecting: isSelecting,
                            isSelected: selectedIds.contains(entry.id),
                            onTap: { onTap(entry) },
                            onToggle: {
                                if selectedIds.contains(entry.id) {
                                    selectedIds.remove(entry.id)
                                } else {
                                    selectedIds.insert(entry.id)
                                }
                            },
                            onLongPress: {
                                onLongPress()
                                selectedIds.insert(entry.id)
                                dragSelectActive = true
                            }
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: EntryFrameKey.self,
                                    value: [entry.id: geo.frame(in: .named("mealEntries"))]
                                )
                            }
                        )
                    }
                }
                .coordinateSpace(name: "mealEntries")
                .onPreferenceChange(EntryFrameKey.self) { entryFrames = $0 }
                .gesture(
                    // Drag-to-select only active in selection mode, doesn't block scroll otherwise.
                    isSelecting ?
                    DragGesture(minimumDistance: Self.dragThreshold, coordinateSpace: .named("mealEntries"))
                        .onChanged { value in
                            if let id = entryId(at: value.location) {
                                selectedIds.insert(id)
                            }
                        } : nil
                )
                .kcCard()
            }
        }
        .padding(.bottom, 4)
    }

    /// Returns the entry id whose frame contains `point`, or `nil` if none match.
    private func entryId(at point: CGPoint) -> UUID? {
        for (id, frame) in entryFrames {
            if frame.contains(point) { return id }
        }
        return nil
    }
}

// MARK: - Entry row (unified: normal + selection mode)

/// A single food-entry row with tap, toggle, and long-press gestures.
private struct EntryRow: View {
    let entry: FoodEntry
    let isSelecting: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onToggle: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.kcFeather : Color.kcHare)
                    .padding(.trailing, 12)
                    .transition(.scale.combined(with: .opacity))
            }

            Text(entry.name)
                .font(.kcBody)
                .foregroundStyle(Color.kcEel)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(Int(entry.grams))g")
                .font(.kcBadge)
                .foregroundStyle(Color.kcHare)
                .padding(.trailing, 14)

            Text("\(Int(entry.kcal))")
                .font(.kcNumberSmall)
                .foregroundStyle(Color.kcFeather)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.horizontal, Theme.cardInnerPadding)
        .padding(.vertical, 14)
        .background(Color.kcSnow)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.25), value: isSelecting)
    }
}

/// Wraps EntryRow in a Button (for scroll compatibility) + long press gesture.
private struct EntryRowButton: View {
    let entry: FoodEntry
    let isSelecting: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onToggle: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Button {
            if isSelecting { onToggle() } else { onTap() }
        } label: {
            EntryRow(entry: entry, isSelecting: isSelecting, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !isSelecting {
                Button {
                    onLongPress()
                } label: {
                    Label("Sélectionner", systemImage: "checkmark.circle")
                }
            }
        }
    }
}

// Keep EntryRow as a pure display component
private extension EntryRow {
    init(entry: FoodEntry, isSelecting: Bool, isSelected: Bool) {
        self.entry = entry
        self.isSelecting = isSelecting
        self.isSelected = isSelected
        self.onTap = {}
        self.onToggle = {}
        self.onLongPress = {}
    }
}

