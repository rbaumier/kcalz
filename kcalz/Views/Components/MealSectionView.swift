import SwiftUI

// MARK: - Preference key for entry row frames

private struct EntryFrameKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct MealSectionView: View {
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
                    LongPressGesture(minimumDuration: 0.3)
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

                        EntryRow(
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
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("mealEntries"))
                        .onChanged { value in
                            // dragSelectActive: long-press just fired, drag continues without release
                            // isSelecting + moved >10pt: already in selection mode, user is dragging
                            let isDragging = dragSelectActive ||
                                (isSelecting && hypot(value.translation.width, value.translation.height) > 10)
                            guard isDragging else { return }
                            if let id = entryId(at: value.location) {
                                selectedIds.insert(id)
                            }
                        }
                        .onEnded { _ in
                            dragSelectActive = false
                        }
                )
                .kcCard()
            }
        }
        .padding(.bottom, 4)
    }

    private func entryId(at point: CGPoint) -> UUID? {
        for (id, frame) in entryFrames {
            if frame.contains(point) { return id }
        }
        return nil
    }
}

// MARK: - Entry row (unified: normal + selection mode)

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
        .onTapGesture {
            if isSelecting {
                onToggle()
            } else {
                onTap()
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.25)
                .onEnded { _ in
                    if !isSelecting {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onLongPress()
                    }
                }
        )
        .animation(.easeOut(duration: 0.25), value: isSelecting)
    }
}
