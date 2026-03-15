import SwiftUI

/// Circular progress ring showing remaining kilocalories for the day.
struct KcalRingView: View {
    let consumed: Double
    let goal: Double

    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(consumed / goal, 1.0)
    }

    private var remaining: Int {
        Int(goal) - Int(consumed)
    }

    private var percentage: Int {
        Int(progress * 100)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.kcSwan, lineWidth: Theme.ringStroke)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    Color.kcFeather,
                    style: StrokeStyle(lineWidth: Theme.ringStroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(remaining)")
                    .font(.kcNumberLarge)
                    .foregroundStyle(remaining < 0 ? Color.kcCardinal : Color.kcEel)
                    .contentTransition(.numericText())

                Text("RESTANTES")
                    .font(.kcLabel)
                    .foregroundStyle(Color.kcWolf)
                    .kerning(Theme.ringLabelKerning)
            }
        }
        .frame(width: Theme.ringSize, height: Theme.ringSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(percentage) pour cent de l'objectif atteint, \(remaining) kilocalories restantes")
        .task {
            if reduceMotion {
                animatedProgress = progress
            } else {
                withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                    animatedProgress = progress
                }
            }
        }
        .onChange(of: consumed) {
            withAnimation(.easeOut(duration: 0.3)) {
                animatedProgress = progress
            }
        }
    }
}
