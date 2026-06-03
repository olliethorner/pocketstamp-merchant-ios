import SwiftUI

struct MerchantHomeView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isShowingSettings = false
    @State private var detailResult: TapResult?

    var body: some View {
        NavigationStack {
            ZStack {
                PocketStampTheme.cream
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        merchantSummary
                        ModeStatusCard(mode: viewModel.mode, tapStatusText: viewModel.tapStatusText)
                        simulateTapButton
                        switchModeButton

                        if let latestResult = viewModel.latestResult {
                            CustomerResultCard(result: latestResult) {
                                Task {
                                    detailResult = await viewModel.refreshedResultForDetail(latestResult)
                                }
                            }
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ActivityLogView(events: viewModel.activityLog)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("PocketStamp")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(PocketStampTheme.brown)
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(viewModel: viewModel)
            }
            .sheet(item: $detailResult) { result in
                CustomerPassDetailView(
                    result: result,
                    currentMerchantId: viewModel.merchant?.id ?? result.customerPass.merchantId,
                    recentActivity: viewModel.activityLog
                )
            }
        }
    }

    private var merchantSummary: some View {
        HStack(spacing: 14) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.title2)
                .foregroundStyle(PocketStampTheme.brown)
                .frame(width: 48, height: 48)
                .background(PocketStampTheme.caramel.opacity(0.35))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.merchant?.name ?? "Merchant")
                    .font(.headline)
                    .foregroundStyle(PocketStampTheme.espresso)
                Text(viewModel.location?.name ?? "Location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(deviceStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("READY")
                .font(.caption.weight(.bold))
                .foregroundStyle(.green)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.green.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(16)
        .pocketStampCard()
    }

    private var simulateTapButton: some View {
        Button {
            Task { await viewModel.handleCustomerTap() }
        } label: {
            VStack(spacing: 8) {
                if viewModel.isBusy {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 32))
                }

                Text(viewModel.tapStatusText ?? "Simulate Customer Tap")
                    .font(.headline)

                Text("Mock Wallet tap - future NFC reader plugs in here.")
                    .font(.caption)
                    .opacity(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(viewModel.mode == .stamp ? PocketStampTheme.brown : PocketStampTheme.redeem)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 7)
        }
        .disabled(viewModel.isProcessingTap)
    }

    private var deviceStatusText: String {
        guard let device = viewModel.device else {
            return "Registering device..."
        }

        return "\(device.name) - \(device.status.displayName)"
    }

    private var switchModeButton: some View {
        Button {
            withAnimation {
                viewModel.switchMode()
            }
        } label: {
            Text(viewModel.mode == .stamp ? "Switch to Redeem Mode" : "Switch to Stamp Mode")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(PocketStampTheme.espresso)
                .background(.white.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(viewModel.isBusy)
    }
}
