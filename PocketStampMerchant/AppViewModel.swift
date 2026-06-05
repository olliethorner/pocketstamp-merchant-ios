import Foundation
import Combine

enum TapProcessingStage {
    case readingPass
    case updatingBalance

    var statusText: String {
        switch self {
        case .readingPass: "Reading Wallet pass…"
        case .updatingBalance: "Updating loyalty balance…"
        }
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published var accessMode: MerchantAccessMode = .demo
    @Published var authEmail = ""
    @Published var authPassword = ""
    @Published private(set) var authSession: AuthSession?
    @Published private(set) var authenticatedMerchantContext: MerchantContext?
    @Published private(set) var authErrorMessage: String?
    @Published private(set) var isAuthenticating = false
    @Published private(set) var merchant: Merchant?
    @Published private(set) var location: Location?
    @Published private(set) var device: RegisteredDevice?
    @Published private(set) var mode: MerchantMode = .stamp
    @Published private(set) var latestResult: TapResult?
    @Published private(set) var latestCustomerPass: CustomerPass?
    @Published private(set) var latestTapResult: TapResult?
    @Published private(set) var activityLog: [StampEvent] = []
    @Published private(set) var isBusy = false
    @Published private(set) var tapProcessingStage: TapProcessingStage?
    @Published private(set) var availableDemoMerchants = DemoMerchant.all
    @Published private(set) var selectedDemoMerchant = DemoMerchant.kitchenAtTheWharf
    @Published private(set) var availableDemoCustomers = DemoMerchant.kitchenAtTheWharf.demoCustomers
    @Published private(set) var selectedDemoCustomer: DemoCustomer? = DemoMerchant.kitchenAtTheWharf.demoCustomers[0]
    @Published var errorMessage: String?

    private let passReader: PassReader
    private let service: PocketStampService

    var isProcessingTap: Bool {
        tapProcessingStage != nil
    }

    var tapStatusText: String? {
        tapProcessingStage?.statusText
    }

    init(
        passReader: PassReader? = nil,
        service: PocketStampService? = nil
    ) {
        // Swap MockPassReader for an NFCPassReader here after entitlement approval.
        self.passReader = passReader ?? AppEnvironment.makePassReader()
        self.service = service ?? AppEnvironment.makePocketStampService()
    }

    func login(email: String, password: String) async {
        isBusy = true
        errorMessage = nil

        do {
            let user = try await service.authenticate(email: email, password: password)
            isAuthenticated = true
            try await activateSelectedDemoMerchant(contactEmail: user.email)
        } catch {
            errorMessage = error.localizedDescription
        }

        isBusy = false
    }

    func authenticateMerchant() async {
        isAuthenticating = true
        isBusy = true
        authErrorMessage = nil
        errorMessage = nil

        defer {
            authPassword = ""
            isAuthenticating = false
            isBusy = false
        }

        do {
            let response = try await service.login(email: authEmail, password: authPassword)
            // TODO: Persist and refresh merchant sessions with Keychain storage.
            authSession = response.session
            authenticatedMerchantContext = response.merchantContext
            accessMode = .authenticated
            isAuthenticated = true
            try await activateAuthenticatedMerchant(response.merchantContext)
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    func setAccessMode(_ mode: MerchantAccessMode) {
        accessMode = mode
        authErrorMessage = nil
        errorMessage = nil
    }

    func logout() {
        isAuthenticated = false
        accessMode = .demo
        authSession = nil
        authenticatedMerchantContext = nil
        authPassword = ""
        authErrorMessage = nil
        merchant = nil
        location = nil
        device = nil
        mode = .stamp
        latestResult = nil
        latestCustomerPass = nil
        latestTapResult = nil
        activityLog = []
        errorMessage = nil
    }

    func switchMode() {
        mode = mode == .stamp ? .redeem : .stamp
        resetLatestResult()
    }

    func selectDemoCustomer(_ demoCustomer: DemoCustomer) {
        selectedDemoCustomer = demoCustomer
        resetLatestResult()
    }

    func selectDemoMerchant(_ demoMerchant: DemoMerchant) {
        guard accessMode == .demo else { return }
        guard selectedDemoMerchant != demoMerchant else { return }

        let contactEmail = merchant?.contactEmail ?? "counter@pocketstamp.demo"
        selectedDemoMerchant = demoMerchant
        setDemoCustomers(demoMerchant.demoCustomers)
        resetLatestResult()
        activityLog = []

        guard isAuthenticated else { return }

        Task {
            do {
                try await activateSelectedDemoMerchant(contactEmail: contactEmail)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func handleCustomerTap() async {
        guard !isProcessingTap,
              let merchant,
              let location,
              let device,
              let selectedDemoCustomer else { return }

        print("TAP_UI_STARTED")
        isBusy = true
        tapProcessingStage = .readingPass
        errorMessage = nil
        latestResult = nil

        defer {
            tapProcessingStage = nil
            isBusy = false
            print("TAP_UI_FINISHED")
        }

        do {
            let customerPass = try await passReader.readCustomerPass(
                for: merchant,
                location: location,
                demoCustomer: selectedDemoCustomer
            )
            print("PASS_READER_COMPLETED")
            tapProcessingStage = .updatingBalance
            print("SERVICE_TAP_STARTED")
            let result: TapResult

            switch mode {
            case .stamp:
                result = try await service.addStamp(to: customerPass, merchant: merchant, location: location)
            case .redeem:
                result = try await service.redeemReward(for: customerPass, merchant: merchant, location: location)
            }

            print("SERVICE_TAP_COMPLETED")
            latestResult = result
            latestCustomerPass = result.customerPass
            latestTapResult = result
            print("UI_RESULT_UPDATED")

            Task { [weak self] in
                await self?.refreshActivity(
                    for: result,
                    merchant: merchant,
                    location: location,
                    device: device
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshedResultForDetail(_ result: TapResult) async -> TapResult {
        do {
            let detail = try await service.loadCustomerPassDetail(
                passSerialNumber: result.customerPass.passSerialNumber
            )
            activityLog = mergedActivity(detail.recentActivity, with: activityLog)
            return TapResult(
                id: result.id,
                action: result.action,
                state: result.state,
                customerPass: detail.customerPass,
                isSuccess: result.isSuccess,
                message: result.message
            )
        } catch {
            errorMessage = error.localizedDescription
            return result
        }
    }

    func resetLatestResult() {
        latestResult = nil
        latestCustomerPass = nil
        latestTapResult = nil
        errorMessage = nil
    }

    private func mergedActivity(_ first: [StampEvent], with second: [StampEvent]) -> [StampEvent] {
        var seen = Set<UUID>()
        return (first + second).filter { seen.insert($0.id).inserted }
    }

    private func activateSelectedDemoMerchant(contactEmail: String) async throws {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        let merchant = selectedDemoMerchant.makeMerchant(contactEmail: contactEmail)
        let location = selectedDemoMerchant.makeLocation(for: merchant)
        let device = try await service.registerDevice(for: merchant, location: location)

        self.merchant = merchant
        self.location = location
        self.device = device
        activityLog = (try? await service.loadActivity(for: merchant, location: location)) ?? []
    }

    private func activateAuthenticatedMerchant(_ context: MerchantContext) async throws {
        let matchingDemoMerchant = availableDemoMerchants.first { $0.id == context.merchantId }
        if let matchingDemoMerchant {
            selectedDemoMerchant = matchingDemoMerchant
            setDemoCustomers(matchingDemoMerchant.demoCustomers)
        } else {
            setDemoCustomers([])
        }

        let backendDeviceToken = matchingDemoMerchant?.backendDeviceToken
        let merchant = Merchant(
            id: stableUUID(from: context.merchantId),
            name: context.merchantName,
            contactEmail: context.email,
            loyaltyProgram: LoyaltyProgram(
                id: stableUUID(from: matchingDemoMerchant?.loyaltyProgramId ?? "\(context.merchantId)-loyalty"),
                name: "Coffee Card",
                rewardName: "Free coffee",
                rewardThreshold: 10,
                backendId: matchingDemoMerchant?.loyaltyProgramId
            ),
            backendId: context.merchantId,
            backendDeviceToken: backendDeviceToken
        )
        let location = Location(
            id: stableUUID(from: context.locationId),
            merchantId: merchant.id,
            name: context.locationName,
            address: context.locationName,
            backendId: context.locationId,
            backendDeviceToken: backendDeviceToken
        )

        // TODO: Future backend hardening should send the bearer token and derive merchant context server-side.
        let device = try await service.registerDevice(for: merchant, location: location)

        self.merchant = merchant
        self.location = location
        self.device = device
        activityLog = (try? await service.loadActivity(for: merchant, location: location)) ?? []
    }

    private func setDemoCustomers(_ demoCustomers: [DemoCustomer]) {
        availableDemoCustomers = demoCustomers
        selectedDemoCustomer = demoCustomers.first
    }

    private func stableUUID(from value: String) -> UUID {
        var first: UInt64 = 14_695_981_039_346_656_037
        var second: UInt64 = 10_995_116_282_111

        for byte in value.utf8 {
            first = (first ^ UInt64(byte)) &* 1_099_511_628_211
            second = (second &* 1_099_511_628_211) ^ UInt64(byte)
        }

        let bytes = withUnsafeBytes(of: (first.bigEndian, second.bigEndian)) { Array($0) }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private func refreshActivity(
        for result: TapResult,
        merchant: Merchant,
        location: Location,
        device: RegisteredDevice
    ) async {
        print("ACTIVITY_REFRESH_STARTED")
        defer { print("ACTIVITY_REFRESH_COMPLETED") }

        do {
            let activity = try await service.logActivity(
                for: result,
                merchant: merchant,
                location: location,
                device: device
            )
            activityLog.insert(activity, at: 0)
            if let remoteActivity = try? await service.loadActivity(for: merchant, location: location) {
                activityLog = remoteActivity
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
