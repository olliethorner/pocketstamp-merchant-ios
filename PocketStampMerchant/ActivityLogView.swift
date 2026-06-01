import SwiftUI

struct ActivityLogView: View {
    let events: [StampEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent activity")
                .font(.headline)
                .foregroundStyle(PocketStampTheme.espresso)

            if events.isEmpty {
                Text("Customer tap activity will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(events.prefix(6).enumerated()), id: \.element.id) { index, event in
                    if index > 0 {
                        Divider()
                    }

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: icon(for: event.result))
                            .foregroundStyle(color(for: event.result))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.result.activityDescription)
                                .font(.subheadline.weight(.semibold))
                            Text("\(event.customerName) - \(event.deviceName) - \(event.stampBalance) stamps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(event.createdAt, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .pocketStampCard()
    }

    private func icon(for result: TapResultState) -> String {
        switch result {
        case .stampAdded, .rewardAvailable: "plus.circle.fill"
        case .rewardRedeemed: "checkmark.seal.fill"
        case .notEnoughStamps, .wrongMerchant, .inactivePass, .error: "exclamationmark.circle.fill"
        }
    }

    private func color(for result: TapResultState) -> Color {
        switch result {
        case .stampAdded, .rewardAvailable: PocketStampTheme.brown
        case .rewardRedeemed: .green
        case .notEnoughStamps, .wrongMerchant, .inactivePass, .error: .orange
        }
    }
}
