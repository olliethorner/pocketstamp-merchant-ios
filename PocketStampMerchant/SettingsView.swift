import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Merchant") {
                    settingsRow("Cafe", value: viewModel.merchant?.name ?? "Not loaded")
                    settingsRow("Location", value: viewModel.location?.name ?? "Not loaded")
                    settingsRow("Device", value: viewModel.device?.name ?? "Not registered")
                    settingsRow("Device Status", value: viewModel.device?.status.displayName ?? "Not registered")
                    settingsRow("Mode", value: viewModel.mode.title)
                }

                Section("Reader") {
                    Label("Mock NFC reader active", systemImage: "iphone.radiowaves.left.and.right")
                    Text("Real Wallet NFC reading will plug into PassReader after entitlement approval.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Log Out", role: .destructive) {
                        dismiss()
                        viewModel.logout()
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func settingsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
