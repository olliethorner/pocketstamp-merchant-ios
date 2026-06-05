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
    @Published private(set) var accessMode: MerchantAccessMode = AppEnvironment.isDemoModeEnabled ? .demo : .authenticated
    @Published var authEmail = ""
    @Published var authPassword = ""
    @Published private(set) var authSession: AuthSession?
    @Published private(set) var authenticatedMerchantContext: MerchantContext?
    @Published private(set) var authErrorMessage: String?
    @Published private(set) var isAuthenticating = false
    @Published private(set) var isRestoringSession = true
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

    var isDemoModeEnabled: Bool {
        AppEnvironment.isDemoModeEnabled
    }

    var availableAccessModes: [MerchantAccessMode] {
        isDemoModeEnabled ? MerchantAccessMode.allCases : [.authenticated]
    }

    init(
        passReader: PassReader? = nil,
        service: PocketStampService? = nil
    ) {
        // Swap MockPassReader for an NFCPassReader here after entitlement approval.
        self.passReader = passReader ?? AppEnvironment.makePassReader()
        self.service = service ?? AppEnvironment.makePocketStampService()

        Task {
            await restoreSavedSession()
        }
    }

    func login(email: String, password: String) async {
        guard isDemoModeEnabled else {
            setAccessModeSafely(.authenticated)
            return
        }

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
        setAccessModeSafely(.authenticated)
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
            authSession = response.session
            authenticatedMerchantContext = response.merchantContext
            setAccessModeSafely(.authenticated)
            isAuthenticated = true
            saveAuthSession(response.session)
            try await activateAuthenticatedMerchant(response.merchantContext)
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    func setAccessMode(_ mode: MerchantAccessMode) {
        setAccessModeSafely(mode)
        authErrorMessage = nil
        errorMessage = nil
    }

    func logout() {
        isAuthenticated = false
        setAccessModeSafely(preferredUnauthenticatedAccessMode)
        clearAuthSession()
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
        guard isDemoModeEnabled, accessMode == .demo else { return }
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
                result = try await service.addStamp(
                    to: customerPass,
                    merchant: merchant,
                    location: location,
                    accessToken: accessTokenForMerchantAPIs
                )
            case .redeem:
                result = try await service.redeemReward(
                    for: customerPass,
                    merchant: merchant,
                    location: location,
                    accessToken: accessTokenForMerchantAPIs
                )
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
            handleMerchantAPIError(error)
        }
    }

    func refreshedResultForDetail(_ result: TapResult) async -> TapResult {
        do {
            let detail = try await service.loadCustomerPassDetail(
                passSerialNumber: result.customerPass.passSerialNumber,
                accessToken: accessTokenForMerchantAPIs
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
            handleMerchantAPIError(error)
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

    private func restoreSavedSession() async {
        defer { isRestoringSession = false }

        guard let accessToken = KeychainStore.readString(for: AuthKey.accessToken.rawValue),
              !accessToken.isEmpty else {
            return
        }

        do {
            let context = try await service.me(accessToken: accessToken)
            let session = restoredAuthSession(accessToken: accessToken)
            authSession = session
            authenticatedMerchantContext = context
            authEmail = context.email
            setAccessModeSafely(.authenticated)
            isAuthenticated = true
            try await activateAuthenticatedMerchant(context)
        } catch {
            KeychainStore.clearPocketStampAuthItems()
            authSession = nil
            authenticatedMerchantContext = nil
            setAccessModeSafely(preferredUnauthenticatedAccessMode)
            authErrorMessage = "Your session has expired. Please sign in again."
        }
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
        await refreshRemoteActivity(merchant: merchant, location: location)
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

        // TODO: Send auth token to device registration if/when backend supports authenticated device APIs.
        let device = try await service.registerDevice(for: merchant, location: location)

        self.merchant = merchant
        self.location = location
        self.device = device
        await refreshRemoteActivity(merchant: merchant, location: location)
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
            await refreshRemoteActivity(merchant: merchant, location: location)
        } catch {
            handleMerchantAPIError(error)
        }
    }

    private var accessTokenForMerchantAPIs: String? {
        // TODO: Send auth token to all production merchant APIs as backend auth hardening expands.
        // TODO: Eventually require auth on backend and disable unauthenticated demo endpoints in production.
        accessMode == .authenticated ? authSession?.accessToken : nil
    }

    private func refreshRemoteActivity(merchant: Merchant, location: Location) async {
        do {
            activityLog = try await service.loadActivity(
                for: merchant,
                location: location,
                accessToken: accessTokenForMerchantAPIs
            )
        } catch {
            handleMerchantAPIError(error)
        }
    }

    private func handleMerchantAPIError(_ error: Error) {
        errorMessage = error.localizedDescription

        if accessMode == .authenticated,
           case PocketStampError.merchantSessionExpired = error {
            clearAuthSession()
            isAuthenticated = false
            setAccessModeSafely(preferredUnauthenticatedAccessMode)
            authErrorMessage = error.localizedDescription
        }
    }

    private var preferredUnauthenticatedAccessMode: MerchantAccessMode {
        isDemoModeEnabled ? .demo : .authenticated
    }

    private func setAccessModeSafely(_ mode: MerchantAccessMode) {
        if !isDemoModeEnabled, mode == .demo {
            accessMode = .authenticated
        } else {
            accessMode = mode
        }
    }

    private func saveAuthSession(_ session: AuthSession) {
        KeychainStore.saveString(session.accessToken, for: AuthKey.accessToken.rawValue)
        KeychainStore.saveString(session.refreshToken, for: AuthKey.refreshToken.rawValue)
        KeychainStore.saveString(session.tokenType, for: AuthKey.tokenType.rawValue)

        let expiresAt = Date().addingTimeInterval(TimeInterval(session.expiresIn)).timeIntervalSince1970
        KeychainStore.saveString(String(expiresAt), for: AuthKey.expiresAt.rawValue)

        // TODO: Refresh token handling is basic for now; implement refresh before access token expiry.
        // TODO: Add biometric unlock if desired.
        // TODO: Wire demo/prod behavior to build configurations before release.
    }

    private func restoredAuthSession(accessToken: String) -> AuthSession {
        let refreshToken = KeychainStore.readString(for: AuthKey.refreshToken.rawValue) ?? ""
        let tokenType = KeychainStore.readString(for: AuthKey.tokenType.rawValue) ?? "bearer"
        let expiresAtValue = KeychainStore.readString(for: AuthKey.expiresAt.rawValue)
        let expiresAt = expiresAtValue.flatMap(TimeInterval.init) ?? Date().timeIntervalSince1970
        let expiresIn = max(0, Int(expiresAt - Date().timeIntervalSince1970))

        return AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            tokenType: tokenType
        )
    }

    private func clearAuthSession() {
        authSession = nil
        authenticatedMerchantContext = nil
        KeychainStore.clearPocketStampAuthItems()
    }
}
