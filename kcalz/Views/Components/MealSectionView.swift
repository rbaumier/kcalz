import SwiftUI

struct MealSectionView: View {
    let meal: Meal
    let onAdd: () -> Void
    let onTap: (FoodEntry) -> Void
    let onDelete: (FoodEntry) -> Void
    let isSelecting: Bool
    @Binding var selectedIds: Set<UUID>
    let onLongPress: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header — outside the card
            HStack(spacing: 12) {
                Text(meal.type.displayName)
                    .font(.kcHeadline)
                    .foregroundStyle(Color.kcEel)

                Spacer()

                if meal.totalKcal > 0 {
                    Text("\(Int(meal.totalKcal))")
                        .font(.kcNumberSmall)
                        .foregroundStyle(Color.kcFeather)
                    Text("kcal")
                        .font(.kcUnit)
                        .foregroundStyle(Color.kcWolf)
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
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife")
                        .font(.kcIcon)
                        .foregroundStyle(Color.kcHare)
                    Text("Aucun aliment")
                        .font(.kcEmptyText)
                        .foregroundStyle(Color.kcHare)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.kcSnow)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusXL, style: .continuous))
                .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)
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
                            onDelete: { onDelete(entry) },
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
                            }
                        )
                    }
                }
                .background(Color.kcSnow)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusXL, style: .continuous))
                .shadow(color: Color.kcSwan, radius: 0, x: 0, y: 4)
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Entry row (unified: normal + selection mode)

private struct EntryRow: View {
    let entry: FoodEntry
    let isSelecting: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void
    let onLongPress: () -> Void

    @State private var baseOffset: CGFloat = 0
    @State private var dragTranslation: CGFloat = 0

    private let deleteWidth: CGFloat = 72

    private var currentOffset: CGFloat {
        min(baseOffset + dragTranslation, 0)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background (only visible when swiped)
            if currentOffset < 0 {
                Color.kcCardinal
                    .overlay(alignment: .trailing) {
                        Image(systemName: "trash")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.trailing, 26)
                    }
            }

            // Entry content
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
            .offset(x: isSelecting ? 0 : currentOffset)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelecting {
                    onToggle()
                } else if baseOffset < 0 {
                    withAnimation(.easeOut(duration: 0.2)) { baseOffset = 0 }
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

            // Delete tap target
            if !isSelecting && baseOffset < 0 {
                HStack {
                    Spacer()
                    Color.clear
                        .frame(width: -baseOffset)
                        .contentShape(Rectangle())
                        .onTapGesture { onDelete() }
                }
            }
        }
        .clipped()
        .gesture(
            isSelecting ? nil :
            DragGesture(minimumDistance: 16)
                .onChanged { value in
                    dragTranslation = value.translation.width
                }
                .onEnded { value in
                    baseOffset = min(baseOffset + value.translation.width, 0)
                    dragTranslation = 0
                    if baseOffset < -deleteWidth {
                        onDelete()
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) {
                            baseOffset = baseOffset < -deleteWidth / 2 ? -deleteWidth : 0
                        }
                    }
                }
        )
        .animation(.easeOut(duration: 0.25), value: isSelecting)
        .onChange(of: isSelecting) { _, selecting in
            if selecting {
                withAnimation(.easeOut(duration: 0.2)) { baseOffset = 0; dragTranslation = 0 }
            }
        }
    }
}

