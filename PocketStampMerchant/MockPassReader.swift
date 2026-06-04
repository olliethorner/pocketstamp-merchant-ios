import Foundation

final class MockPassReader: PassReader {
    func readCustomerPass(
        for merchant: Merchant,
        location: Location,
        demoCustomer: DemoCustomer
    ) async throws -> CustomerPass {
        // This mock reader simulates the future Apple Wallet NFC read. Replace this with
        // ProximityReader/readVAS once Apple entitlement is available. The production
        // reader should map Apple Wallet NFC data into CustomerPass.
        try await Task.sleep(for: .milliseconds(650))

        return CustomerPass(
            customerId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            customerName: demoCustomer.displayName,
            passSerialNumber: demoCustomer.passSerialNumber,
            merchantId: merchant.id,
            locationId: location.id,
            currentStamps: 0,
            rewardThreshold: merchant.loyaltyProgram.rewardThreshold,
            isActive: true,
            lastUpdated: .now
        )
    }
}
