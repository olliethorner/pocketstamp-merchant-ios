import Foundation
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var merchant: Merchant?
    @Published private(set) var location: Location?
    @Published private(set) var device: RegisteredDevice?
    @Published private(set) var mode: MerchantMode = .stamp
    @Published private(set) var latestResult: TapResult?
    @Published private(set) var latestCustomerPass: CustomerPass?
    @Published private(set) var latestTapResult: TapResult?
    @Published private(set) var activityLog: [StampEvent] = []
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    private let passReader: PassReader
    private let service: PocketStampService

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
            let merchant = try await service.loadMerchant(for: user)
            let location = try await service.loadLocation(for: merchant)
            let device = try await service.registerDevice(for: merchant, location: location)

            self.merchant = merchant
            self.location = location
            self.device = device
            isAuthenticated = true
            activityLog = (try? await service.loadActivity(for: merchant, location: location)) ?? []
        } catch {
            errorMessage = error.localizedDescription
        }

        isBusy = false
    }

    func logout() {
        isAuthenticated = false
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

    func handleCustomerTap() async {
        guard let merchant, let location, let device else { return }

        isBusy = true
        errorMessage = nil
        latestResult = nil

        do {
            let customerPass = try await passReader.readCustomerPass(for: merchant, location: location)
            let result: TapResult

            switch mode {
            case .stamp:
                result = try await service.addStamp(to: customerPass, merchant: merchant, location: location)
            case .redeem:
                result = try await service.redeemReward(for: customerPass, merchant: merchant, location: location)
            }

            let activity = try await service.logActivity(
                for: result,
                merchant: merchant,
                location: location,
                device: device
            )
            latestResult = result
            latestCustomerPass = result.customerPass
            latestTapResult = result
            activityLog.insert(activity, at: 0)
            if let remoteActivity = try? await service.loadActivity(for: merchant, location: location) {
                activityLog = remoteActivity
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isBusy = false
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
}
