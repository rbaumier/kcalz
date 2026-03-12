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
            Circle()
                .stroke(Color.kcSwan, lineWidth: 14)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    Color.kcFeather,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(remaining)")
                    .font(.kcNumber)
                    .foregroundStyle(Color.kcEel)
                    .contentTransition(.numericText())

                Text("RESTANTES")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.kcWolf)
                    .kerning(0.6)
            }
        }
        .frame(width: 156, height: 156)
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
