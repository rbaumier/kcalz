import SwiftUI

struct KcalRingView: View {
    let consumed: Double
    let goal: Int

    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(consumed / Double(goal), 1.0)
    }

    private var remaining: Int {
        max(goal - Int(consumed), 0)
    }

    private var percentage: Int {
        Int(progress * 100)
    }

    var body: some View {
        ZStack {
            // Background track — warm tint, not gray
            Circle()
                .stroke(Color.kcKcal.opacity(0.1), lineWidth: 14)

            // Progress arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    Color.kcKcal,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: 2) {
                Text("\(remaining)")
                    .font(.kcNumber)
                    .foregroundStyle(Color.kcTextPrimary)
                    .contentTransition(.numericText())

                Text("kcal restantes")
                    .font(.kcCaption)
                    .foregroundStyle(Color.kcTextSecondary)
            }
        }
        .frame(width: 150, height: 150)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(percentage) pour cent de l'objectif atteint, \(remaining) kilocalories restantes")
        .onAppear {
            if reduceMotion {
                animatedProgress = progress
            } else {
                withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                    animatedProgress = progress
                }
            }
        }
    }
}
