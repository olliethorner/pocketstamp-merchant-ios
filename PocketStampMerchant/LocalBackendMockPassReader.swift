import Foundation

final class LocalBackendMockPassReader: PassReader {
    func readCustomerPass(
        for merchant: Merchant,
        location: Location,
        demoCustomer: DemoCustomer
    ) async throws -> CustomerPass {
        // NFC stays mocked while local/Railway integration uses the verified backend Kitchen pass.
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
