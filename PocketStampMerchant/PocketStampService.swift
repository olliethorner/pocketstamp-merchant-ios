protocol PocketStampService {
    func authenticate(email: String, password: String) async throws -> MerchantUser
    func loadMerchant(for user: MerchantUser) async throws -> Merchant
    func loadLocation(for merchant: Merchant) async throws -> Location
    func registerDevice(for merchant: Merchant, location: Location) async throws -> RegisteredDevice
    func addStamp(to customerPass: CustomerPass, merchant: Merchant, location: Location) async throws -> TapResult
    func redeemReward(for customerPass: CustomerPass, merchant: Merchant, location: Location) async throws -> TapResult
    func logActivity(for result: TapResult, merchant: Merchant, location: Location, device: RegisteredDevice) async throws -> StampEvent
    func loadCustomerPassDetail(passSerialNumber: String) async throws -> CustomerPassDetail
    func loadActivity(for merchant: Merchant, location: Location) async throws -> [StampEvent]
}
