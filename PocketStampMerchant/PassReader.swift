// This protocol is the integration point for future Apple NFC / ProximityReader support.
// An NFCPassReader can map readVAS Wallet data into CustomerPass without changing the app.
protocol PassReader {
    func readCustomerPass(
        for merchant: Merchant,
        location: Location,
        demoCustomer: DemoCustomer
    ) async throws -> CustomerPass
}
