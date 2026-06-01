import SwiftUI

struct Merchant: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let contactEmail: String
    let loyaltyProgram: LoyaltyProgram

    var displayName: String { name }
}

struct Location: Identifiable, Equatable, Sendable {
    let id: UUID
    let merchantId: UUID
    let name: String
    let address: String

    var displayName: String { name }
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

struct LoyaltyProgram: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let rewardName: String
    let rewardThreshold: Int
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
        case .stamp: "Stamp Mode ON"
        case .redeem: "Redeem Mode"
        }
    }

    var readyMessage: String {
        switch self {
        case .stamp: "Ready for customer tap."
        case .redeem: "Ready to redeem reward."
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
        case .stampAdded: "+1 stamp"
        case .rewardAvailable: "+1 stamp - reward available"
        case .rewardRedeemed: "reward redeemed"
        case .notEnoughStamps: "declined: not enough stamps"
        case .wrongMerchant: "declined: wrong merchant"
        case .inactivePass: "declined: inactive pass"
        case .error: "error"
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
