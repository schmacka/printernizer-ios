import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    var lineWidth: CGFloat = 12
    var backgroundColor: Color = .secondary.opacity(0.2)
    var foregroundColor: Color = .accentColor

    var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    foregroundColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)

            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        ProgressRingView(progress: 0.75)
            .frame(width: 120, height: 120)

        ProgressRingView(progress: 0.33)
            .frame(width: 80, height: 80)
    }
    .padding()
}
