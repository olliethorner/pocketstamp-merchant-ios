protocol PocketStampService {
    func login(email: String, password: String) async throws -> AuthLoginResponse
    func me(accessToken: String) async throws -> MerchantContext
    func authenticate(email: String, password: String) async throws -> MerchantUser
    func loadMerchant(for user: MerchantUser) async throws -> Merchant
    func loadLocation(for merchant: Merchant) async throws -> Location
    func registerDevice(for merchant: Merchant, location: Location) async throws -> RegisteredDevice
    func addStamp(to customerPass: CustomerPass, merchant: Merchant, location: Location, accessToken: String?) async throws -> TapResult
    func redeemReward(for customerPass: CustomerPass, merchant: Merchant, location: Location, accessToken: String?) async throws -> TapResult
    func logActivity(for result: TapResult, merchant: Merchant, location: Location, device: RegisteredDevice) async throws -> StampEvent
    func loadCustomerPassDetail(passSerialNumber: String, accessToken: String?) async throws -> CustomerPassDetail
    func loadActivity(for merchant: Merchant, location: Location, accessToken: String?) async throws -> [StampEvent]
}

extension PocketStampService {
    func addStamp(to customerPass: CustomerPass, merchant: Merchant, location: Location) async throws -> TapResult {
        try await addStamp(to: customerPass, merchant: merchant, location: location, accessToken: nil)
    }

    func redeemReward(for customerPass: CustomerPass, merchant: Merchant, location: Location) async throws -> TapResult {
        try await redeemReward(for: customerPass, merchant: merchant, location: location, accessToken: nil)
    }

    func loadCustomerPassDetail(passSerialNumber: String) async throws -> CustomerPassDetail {
        try await loadCustomerPassDetail(passSerialNumber: passSerialNumber, accessToken: nil)
    }

    func loadActivity(for merchant: Merchant, location: Location) async throws -> [StampEvent] {
        try await loadActivity(for: merchant, location: location, accessToken: nil)
    }
}
