import SwiftUI

struct CustomerPassDetailView: View {
    let result: TapResult
    let currentMerchantId: UUID
    let recentActivity: [StampEvent]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Latest tap") {
                    Label(result.state.title, systemImage: result.isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(result.isSuccess ? .green : .orange)

                    Text(result.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Customer pass") {
                    detailRow("Customer", value: pass.customerName)
                    detailRow("Pass serial", value: shortenedSerialNumber)
                    detailRow("Merchant ID", value: shortenedMerchantId)
                    detailRow("Cafe match", value: isMatchingMerchant ? "Correct cafe" : "Wrong cafe")
                    detailRow("Pass status", value: pass.isActive ? "Active" : "Inactive")
                    detailRow("Last updated", value: pass.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                }

                Section("Loyalty balance") {
                    detailRow("Current stamps", value: "\(pass.currentStamps)")
                    detailRow("Reward threshold", value: "\(pass.rewardThreshold)")
                    detailRow("Reward available", value: rewardAvailable ? "Yes" : "No")
                }

                Section("Recent customer activity") {
                    if customerActivity.isEmpty {
                        Text("No previous activity in this app session.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(customerActivity.prefix(5)) { event in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.result.activityDescription)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(event.createdAt.formatted(date: .omitted, time: .shortened)) - \(event.deviceName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pass details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var pass: CustomerPass {
        result.customerPass
    }

    private var isMatchingMerchant: Bool {
        pass.merchantId == currentMerchantId
    }

    private var rewardAvailable: Bool {
        pass.currentStamps >= pass.rewardThreshold
    }

    private var customerActivity: [StampEvent] {
        recentActivity.filter { $0.customerId == pass.customerId }
    }

    private var shortenedSerialNumber: String {
        guard pass.passSerialNumber.count > 16 else {
            return pass.passSerialNumber
        }

        return "\(pass.passSerialNumber.prefix(8))...\(pass.passSerialNumber.suffix(4))"
    }

    private var shortenedMerchantId: String {
        let merchantId = pass.merchantId.uuidString
        return "\(merchantId.prefix(8))...\(merchantId.suffix(4))"
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
