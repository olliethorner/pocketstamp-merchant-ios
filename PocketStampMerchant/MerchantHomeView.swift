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
                        merchantDashboard
                        ModeStatusCard(mode: viewModel.mode, tapStatusText: viewModel.tapStatusText)
                        demoCustomerSelector
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

    private var merchantDashboard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title3)
                    .foregroundStyle(PocketStampTheme.brown)
                    .frame(width: 42, height: 42)
                    .background(PocketStampTheme.caramel.opacity(0.35))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Kitchen at the Wharf")
                        .font(.headline)
                        .foregroundStyle(PocketStampTheme.espresso)
                    Text("Merchant dashboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(deviceBadgeText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(viewModel.device == nil ? .orange : .green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background((viewModel.device == nil ? Color.orange : Color.green).opacity(0.12))
                    .clipShape(Capsule())
            }

            LazyVGrid(columns: dashboardColumns, alignment: .leading, spacing: 10) {
                dashboardItem(title: "Merchant", value: viewModel.merchant?.name ?? "Kitchen at the Wharf")
                dashboardItem(title: "Location", value: viewModel.location?.name ?? "Main Till")
                dashboardItem(title: "Backend", value: AppEnvironment.backendMode.displayName)
                dashboardItem(title: "Device", value: deviceBadgeText)
                dashboardItem(title: "Current mode", value: viewModel.mode == .stamp ? "Stamp" : "Redeem")
            }
        }
        .padding(16)
        .pocketStampCard()
    }

    private var demoCustomerSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.title3)
                    .foregroundStyle(PocketStampTheme.brown)
                    .frame(width: 38, height: 38)
                    .background(PocketStampTheme.caramel.opacity(0.26))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Demo tap customer: \(viewModel.selectedDemoCustomer.displayName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PocketStampTheme.espresso)
                    Text(viewModel.selectedDemoCustomer.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Menu {
                    ForEach(viewModel.availableDemoCustomers) { customer in
                        Button {
                            viewModel.selectDemoCustomer(customer)
                        } label: {
                            Text(customer.displayName)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PocketStampTheme.espresso)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.86))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(viewModel.availableDemoCustomers.count <= 1 || viewModel.isBusy)
            }
        }
        .padding(14)
        .background(PocketStampTheme.caramel.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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

                Text(viewModel.selectedDemoCustomer.displayName)
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

    private var deviceBadgeText: String {
        viewModel.device == nil ? "Not registered" : "Registered"
    }

    private var dashboardColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 138), spacing: 10)
        ]
    }

    private func dashboardItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PocketStampTheme.espresso)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(PocketStampTheme.cream.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
