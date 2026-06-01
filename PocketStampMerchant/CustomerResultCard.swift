import SwiftUI

struct CustomerResultCard: View {
    let result: TapResult
    let onViewDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(result.isSuccess ? .green : .orange)

                Text(result.message)
                    .font(.headline)
                    .foregroundStyle(PocketStampTheme.espresso)

                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.customerPass.customerName)
                        .font(.title3.weight(.semibold))
                    Text("Wallet loyalty pass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(result.customerPass.currentStamps) / \(result.customerPass.rewardThreshold)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PocketStampTheme.brown)
            }

            ProgressView(
                value: Double(min(result.customerPass.currentStamps, result.customerPass.rewardThreshold)),
                total: Double(result.customerPass.rewardThreshold)
            )
            .tint(PocketStampTheme.brown)

            Button("View pass details") {
                onViewDetails()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PocketStampTheme.brown)
        }
        .padding(18)
        .pocketStampCard()
    }
}
