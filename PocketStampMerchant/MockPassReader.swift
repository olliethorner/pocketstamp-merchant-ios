import Foundation

final class MockPassReader: PassReader {
    private var nextCustomerIndex = 0
    private let kitchenAtTheWharfId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let anotherMerchantId = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!

    func readCustomerPass(for merchant: Merchant, location: Location) async throws -> CustomerPass {
        // This mock reader simulates the future Apple Wallet NFC read. Replace this with
        // ProximityReader/readVAS once Apple entitlement is available. The production
        // reader should map Apple Wallet NFC data into CustomerPass.
        try await Task.sleep(for: .milliseconds(650))

        let customers = [
            CustomerPass(
                customerId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                customerName: "Dannielle Tucker",
                passSerialNumber: "PS-DT-001",
                merchantId: kitchenAtTheWharfId,
                locationId: location.id,
                currentStamps: 5,
                rewardThreshold: 10,
                isActive: true,
                lastUpdated: .now
            ),
            CustomerPass(
                customerId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                customerName: "James Carter",
                passSerialNumber: "PS-JC-002",
                merchantId: kitchenAtTheWharfId,
                locationId: location.id,
                currentStamps: 9,
                rewardThreshold: 10,
                isActive: true,
                lastUpdated: .now
            ),
            CustomerPass(
                customerId: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                customerName: "Sophie Martin",
                passSerialNumber: "PS-SM-003",
                merchantId: kitchenAtTheWharfId,
                locationId: location.id,
                currentStamps: 10,
                rewardThreshold: 10,
                isActive: true,
                lastUpdated: .now
            ),
            CustomerPass(
                customerId: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                customerName: "Alex Morgan",
                passSerialNumber: "PS-AM-004",
                merchantId: anotherMerchantId,
                locationId: nil,
                currentStamps: 4,
                rewardThreshold: 10,
                isActive: true,
                lastUpdated: .now
            )
        ]

        let customer = customers[nextCustomerIndex]
        nextCustomerIndex = (nextCustomerIndex + 1) % customers.count
        return customer
    }
}
