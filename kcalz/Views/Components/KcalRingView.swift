import SwiftUI

struct KcalRingView: View {
    let consumed: Double
    let goal: Int
    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(consumed / Double(goal), 1.0)
    }

    private var remaining: Int {
        max(goal - Int(consumed), 0)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.kcKcal.opacity(0.15), lineWidth: 20)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(Color.kcKcal, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text("\(remaining)")
                    .font(.kcNumber)
                    .foregroundStyle(Color.kcKcal)
                Text("restantes")
                    .font(.kcCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 160, height: 160)
        .onAppear {
            withAnimation(.kcBounce.delay(0.2)) {
                animatedProgress = progress
            }
        }
    }
}
