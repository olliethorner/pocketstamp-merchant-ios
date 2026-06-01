import Foundation

// Backend contract DTOs for the future PocketStamp API. NFC reading remains separate:
// PassReader produces a CustomerPass, then PocketStampService sends stamp or redeem
// actions to the backend. Wallet pass updates will be issued server-side after balances change.
//
// Intended endpoints:
// POST /api/merchant/login
// POST /api/devices/register
// POST /api/taps/stamp
// POST /api/taps/redeem
// GET  /api/merchant/activity
// GET  /api/customer-pass/{passSerialNumber}

struct MerchantLoginRequest: Codable, Sendable {
    let email: String
    let password: String
}

struct MerchantLoginResponse: Codable, Sendable {
    let accessToken: String
    let user: MerchantUserDTO
    let merchant: MerchantDTO
    let defaultLocation: LocationDTO
}

struct DeviceRegistrationRequest: Codable, Sendable {
    let merchantId: UUID
    let locationId: UUID
    let deviceName: String
}

struct DeviceRegistrationResponse: Codable, Sendable {
    let device: RegisteredDeviceDTO
}

struct AddStampRequest: Codable, Sendable {
    let merchantId: UUID
    let locationId: UUID
    let deviceId: UUID
    let passSerialNumber: String
}

struct AddStampResponse: Codable, Sendable {
    let result: TapResultDTO
}

struct RedeemRewardRequest: Codable, Sendable {
    let merchantId: UUID
    let locationId: UUID
    let deviceId: UUID
    let passSerialNumber: String
}

struct RedeemRewardResponse: Codable, Sendable {
    let result: TapResultDTO
}

struct ActivityLogResponse: Codable, Sendable {
    let events: [StampEventDTO]
}

struct CustomerPassDetailResponse: Codable, Sendable {
    let customerPass: CustomerPassDTO
    let recentActivity: [StampEventDTO]
}

struct MerchantUserDTO: Codable, Sendable {
    let id: UUID
    let merchantId: UUID
    let email: String
    let displayName: String
}

struct MerchantDTO: Codable, Sendable {
    let id: UUID
    let displayName: String
    let contactEmail: String
    let loyaltyProgram: LoyaltyProgramDTO
}

struct LocationDTO: Codable, Sendable {
    let id: UUID
    let merchantId: UUID
    let displayName: String
    let address: String
}

struct RegisteredDeviceDTO: Codable, Sendable {
    let id: UUID
    let merchantId: UUID
    let locationId: UUID
    let displayName: String
    let status: String
    let registeredAt: Date
}

struct LoyaltyProgramDTO: Codable, Sendable {
    let id: UUID
    let name: String
    let rewardName: String
    let rewardThreshold: Int
}

struct CustomerPassDTO: Codable, Sendable {
    let customerId: UUID
    let customerName: String
    let passSerialNumber: String
    let merchantId: UUID
    let locationId: UUID?
    let currentStamps: Int
    let rewardThreshold: Int
    let isActive: Bool
    let lastUpdated: Date
}

struct TapResultDTO: Codable, Sendable {
    let id: UUID
    let action: String
    let state: String
    let customerPass: CustomerPassDTO
    let isSuccess: Bool
    let message: String
}

struct StampEventDTO: Codable, Sendable {
    let id: UUID
    let merchantId: UUID
    let locationId: UUID
    let customerId: UUID
    let customerName: String
    let action: String
    let result: String
    let stampBalance: Int
    let deviceId: UUID
    let deviceName: String
    let createdAt: Date
}
