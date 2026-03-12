import SwiftUI

struct NutrientBarView: View {
    let label: String
    let current: Double
    let goal: Double
    let color: Color
    let index: Int

    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.0)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Colored dot
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            // Label
            Text(label)
                .font(.kcSubheadline)
                .foregroundStyle(Color.kcTextPrimary)

            Spacer()

            // Values
            Text("\(Int(current))")
                .font(.kcNumberSmall)
                .foregroundStyle(color)
            Text("/ \(Int(goal))g")
                .font(.kcCaption)
                .foregroundStyle(Color.kcTextSecondary)
        }

        // Bar
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.12))

                Capsule()
                    .fill(color)
                    .frame(width: max(geo.size.width * animatedProgress, animatedProgress > 0 ? 8 : 0))
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(Int(current)) sur \(Int(goal)) grammes")
        .onAppear {
            if reduceMotion {
                animatedProgress = progress
            } else {
                withAnimation(.kcStagger(index)) {
                    animatedProgress = progress
                }
            }
        }
    }
}
