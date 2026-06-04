import SwiftUI

struct CustomerResultCard: View {
    let result: TapResult
    let onViewDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: resultIcon)
                    .font(.title2)
                    .foregroundStyle(resultColor)

                Text(result.state.activityDescription)
                    .font(.headline)
                    .foregroundStyle(PocketStampTheme.espresso)

                Spacer()
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.customerPass.customerName)
                        .font(.title3.weight(.semibold))
                    Text(secondaryText)
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
            .tint(resultColor)

            Button("View pass details") {
                onViewDetails()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PocketStampTheme.brown)
        }
        .padding(18)
        .pocketStampCard()
    }

    private var resultIcon: String {
        switch result.state {
        case .stampAdded, .rewardAvailable: "checkmark.circle.fill"
        case .rewardRedeemed: "checkmark.seal.fill"
        case .notEnoughStamps, .wrongMerchant, .inactivePass, .error: "exclamationmark.circle.fill"
        }
    }

    private var resultColor: Color {
        switch result.state {
        case .stampAdded, .rewardAvailable: PocketStampTheme.brown
        case .rewardRedeemed: .green
        case .notEnoughStamps, .wrongMerchant, .inactivePass, .error: .orange
        }
    }

    private var secondaryText: String {
        switch result.state {
        case .stampAdded: "1 stamp added to this pass."
        case .rewardAvailable: "Reward is now available."
        case .rewardRedeemed: "Reward redeemed successfully."
        case .notEnoughStamps: "Customer needs more stamps."
        case .wrongMerchant: "This pass is for another merchant."
        case .inactivePass: "This pass is inactive."
        case .error: result.message
        }
    }
}
