import Foundation

final class RemotePocketStampService: PocketStampService {
    private enum LocalBackend {
        static let merchantSlug = "kitchen-at-the-wharf"
        static let locationSlug = "kitchen-at-the-wharf-main"
        static let deviceName = "Main Till iPhone"
        static let deviceToken = "demo-main-till-iphone"

        static let merchantId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        static let locationId = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        static let loyaltyProgramId = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    }

    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func authenticate(email: String, password: String) async throws -> MerchantUser {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else {
            throw PocketStampError.invalidCredentials
        }

        // The local backend currently exposes device and tap endpoints, not merchant auth.
        return MerchantUser(
            id: UUID(),
            merchantId: LocalBackend.merchantId,
            email: email,
            displayName: "Counter Staff"
        )
    }

    func loadMerchant(for user: MerchantUser) async throws -> Merchant {
        Merchant(
            id: LocalBackend.merchantId,
            name: "Kitchen at the Wharf",
            contactEmail: user.email,
            loyaltyProgram: LoyaltyProgram(
                id: LocalBackend.loyaltyProgramId,
                name: "Coffee Card",
                rewardName: "Free coffee",
                rewardThreshold: 10
            )
        )
    }

    func loadLocation(for merchant: Merchant) async throws -> Location {
        Location(
            id: LocalBackend.locationId,
            merchantId: merchant.id,
            name: "Main Till",
            address: "The Wharf"
        )
    }

    func registerDevice(for merchant: Merchant, location: Location) async throws -> RegisteredDevice {
        let request = DeviceRegistrationRequest(
            merchantId: LocalBackend.merchantSlug,
            locationId: LocalBackend.locationSlug,
            deviceName: LocalBackend.deviceName,
            deviceToken: LocalBackend.deviceToken
        )
        let response: DeviceRegistrationResponse = try await apiClient.send(
            "/api/devices/register",
            method: .post,
            body: request
        )
        let dto = response.device ?? RegisteredDeviceDTO(
            id: response.id,
            merchantId: response.merchantId,
            locationId: response.locationId,
            deviceName: response.deviceName,
            displayName: response.displayName,
            status: response.status,
            registeredAt: response.registeredAt
        )

        return RegisteredDevice(
            id: uuid(from: dto.id, fallback: UUID()),
            merchantId: merchant.id,
            locationId: location.id,
            name: dto.displayName ?? dto.deviceName ?? LocalBackend.deviceName,
            status: .registered,
            registeredAt: dto.registeredAt ?? .now
        )
    }

    func addStamp(
        to customerPass: CustomerPass,
        merchant: Merchant,
        location: Location
    ) async throws -> TapResult {
        try await mutatePass(path: "/api/taps/stamp", customerPass: customerPass, fallbackAction: .addStamp)
    }

    func redeemReward(
        for customerPass: CustomerPass,
        merchant: Merchant,
        location: Location
    ) async throws -> TapResult {
        try await mutatePass(path: "/api/taps/redeem", customerPass: customerPass, fallbackAction: .redeemReward)
    }

    func logActivity(
        for result: TapResult,
        merchant: Merchant,
        location: Location,
        device: RegisteredDevice
    ) async throws -> StampEvent {
        return StampEvent(
            id: result.id,
            merchantId: merchant.id,
            locationId: location.id,
            customerId: result.customerPass.customerId,
            customerName: result.customerPass.customerName,
            action: result.action,
            result: result.state,
            stampBalance: result.customerPass.currentStamps,
            deviceId: device.id,
            deviceName: device.name,
            createdAt: result.customerPass.lastUpdated
        )
    }

    func loadCustomerPassDetail(passSerialNumber: String) async throws -> CustomerPassDetail {
        let serial = passSerialNumber.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? passSerialNumber
        let response: CustomerPassDetailResponse = try await apiClient.send("/api/customer-pass/\(serial)")
        return CustomerPassDetail(
            customerPass: mapCustomerPass(response.customerPass),
            recentActivity: (response.recentActivity ?? []).map(mapEvent)
        )
    }

    func loadActivity(for merchant: Merchant, location: Location) async throws -> [StampEvent] {
        var components = URLComponents()
        components.path = "/api/merchant/activity"
        components.queryItems = [
            URLQueryItem(name: "merchantId", value: LocalBackend.merchantSlug),
            URLQueryItem(name: "locationId", value: LocalBackend.locationSlug),
            URLQueryItem(name: "limit", value: "50")
        ]
        let response: ActivityLogResponse = try await apiClient.send(components.string ?? "/api/merchant/activity")
        return (response.events ?? response.activity ?? []).map(mapEvent)
    }

    private func mutatePass(
        path: String,
        customerPass: CustomerPass,
        fallbackAction: TapAction
    ) async throws -> TapResult {
        let request = TapMutationRequest(
            deviceToken: LocalBackend.deviceToken,
            passSerialNumber: customerPass.passSerialNumber,
            idempotencyKey: UUID().uuidString
        )
        let response: TapMutationResponse = try await apiClient.send(path, method: .post, body: request)
        guard let pass = response.customerPass else {
            throw APIError.invalidResponse
        }

        let isSuccess = response.ok ?? false
        let state = tapState(from: response.result) ?? fallbackState(for: fallbackAction, isSuccess: isSuccess)
        return TapResult(
            id: UUID(),
            action: fallbackAction,
            state: state,
            customerPass: mapCustomerPass(pass),
            isSuccess: isSuccess,
            message: response.message ?? state.title
        )
    }

    private func mapCustomerPass(_ dto: CustomerPassDTO) -> CustomerPass {
        CustomerPass(
            customerId: uuid(from: dto.customerId, fallback: UUID()),
            customerName: dto.customerName ?? "Kitchen test customer",
            passSerialNumber: dto.passSerialNumber,
            merchantId: uuid(from: dto.merchantId, fallback: LocalBackend.merchantId),
            locationId: dto.locationId.map { uuid(from: $0, fallback: LocalBackend.locationId) },
            currentStamps: dto.currentStamps,
            rewardThreshold: dto.rewardThreshold,
            isActive: dto.isActive,
            lastUpdated: dto.lastUpdated ?? .now
        )
    }

    private func mapEvent(_ dto: StampEventDTO) -> StampEvent {
        let state = tapState(from: dto.result ?? dto.state) ?? .error
        return StampEvent(
            id: uuid(from: dto.id, fallback: UUID()),
            merchantId: uuid(from: dto.merchantId, fallback: LocalBackend.merchantId),
            locationId: uuid(from: dto.locationId, fallback: LocalBackend.locationId),
            customerId: uuid(from: dto.customerId, fallback: UUID()),
            customerName: dto.customerName ?? "Kitchen test customer",
            action: tapAction(from: dto.action) ?? (state == .rewardRedeemed ? .redeemReward : .addStamp),
            result: state,
            stampBalance: dto.stampBalance ?? dto.currentStamps ?? dto.balanceAfter ?? 0,
            deviceId: uuid(from: dto.deviceId ?? dto.merchantDeviceId, fallback: UUID()),
            deviceName: dto.deviceName ?? LocalBackend.deviceName,
            createdAt: dto.createdAt ?? .now
        )
    }

    private func tapAction(from value: String?) -> TapAction? {
        switch value {
        case TapAction.addStamp.rawValue, "stamp": .addStamp
        case TapAction.redeemReward.rawValue, "redeem": .redeemReward
        default: nil
        }
    }

    private func tapState(from value: String?) -> TapResultState? {
        guard let value else { return nil }
        return TapResultState(rawValue: value)
    }

    private func fallbackState(for action: TapAction, isSuccess: Bool) -> TapResultState {
        guard isSuccess else { return .error }
        return action == .addStamp ? .stampAdded : .rewardRedeemed
    }

    private func uuid(from value: String?, fallback: UUID) -> UUID {
        guard let value else { return fallback }
        switch value {
        case LocalBackend.merchantSlug:
            return LocalBackend.merchantId
        case LocalBackend.locationSlug:
            return LocalBackend.locationId
        default:
            return UUID(uuidString: value) ?? stableUUID(from: value)
        }
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
}
