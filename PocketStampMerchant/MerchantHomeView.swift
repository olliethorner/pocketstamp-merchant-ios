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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title3)
                    .foregroundStyle(PocketStampTheme.brown)
                    .frame(width: 42, height: 42)
                    .background(PocketStampTheme.caramel.opacity(0.35))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.merchant?.name ?? "Kitchen at the Wharf")
                        .font(.headline)
                        .foregroundStyle(PocketStampTheme.espresso)
                    Text("\(viewModel.location?.name ?? viewModel.selectedDemoMerchant.locationName) · \(AppEnvironment.backendMode.displayName) · \(deviceBadgeText)")
                        .font(.subheadline)
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

            if viewModel.accessMode == .demo {
                demoMerchantSelector
            }

            VStack(spacing: 10) {
                statusRow(
                    icon: "server.rack",
                    title: "Backend",
                    value: AppEnvironment.backendMode.displayName
                )
                if let authenticatedMerchantContext = viewModel.authenticatedMerchantContext {
                    statusRow(
                        icon: "person.badge.key.fill",
                        title: "Signed in",
                        value: "\(authenticatedMerchantContext.role.capitalized) · \(authenticatedMerchantContext.email)"
                    )
                }
                statusRow(
                    icon: "iphone.radiowaves.left.and.right",
                    title: "Reader",
                    value: "Mock NFC / Wallet tap simulation"
                )
                statusRow(
                    icon: viewModel.mode == .stamp ? "sensor.tag.radiowaves.forward.fill" : "giftcard.fill",
                    title: "Current mode",
                    value: viewModel.mode == .stamp ? "Stamp" : "Redeem"
                )
            }
        }
        .padding(16)
        .pocketStampCard()
    }

    private var demoMerchantSelector: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "storefront.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PocketStampTheme.brown)
                .frame(width: 32, height: 32)
                .background(PocketStampTheme.cream.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("Demo merchant")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.selectedDemoMerchant.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PocketStampTheme.espresso)
            }

            Spacer(minLength: 8)

            Menu {
                ForEach(viewModel.availableDemoMerchants) { merchant in
                    Button {
                        viewModel.selectDemoMerchant(merchant)
                    } label: {
                        Text(merchant.displayName)
                    }
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PocketStampTheme.espresso)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(viewModel.availableDemoMerchants.count <= 1 || viewModel.isBusy)
        }
        .padding(12)
        .background(PocketStampTheme.caramel.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var demoCustomerSelector: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "person.crop.rectangle.stack.fill")
                .font(.title3)
                .foregroundStyle(PocketStampTheme.brown)
                .frame(width: 40, height: 40)
                .background(PocketStampTheme.caramel.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text("Demo customer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(viewModel.selectedDemoCustomer?.displayName ?? "No demo customer configured")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PocketStampTheme.espresso)
                Text(viewModel.selectedDemoCustomer?.subtitle ?? "Add a matching demo pass for this merchant.")
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
                    .background(.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(viewModel.availableDemoCustomers.count <= 1 || viewModel.isBusy)
        }
        .padding(14)
        .background(.white.opacity(0.68))
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

                Text(viewModel.tapStatusText ?? "Simulate Wallet Tap")
                    .font(.headline)

                Text(viewModel.selectedDemoCustomer?.displayName ?? "No demo customer configured")
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
        .disabled(viewModel.isProcessingTap || viewModel.selectedDemoCustomer == nil)
    }

    private var deviceBadgeText: String {
        viewModel.device == nil ? "Not registered" : "Registered"
    }

    private func statusRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PocketStampTheme.brown)
                .frame(width: 26, height: 26)
                .background(PocketStampTheme.cream.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PocketStampTheme.espresso)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(PocketStampTheme.cream.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
