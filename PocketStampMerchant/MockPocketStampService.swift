import Foundation

final class MockPocketStampService: PocketStampService {
    // These in-memory balances and event logs simulate state that will live in the backend.
    private let merchantId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let locationId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private var stampBalances: [UUID: Int] = [:]
    private var customerPasses: [String: CustomerPass] = [:]
    private var stampEvents: [StampEvent] = []
    private var redemptionEvents: [RedemptionEvent] = []

    func authenticate(email: String, password: String) async throws -> MerchantUser {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else {
            throw PocketStampError.invalidCredentials
        }

        try await Task.sleep(for: .milliseconds(350))
        return MerchantUser(
            id: UUID(),
            merchantId: merchantId,
            email: email,
            displayName: "Counter Staff"
        )
    }

    func loadMerchant(for user: MerchantUser) async throws -> Merchant {
        Merchant(
            id: merchantId,
            name: "Kitchen at the Wharf",
            contactEmail: user.email,
            loyaltyProgram: LoyaltyProgram(
                id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
                name: "Coffee Card",
                rewardName: "Free coffee",
                rewardThreshold: 10
            )
        )
    }

    func loadLocation(for merchant: Merchant) async throws -> Location {
        Location(
            id: locationId,
            merchantId: merchant.id,
            name: "Main Till",
            address: "The Wharf"
        )
    }

    func registerDevice(for merchant: Merchant, location: Location) async throws -> RegisteredDevice {
        RegisteredDevice(
            id: UUID(),
            merchantId: merchant.id,
            locationId: location.id,
            name: "Main Till iPhone",
            status: .registered,
            registeredAt: .now
        )
    }

    func addStamp(
        to customerPass: CustomerPass,
        merchant: Merchant,
        location: Location
    ) async throws -> TapResult {
        if let declineResult = validationResult(for: customerPass, action: .addStamp, merchant: merchant) {
            return declineResult
        }

        var updatedPass = passWithStoredBalance(customerPass)
        updatedPass.currentStamps += 1
        updatedPass.lastUpdated = .now
        stampBalances[updatedPass.customerId] = updatedPass.currentStamps
        customerPasses[updatedPass.passSerialNumber] = updatedPass

        let rewardAvailable = updatedPass.currentStamps >= updatedPass.rewardThreshold
        return TapResult(
            id: UUID(),
            action: .addStamp,
            state: rewardAvailable ? .rewardAvailable : .stampAdded,
            customerPass: updatedPass,
            isSuccess: true,
            message: rewardAvailable ? "Stamp added. Reward available." : "Stamp added"
        )
    }

    func redeemReward(
        for customerPass: CustomerPass,
        merchant: Merchant,
        location: Location
    ) async throws -> TapResult {
        if let declineResult = validationResult(for: customerPass, action: .redeemReward, merchant: merchant) {
            return declineResult
        }

        var updatedPass = passWithStoredBalance(customerPass)

        guard updatedPass.currentStamps >= updatedPass.rewardThreshold else {
            return TapResult(
                id: UUID(),
                action: .redeemReward,
                state: .notEnoughStamps,
                customerPass: updatedPass,
                isSuccess: false,
                message: "Not enough stamps"
            )
        }

        updatedPass.currentStamps -= updatedPass.rewardThreshold
        updatedPass.lastUpdated = .now
        stampBalances[updatedPass.customerId] = updatedPass.currentStamps
        customerPasses[updatedPass.passSerialNumber] = updatedPass
        return TapResult(
            id: UUID(),
            action: .redeemReward,
            state: .rewardRedeemed,
            customerPass: updatedPass,
            isSuccess: true,
            message: "Reward redeemed"
        )
    }

    func logActivity(
        for result: TapResult,
        merchant: Merchant,
        location: Location,
        device: RegisteredDevice
    ) async throws -> StampEvent {
        let event = StampEvent(
            id: UUID(),
            merchantId: merchant.id,
            locationId: location.id,
            customerId: result.customerPass.customerId,
            customerName: result.customerPass.customerName,
            action: result.action,
            result: result.state,
            stampBalance: result.customerPass.currentStamps,
            deviceId: device.id,
            deviceName: device.name,
            createdAt: .now
        )
        stampEvents.insert(event, at: 0)

        if result.state == .rewardRedeemed {
            redemptionEvents.insert(
                RedemptionEvent(
                    id: UUID(),
                    merchantId: merchant.id,
                    locationId: location.id,
                    customerId: result.customerPass.customerId,
                    passSerialNumber: result.customerPass.passSerialNumber,
                    deviceId: device.id,
                    stampsRedeemed: result.customerPass.rewardThreshold,
                    createdAt: event.createdAt
                ),
                at: 0
            )
        }

        return event
    }

    func loadCustomerPassDetail(passSerialNumber: String) async throws -> CustomerPassDetail {
        guard let customerPass = customerPasses[passSerialNumber] else {
            throw APIError.invalidResponse
        }
        let events = stampEvents.filter { $0.customerId == customerPass.customerId }
        return CustomerPassDetail(customerPass: customerPass, recentActivity: events)
    }

    func loadActivity(for merchant: Merchant, location: Location) async throws -> [StampEvent] {
        stampEvents
    }

    private func validationResult(
        for customerPass: CustomerPass,
        action: TapAction,
        merchant: Merchant
    ) -> TapResult? {
        if customerPass.merchantId != merchant.id {
            return declinedResult(
                state: .wrongMerchant,
                message: "This Wallet pass belongs to another cafe.",
                action: action,
                customerPass: customerPass
            )
        }

        if !customerPass.isActive {
            return declinedResult(
                state: .inactivePass,
                message: "This Wallet pass is inactive.",
                action: action,
                customerPass: customerPass
            )
        }

        return nil
    }

    private func declinedResult(
        state: TapResultState,
        message: String,
        action: TapAction,
        customerPass: CustomerPass
    ) -> TapResult {
        TapResult(
            id: UUID(),
            action: action,
            state: state,
            customerPass: passWithStoredBalance(customerPass),
            isSuccess: false,
            message: message
        )
    }

    private func passWithStoredBalance(_ customerPass: CustomerPass) -> CustomerPass {
        var updatedPass = customerPass
        updatedPass.currentStamps = stampBalances[customerPass.customerId] ?? customerPass.currentStamps
        return updatedPass
    }
}
