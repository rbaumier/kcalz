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
        HStack(spacing: 10) {
            Text(label)
                .font(.kcSmallLabel)
                .foregroundStyle(Color.kcEel)
                .frame(width: 72, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.kcSwan)

                    Capsule()
                        .fill(color)
                        .frame(width: max(geo.size.width * animatedProgress, animatedProgress > 0 ? Theme.minBarWidth : 0))
                }
            }
            .frame(height: Theme.barHeight)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(current))")
                    .font(.kcSmallNumber)
                    .foregroundStyle(Color.kcEel)
                Text("/ \(Int(goal))g")
                    .font(.kcUnit)
                    .foregroundStyle(Color.kcWolf)
            }
            .frame(minWidth: 56, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(Int(current)) sur \(Int(goal)) grammes")
        .task {
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
