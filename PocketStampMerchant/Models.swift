import SwiftUI

struct Merchant: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let contactEmail: String
    let loyaltyProgram: LoyaltyProgram
    let backendId: String?
    let backendDeviceToken: String?

    var displayName: String { name }

    init(
        id: UUID,
        name: String,
        contactEmail: String,
        loyaltyProgram: LoyaltyProgram,
        backendId: String? = nil,
        backendDeviceToken: String? = nil
    ) {
        self.id = id
        self.name = name
        self.contactEmail = contactEmail
        self.loyaltyProgram = loyaltyProgram
        self.backendId = backendId
        self.backendDeviceToken = backendDeviceToken
    }
}

struct Location: Identifiable, Equatable, Sendable {
    let id: UUID
    let merchantId: UUID
    let name: String
    let address: String
    let backendId: String?
    let backendDeviceToken: String?

    var displayName: String { name }

    init(
        id: UUID,
        merchantId: UUID,
        name: String,
        address: String,
        backendId: String? = nil,
        backendDeviceToken: String? = nil
    ) {
        self.id = id
        self.merchantId = merchantId
        self.name = name
        self.address = address
        self.backendId = backendId
        self.backendDeviceToken = backendDeviceToken
    }
}

struct MerchantUser: Identifiable, Equatable, Sendable {
    let id: UUID
    let merchantId: UUID
    let email: String
    let displayName: String
}

struct RegisteredDevice: Identifiable, Equatable, Sendable {
    let id: UUID
    let merchantId: UUID
    let locationId: UUID
    let name: String
    let status: DeviceStatus
    let registeredAt: Date

    var displayName: String { name }
}

enum DeviceStatus: String, Sendable {
    case registered

    var displayName: String { rawValue.capitalized }
}

struct Customer: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let email: String?

    var displayName: String { name }
}

struct CustomerPass: Identifiable, Equatable, Sendable {
    let customerId: UUID
    let customerName: String
    let passSerialNumber: String
    let merchantId: UUID
    let locationId: UUID?
    var currentStamps: Int
    let rewardThreshold: Int
    let isActive: Bool
    var lastUpdated: Date

    var id: UUID { customerId }
}

struct DemoCustomer: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let passSerialNumber: String
    let subtitle: String

    static let railwayTestCustomer = DemoCustomer(
        id: "railway-test-customer",
        displayName: "Test Customer",
        passSerialNumber: "kitchen-wharf-test-customer-1775637512162",
        subtitle: "Railway demo pass"
    )

    static let all: [DemoCustomer] = [
        .railwayTestCustomer
    ]
}

struct DemoMerchant: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let locationId: String
    let locationName: String
    let loyaltyProgramId: String
    let backendDeviceToken: String
    let subtitle: String
    let demoCustomers: [DemoCustomer]

    static let kitchenAtTheWharf = DemoMerchant(
        id: "kitchen-at-the-wharf",
        displayName: "Kitchen at the Wharf",
        locationId: "kitchen-at-the-wharf-main",
        locationName: "Main Till",
        loyaltyProgramId: "kitchen-at-the-wharf-coffee",
        backendDeviceToken: "demo-main-till-iphone",
        subtitle: "Main Till",
        demoCustomers: [
            .railwayTestCustomer
        ]
    )

    static let mrMiles = DemoMerchant(
        id: "mr-miles",
        displayName: "Mr Miles",
        locationId: "mr-miles-taunton",
        locationName: "Taunton",
        loyaltyProgramId: "mr-miles-coffee",
        backendDeviceToken: "mr-miles-main-till-iphone",
        subtitle: "Taunton",
        demoCustomers: [
            DemoCustomer(
                id: "mr-miles-demo-customer",
                displayName: "Mr Miles Demo Customer",
                passSerialNumber: "mr-miles-demo-customer",
                subtitle: "Railway demo pass"
            )
        ]
    )

    static let all: [DemoMerchant] = [
        .kitchenAtTheWharf,
        .mrMiles
    ]

    func makeMerchant(contactEmail: String) -> Merchant {
        Merchant(
            id: stableUUID(from: id),
            name: displayName,
            contactEmail: contactEmail,
            loyaltyProgram: LoyaltyProgram(
                id: stableUUID(from: loyaltyProgramId),
                name: "Coffee Card",
                rewardName: "Free coffee",
                rewardThreshold: 10,
                backendId: loyaltyProgramId
            ),
            backendId: id,
            backendDeviceToken: backendDeviceToken
        )
    }

    func makeLocation(for merchant: Merchant) -> Location {
        Location(
            id: stableUUID(from: locationId),
            merchantId: merchant.id,
            name: locationName,
            address: subtitle,
            backendId: locationId,
            backendDeviceToken: backendDeviceToken
        )
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

struct LoyaltyProgram: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let rewardName: String
    let rewardThreshold: Int
    let backendId: String?

    init(
        id: UUID,
        name: String,
        rewardName: String,
        rewardThreshold: Int,
        backendId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.rewardName = rewardName
        self.rewardThreshold = rewardThreshold
        self.backendId = backendId
    }
}

struct StampEvent: Identifiable, Equatable, Sendable {
    let id: UUID
    let merchantId: UUID
    let locationId: UUID
    let customerId: UUID
    let customerName: String
    let action: TapAction
    let result: TapResultState
    let stampBalance: Int
    let deviceId: UUID
    let deviceName: String
    let createdAt: Date
}

struct RedemptionEvent: Identifiable, Equatable, Sendable {
    let id: UUID
    let merchantId: UUID
    let locationId: UUID
    let customerId: UUID
    let passSerialNumber: String
    let deviceId: UUID
    let stampsRedeemed: Int
    let createdAt: Date
}

enum MerchantMode: String, CaseIterable, Sendable {
    case stamp
    case redeem

    var title: String {
        switch self {
        case .stamp: "Stamp Mode"
        case .redeem: "Redeem Mode"
        }
    }

    var readyMessage: String {
        switch self {
        case .stamp, .redeem: "Ready for Wallet tap."
        }
    }

    var actionDescription: String {
        switch self {
        case .stamp: "Tap a customer pass to add 1 stamp."
        case .redeem: "Tap a customer pass to redeem an available reward."
        }
    }
}

enum TapAction: String, Sendable {
    case addStamp
    case redeemReward

    var title: String {
        switch self {
        case .addStamp: "+1 stamp"
        case .redeemReward: "Redeem reward"
        }
    }
}

enum TapResultState: String, Sendable {
    case stampAdded
    case rewardAvailable
    case rewardRedeemed
    case notEnoughStamps
    case wrongMerchant
    case inactivePass
    case error

    var title: String {
        switch self {
        case .stampAdded: "Stamp added"
        case .rewardAvailable: "Reward available"
        case .rewardRedeemed: "Reward redeemed"
        case .notEnoughStamps: "Not enough stamps"
        case .wrongMerchant: "Wrong merchant"
        case .inactivePass: "Inactive Wallet pass"
        case .error: "Something went wrong"
        }
    }

    var activityDescription: String {
        switch self {
        case .stampAdded: "Stamp added"
        case .rewardAvailable: "Reward available"
        case .rewardRedeemed: "Reward redeemed"
        case .notEnoughStamps: "Not enough stamps"
        case .wrongMerchant: "Wrong merchant"
        case .inactivePass: "Inactive pass"
        case .error: "Something went wrong"
        }
    }
}

struct TapResult: Identifiable, Equatable, Sendable {
    let id: UUID
    let action: TapAction
    let state: TapResultState
    let customerPass: CustomerPass
    let isSuccess: Bool
    let message: String
}

struct CustomerPassDetail: Equatable, Sendable {
    let customerPass: CustomerPass
    let recentActivity: [StampEvent]
}

enum PocketStampError: LocalizedError {
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "Enter an email address and password to continue."
        }
    }
}

enum PocketStampTheme {
    static let cream = Color(red: 0.98, green: 0.95, blue: 0.89)
    static let espresso = Color(red: 0.16, green: 0.11, blue: 0.08)
    static let brown = Color(red: 0.48, green: 0.31, blue: 0.20)
    static let caramel = Color(red: 0.91, green: 0.76, blue: 0.57)
    static let redeem = Color(red: 0.26, green: 0.39, blue: 0.34)
}

extension View {
    func pocketStampCard(cornerRadius: CGFloat = 24) -> some View {
        self
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 7)
    }
}
