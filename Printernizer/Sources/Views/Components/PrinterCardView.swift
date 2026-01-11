import SwiftUI

struct PrinterCardView: View {
    let printer: Printer

    var body: some View {
        HStack(spacing: 16) {
            printerIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(printer.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Circle()
                        .fill(printer.statusColor)
                        .frame(width: 8, height: 8)
                    Text(printer.status.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if printer.status == .printing, let progress = printer.currentJobProgress {
                    ProgressView(value: progress)
                        .tint(.accentColor)
                        .padding(.top, 4)
                }
            }

            Spacer()

            if printer.status == .printing, let progress = printer.currentJobProgress {
                Text("\(Int(progress * 100))%")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.accentColor)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var printerIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(printer.statusColor.opacity(0.15))
                .frame(width: 48, height: 48)

            Image(systemName: "printer.fill")
                .font(.title2)
                .foregroundStyle(printer.statusColor)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PrinterCardView(printer: .preview)
        PrinterCardView(printer: Printer(
            id: "2",
            name: "Prusa MK4",
            status: .idle,
            model: "Prusa MK4",
            currentJobProgress: nil
        ))
    }
    .padding()
}
