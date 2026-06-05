import Foundation

struct AuthLoginRequest: Codable, Sendable {
    let email: String
    let password: String
}

struct AuthLoginResponse: Codable, Sendable {
    let ok: Bool
    let session: AuthSession
    let merchantContext: MerchantContext
}

struct AuthSession: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
}

struct AuthMeResponse: Codable, Sendable {
    let ok: Bool
    let merchantContext: MerchantContext
}

struct MerchantContext: Codable, Equatable, Sendable {
    let merchantUserId: String
    let email: String
    let role: String
    let merchantId: String
    let merchantName: String
    let locationId: String
    let locationName: String
}

struct DeviceRegistrationRequest: Codable, Sendable {
    let merchantId: String
    let locationId: String
    let deviceName: String
    let deviceToken: String
}

struct DeviceRegistrationResponse: Codable, Sendable {
    let device: RegisteredDeviceDTO?
    let id: String?
    let merchantId: String?
    let locationId: String?
    let deviceName: String?
    let displayName: String?
    let status: String?
    let registeredAt: Date?
}

struct TapMutationRequest: Codable, Sendable {
    let deviceToken: String
    let passSerialNumber: String
    let idempotencyKey: String
}

struct TapMutationResponse: Codable, Sendable {
    let ok: Bool?
    let result: String?
    let customerPass: CustomerPassDTO?
    let message: String?
}

struct CustomerPassDetailResponse: Codable, Sendable {
    let customerPass: CustomerPassDTO
    let recentActivity: [StampEventDTO]?
}

struct ActivityLogResponse: Codable, Sendable {
    let events: [StampEventDTO]?
    let activity: [StampEventDTO]?
}

struct RegisteredDeviceDTO: Codable, Sendable {
    let id: String?
    let merchantId: String?
    let locationId: String?
    let deviceName: String?
    let displayName: String?
    let status: String?
    let registeredAt: Date?
}

struct CustomerPassDTO: Codable, Sendable {
    let customerId: String?
    let customerName: String?
    let passSerialNumber: String
    let merchantId: String?
    let locationId: String?
    let currentStamps: Int
    let rewardThreshold: Int
    let isActive: Bool
    let lastUpdated: Date?
}

struct StampEventDTO: Codable, Sendable {
    let id: String?
    let merchantId: String?
    let locationId: String?
    let customerId: String?
    let customerName: String?
    let action: String?
    let result: String?
    let state: String?
    let stampBalance: Int?
    let currentStamps: Int?
    let balanceAfter: Int?
    let deviceId: String?
    let merchantDeviceId: String?
    let deviceName: String?
    let createdAt: Date?
}
