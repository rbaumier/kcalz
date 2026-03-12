import SwiftUI

struct NutrientBarView: View {
    let label: String
    let current: Double
    let goal: Double
    let color: Color
    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.kcCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(current))/\(Int(goal))g")
                    .font(.kcNumberSmall)
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.15))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geo.size.width * animatedProgress)
                }
            }
            .frame(height: 10)
        }
        .onAppear {
            withAnimation(.kcBounce.delay(0.3)) {
                animatedProgress = progress
            }
        }
    }
}
