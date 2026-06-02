import Foundation

final class LocalBackendMockPassReader: PassReader {
    func readCustomerPass(for merchant: Merchant, location: Location) async throws -> CustomerPass {
        // NFC stays mocked while local integration uses the verified backend Kitchen pass.
        try await Task.sleep(for: .milliseconds(650))

        return CustomerPass(
            customerId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            customerName: "Kitchen test customer",
            passSerialNumber: "kitchen-wharf-test-customer-1775637512162",
            merchantId: merchant.id,
            locationId: location.id,
            currentStamps: 0,
            rewardThreshold: merchant.loyaltyProgram.rewardThreshold,
            isActive: true,
            lastUpdated: .now
        )
    }
}
