# PocketStamp Backend Specification

## 1. High-Level Architecture

PocketStamp is a merchant-operated loyalty platform for independent cafes. The backend is the source of truth for merchants, customers, Wallet passes, stamp balances, redemptions, and audit history.

### Components

| Component | Responsibility |
| --- | --- |
| Merchant iOS app | Authenticates staff, registers the till device, reads a future NFC Wallet payload through `PassReader`, and submits stamp or redemption requests. |
| PocketStamp backend API | Validates merchant, device, location, and pass relationships. Applies loyalty rules transactionally. Returns updated pass state and activity records. |
| Supabase/Postgres | Stores accounts, locations, devices, customers, Wallet pass state, balances, events, and Apple Wallet update registrations. |
| Wallet pass service | Generates and signs `.pkpass` packages, builds updated pass payloads, and exposes Apple's Wallet web-service endpoints. |
| Apple Push Notification service (APNs) | Notifies registered customer devices that a Wallet pass changed. Wallet then fetches the latest signed pass package. |
| Future NFC reader | Reads Apple Wallet NFC/VAS data on the merchant iPhone and maps it into a stable pass identifier such as `passSerialNumber`. |

### Stamp Flow

1. Staff signs in to the merchant app and registers the till device.
2. A customer presents their Apple Wallet loyalty pass.
3. The future `NFCPassReader` extracts a pass identifier. Until entitlement approval, `MockPassReader` simulates this step.
4. The app sends the pass identifier, merchant, location, and registered device context to `POST /api/taps/stamp`.
5. The backend validates all relationships and applies exactly one stamp in a database transaction.
6. The backend records an audit event and marks the Wallet pass as updated.
7. The backend notifies registered customer devices through APNs.
8. Apple Wallet requests the updated signed pass from the Wallet web service.
9. The merchant app receives the updated balance and displays the result immediately.

### Redemption Flow

Redemption follows the same structure, but the merchant app calls `POST /api/taps/redeem`. The backend subtracts one loyalty threshold only when sufficient stamps exist.

### Trust Boundary

The merchant app is not authoritative for balances, pass status, or merchant ownership. It submits identifiers and action intent. The backend reloads current state from Postgres and validates every mutation.

## 2. Core Entities and Database Tables

Use UUID primary keys unless an Apple protocol requires a string identifier. Store timestamps as UTC `timestamptz`. Add `created_at` and `updated_at` consistently. Use database constraints and foreign keys in addition to application validation.

### `merchants`

Purpose: A cafe business account. A merchant can own multiple locations and one or more loyalty programs.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` | Primary key. |
| `display_name` | `text` | Customer-facing cafe or brand name. |
| `contact_email` | `text` | Operational contact. |
| `status` | `text` | `active`, `suspended`, or `closed`. |
| `created_at` | `timestamptz` | Audit timestamp. |
| `updated_at` | `timestamptz` | Audit timestamp. |

Relationships: Has many `locations`, `merchant_users`, `devices`, `loyalty_programs`, and `wallet_passes`.

Notes: A suspended merchant must not be able to mutate balances.

### `locations`

Purpose: A physical cafe or till location belonging to a merchant.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` | Primary key. |
| `merchant_id` | `uuid` | Foreign key to `merchants.id`. |
| `display_name` | `text` | Example: `Main Till` or `Wharf Cafe`. |
| `address` | `text` | Human-readable address. |
| `status` | `text` | `active` or `inactive`. |
| `created_at` | `timestamptz` | Audit timestamp. |
| `updated_at` | `timestamptz` | Audit timestamp. |

Relationships: Belongs to one merchant. Has many devices and events.

### `merchant_users`

Purpose: Staff or owner account permitted to access the merchant app.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` | Primary key. May reference the Supabase Auth user ID. |
| `merchant_id` | `uuid` | Foreign key to `merchants.id`. |
| `email` | `text` | Unique login email. |
| `display_name` | `text` | Staff-facing name. |
| `role` | `text` | Suggested values: `owner`, `manager`, `staff`. |
| `status` | `text` | `active` or `disabled`. |
| `last_login_at` | `timestamptz` | Nullable. |
| `created_at` | `timestamptz` | Audit timestamp. |
| `updated_at` | `timestamptz` | Audit timestamp. |

Relationships: Belongs to one merchant. A user may register or operate devices.

Notes: Use Supabase Auth or an equivalent identity provider for password storage and token issuance. Do not store plaintext passwords.

### `devices`

Purpose: A merchant-operated iPhone or till reader authorized to submit taps.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` | Primary key and app-facing `deviceId`. |
| `merchant_id` | `uuid` | Foreign key to `merchants.id`. |
| `location_id` | `uuid` | Foreign key to `locations.id`. |
| `registered_by_user_id` | `uuid` | Foreign key to `merchant_users.id`. |
| `display_name` | `text` | Example: `Main Till iPhone`. |
| `installation_id` | `text` | Stable app-install identifier stored securely on device. |
| `status` | `text` | `registered`, `revoked`, or `inactive`. |
| `last_seen_at` | `timestamptz` | Updated on authenticated API activity. |
| `created_at` | `timestamptz` | Registration timestamp. |
| `updated_at` | `timestamptz` | Audit timestamp. |

Relationships: Belongs to one merchant and location. Referenced by stamp and redemption events.

Notes: Use a unique constraint on `installation_id`. A revoked device cannot mutate balances.

### `customers`

Purpose: A loyalty customer independent of any single Wallet pass.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` | Primary key. |
| `display_name` | `text` | Name shown to merchant staff where consent permits. |
| `email` | `text` | Nullable. Optional for MVP. |
| `status` | `text` | `active`, `blocked`, or `deleted`. |
| `created_at` | `timestamptz` | Audit timestamp. |
| `updated_at` | `timestamptz` | Audit timestamp. |

Relationships: Has many `wallet_passes`.

Notes: Minimize personal data. A pass may work without collecting email.

### `loyalty_programs`

Purpose: Defines the earn and redeem rules for a merchant loyalty card.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` | Primary key. |
| `merchant_id` | `uuid` | Foreign key to `merchants.id`. |
| `name` | `text` | Example: `Coffee Card`. |
| `reward_name` | `text` | Example: `Free coffee`. |
| `reward_threshold` | `integer` | Required positive value, such as `10`. |
| `stamps_per_tap` | `integer` | Default and MVP value: `1`. |
| `status` | `text` | `active` or `inactive`. |
| `created_at` | `timestamptz` | Audit timestamp. |
| `updated_at` | `timestamptz` | Audit timestamp. |

Relationships: Belongs to one merchant. Has many Wallet passes.

Notes: Snapshot the applied threshold on events if program rules may change over time.

### `wallet_passes`

Purpose: Server-side record for an issued Apple Wallet loyalty pass and its authoritative balance.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` | Internal primary key. |
| `customer_id` | `uuid` | Foreign key to `customers.id`. |
| `merchant_id` | `uuid` | Foreign key to `merchants.id`. |
| `loyalty_program_id` | `uuid` | Foreign key to `loyalty_programs.id`. |
| `issued_location_id` | `uuid` | Nullable foreign key to `locations.id`. |
| `pass_type_identifier` | `text` | Apple Pass Type ID. |
| `serial_number` | `text` | Stable unique identifier used by Apple Wallet and merchant taps. |
| `authentication_token_hash` | `text` | Hash of the Wallet web-service authentication token. |
| `current_stamps` | `integer` | Authoritative non-negative balance. |
| `status` | `text` | `active`, `inactive`, `voided`, or `expired`. |
| `last_updated_at` | `timestamptz` | Used by Apple Wallet update checks. |
| `created_at` | `timestamptz` | Issue timestamp. |
| `updated_at` | `timestamptz` | Audit timestamp. |

Relationships: Belongs to a customer, merchant, and loyalty program. Has many stamp events, redemption events, and pass update registrations.

Notes:
- Add a unique constraint on `(pass_type_identifier, serial_number)`.
- Consider a unique constraint on `serial_number` if serials are globally unique.
- Enforce `current_stamps >= 0`.
- Never accept `current_stamps` from the merchant app as a mutation value.

### `stamp_events`

Purpose: Immutable audit record for attempted stamp actions, including declines.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` | Primary key. |
| `merchant_id` | `uuid` | Authenticated merchant context. |
| `location_id` | `uuid` | Authenticated location context. |
| `device_id` | `uuid` | Submitting registered device. |
| `merchant_user_id` | `uuid` | Logged-in staff user. |
| `wallet_pass_id` | `uuid` | Nullable when pass lookup fails. |
| `customer_id` | `uuid` | Nullable when pass lookup fails. |
| `pass_serial_number` | `text` | Submitted identifier for audit. |
| `result` | `text` | `stampAdded`, `rewardAvailable`, `wrongMerchant`, `inactivePass`, `duplicateTap`, or `error`. |
| `stamps_before` | `integer` | Nullable for rejected unknown passes. |
| `stamps_after` | `integer` | Nullable for rejected unknown passes. |
| `idempotency_key` | `text` | Unique client-generated request key. |
| `created_at` | `timestamptz` | Event timestamp. |

Relationships: References merchant, location, device, user, pass, and customer where available.

Notes: Store rejected attempts to support abuse analysis and support investigations.

### `redemption_events`

Purpose: Immutable audit record for attempted reward redemptions, including declines.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` | Primary key. |
| `merchant_id` | `uuid` | Authenticated merchant context. |
| `location_id` | `uuid` | Authenticated location context. |
| `device_id` | `uuid` | Submitting registered device. |
| `merchant_user_id` | `uuid` | Logged-in staff user. |
| `wallet_pass_id` | `uuid` | Nullable when pass lookup fails. |
| `customer_id` | `uuid` | Nullable when pass lookup fails. |
| `pass_serial_number` | `text` | Submitted identifier for audit. |
| `result` | `text` | `rewardRedeemed`, `notEnoughStamps`, `wrongMerchant`, `inactivePass`, `duplicateTap`, or `error`. |
| `threshold_applied` | `integer` | Threshold used for this attempt. |
| `stamps_before` | `integer` | Nullable for rejected unknown passes. |
| `stamps_after` | `integer` | Nullable for rejected unknown passes. |
| `idempotency_key` | `text` | Unique client-generated request key. |
| `created_at` | `timestamptz` | Event timestamp. |

Relationships: References merchant, location, device, user, pass, and customer where available.

### `pass_update_registrations`

Purpose: Stores Apple Wallet device registrations so the backend can notify Wallet when a pass changes.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` | Primary key. |
| `wallet_pass_id` | `uuid` | Foreign key to `wallet_passes.id`. |
| `device_library_identifier` | `text` | Apple Wallet device identifier. |
| `push_token` | `text` | APNs push token supplied by Wallet. Encrypt at rest if practical. |
| `created_at` | `timestamptz` | Registration timestamp. |
| `updated_at` | `timestamptz` | Refresh timestamp. |

Relationships: Belongs to one Wallet pass.

Notes: Add a unique constraint on `(wallet_pass_id, device_library_identifier)`.

## 3. API Endpoints

Use HTTPS only. Return JSON for merchant API endpoints. Return signed `.pkpass` packages where required by Apple's Wallet web-service protocol. Authenticate merchant routes with bearer tokens. Verify that token merchant claims match requested resources.

### `POST /api/merchant/login`

Purpose: Authenticate a merchant user and load the initial app context.

Request:

```json
{
  "email": "staff@kitchenatthewharf.co.uk",
  "password": "secret"
}
```

Response:

```json
{
  "accessToken": "jwt-or-session-token",
  "user": {
    "id": "uuid",
    "merchantId": "uuid",
    "email": "staff@kitchenatthewharf.co.uk",
    "displayName": "Counter Staff"
  },
  "merchant": {
    "id": "uuid",
    "displayName": "Kitchen at the Wharf",
    "contactEmail": "owner@example.com",
    "loyaltyProgram": {
      "id": "uuid",
      "name": "Coffee Card",
      "rewardName": "Free coffee",
      "rewardThreshold": 10
    }
  },
  "defaultLocation": {
    "id": "uuid",
    "merchantId": "uuid",
    "displayName": "Main Till",
    "address": "The Wharf"
  }
}
```

Errors:
- `400 invalidRequest`
- `401 invalidCredentials`
- `403 userDisabled`
- `403 merchantSuspended`

Security: Rate-limit failed attempts. Use an identity provider such as Supabase Auth. Return short-lived access tokens and use a refresh strategy.

### `POST /api/devices/register`

Purpose: Register or refresh a merchant app installation as an authorized reader.

Request:

```json
{
  "merchantId": "uuid",
  "locationId": "uuid",
  "deviceName": "Main Till iPhone",
  "installationId": "secure-device-installation-id"
}
```

Response:

```json
{
  "device": {
    "id": "uuid",
    "merchantId": "uuid",
    "locationId": "uuid",
    "displayName": "Main Till iPhone",
    "status": "registered",
    "registeredAt": "2026-06-01T12:00:00Z"
  }
}
```

Errors:
- `401 unauthenticated`
- `403 merchantMismatch`
- `404 locationNotFound`
- `409 deviceRevoked`

Security: Derive the authenticated merchant from the user token. Confirm the location belongs to that merchant. Store the installation ID in the iOS Keychain.

### `POST /api/taps/stamp`

Purpose: Apply exactly one stamp to a valid pass.

Request:

```json
{
  "merchantId": "uuid",
  "locationId": "uuid",
  "deviceId": "uuid",
  "passSerialNumber": "PS-DT-001",
  "idempotencyKey": "uuid"
}
```

Response:

```json
{
  "result": {
    "id": "uuid",
    "action": "addStamp",
    "state": "stampAdded",
    "isSuccess": true,
    "message": "Stamp added",
    "customerPass": {
      "customerId": "uuid",
      "customerName": "Dannielle Tucker",
      "passSerialNumber": "PS-DT-001",
      "merchantId": "uuid",
      "locationId": "uuid",
      "currentStamps": 6,
      "rewardThreshold": 10,
      "isActive": true,
      "lastUpdated": "2026-06-01T12:04:00Z"
    }
  }
}
```

Errors or declined states:
- `401 unauthenticated`
- `403 deviceNotRegistered`
- `wrongMerchant`
- `inactivePass`
- `duplicateTap`
- `404 passNotFound`

Security: Ignore any client-provided balance. Lock the pass row during mutation. Verify authenticated merchant, device, and location relationships. Enforce idempotency.

### `POST /api/taps/redeem`

Purpose: Redeem one reward from a valid pass.

Request: Same shape as the stamp endpoint, with a unique `idempotencyKey`.

Successful response:

```json
{
  "result": {
    "id": "uuid",
    "action": "redeemReward",
    "state": "rewardRedeemed",
    "isSuccess": true,
    "message": "Reward redeemed",
    "customerPass": {
      "passSerialNumber": "PS-SM-003",
      "currentStamps": 0,
      "rewardThreshold": 10,
      "isActive": true
    }
  }
}
```

Errors or declined states:
- `401 unauthenticated`
- `403 deviceNotRegistered`
- `wrongMerchant`
- `inactivePass`
- `notEnoughStamps`
- `duplicateTap`
- `404 passNotFound`

Security: Lock the pass row and subtract exactly one current program threshold only when the balance is sufficient.

### `GET /api/customer-pass/:passSerialNumber`

Purpose: Load the latest tapped pass state and recent customer-specific events for the merchant app detail sheet.

Response:

```json
{
  "customerPass": {
    "customerId": "uuid",
    "customerName": "Dannielle Tucker",
    "passSerialNumber": "PS-DT-001",
    "merchantId": "uuid",
    "locationId": "uuid",
    "currentStamps": 6,
    "rewardThreshold": 10,
    "isActive": true,
    "lastUpdated": "2026-06-01T12:04:00Z"
  },
  "recentActivity": []
}
```

Errors:
- `401 unauthenticated`
- `403 merchantMismatch`
- `404 passNotFound`

Security: A merchant may load only passes belonging to that merchant, except that a tap mutation response may return minimal wrong-merchant information needed to show a decline. Do not expose another merchant's customer details.

### `GET /api/merchant/activity`

Purpose: Load recent activity for the authenticated merchant and optionally a location.

Query parameters:
- `locationId` optional
- `limit` optional, capped by the server
- `before` optional cursor

Response:

```json
{
  "events": [
    {
      "id": "uuid",
      "customerName": "Dannielle Tucker",
      "result": "stampAdded",
      "stampBalance": 6,
      "deviceName": "Main Till iPhone",
      "createdAt": "2026-06-01T12:04:00Z"
    }
  ],
  "nextCursor": null
}
```

Errors:
- `401 unauthenticated`
- `403 merchantMismatch`
- `404 locationNotFound`

Security: Scope queries by the authenticated merchant before applying optional filters.

### Apple Wallet Web-Service Endpoints

These endpoints implement the Apple Wallet pass update protocol. They are called by Apple Wallet, not the merchant app. Follow Apple's exact path and header requirements when implementing.

### `POST /api/wallet/register-device`

Purpose: Register an Apple Wallet device and push token for updates to a pass.

Recommended production route shape:

```text
POST /api/wallet/v1/devices/:deviceLibraryIdentifier/registrations/:passTypeIdentifier/:serialNumber
```

Request:

```json
{
  "pushToken": "apple-wallet-push-token"
}
```

Response: `201 Created` for a new registration or `200 OK` if refreshed.

Errors:
- `401 invalidPassAuthenticationToken`
- `404 passNotFound`

Security: Validate the pass authentication token supplied in the Apple Wallet request header. Never use merchant authentication for Wallet device registration.

### `GET /api/wallet/passes/:passTypeIdentifier/:serialNumber`

Purpose: Return the newest signed `.pkpass` package after Wallet receives an APNs change notification.

Response:
- Content type: `application/vnd.apple.pkpass`
- Body: Signed pass package bytes
- Include a suitable `Last-Modified` header

Errors:
- `304 Not Modified`
- `401 invalidPassAuthenticationToken`
- `404 passNotFound`

Security: Validate the Wallet pass authentication token. Generate or load only the requested pass record.

### `POST /api/wallet/log`

Purpose: Receive Apple Wallet diagnostic logs.

Request:

```json
{
  "logs": ["Wallet diagnostic message"]
}
```

Response: `200 OK`.

Security: Sanitize and limit payload size. Avoid logging secrets.

### `DELETE /api/wallet/unregister-device`

Purpose: Remove a Wallet device registration for a pass.

Recommended production route shape:

```text
DELETE /api/wallet/v1/devices/:deviceLibraryIdentifier/registrations/:passTypeIdentifier/:serialNumber
```

Response: `200 OK`.

Errors:
- `401 invalidPassAuthenticationToken`
- `404 registrationNotFound`

Security: Validate the Wallet pass authentication token before deletion.

## 4. Stamp Logic

Execute each accepted stamp in a single database transaction:

1. Authenticate the merchant user.
2. Load and validate the registered device.
3. Verify the device belongs to the authenticated merchant and requested location.
4. Load the Wallet pass by serial number with a row lock.
5. Reject a missing pass.
6. Decline with `wrongMerchant` if `wallet_passes.merchant_id` differs from the authenticated merchant.
7. Decline with `inactivePass` if the pass is inactive, voided, or expired.
8. Check the idempotency key and duplicate-tap policy.
9. Increment `current_stamps` by exactly `1`.
10. Set `last_updated_at`.
11. Record an immutable `stamp_events` row.
12. Return `rewardAvailable` when the updated balance meets or exceeds the threshold. Otherwise return `stampAdded`.
13. Commit the transaction.
14. Queue Wallet pass regeneration and APNs notification.

Reaching the threshold never auto-redeems a reward.

## 5. Redemption Logic

Execute each accepted redemption in a single database transaction:

1. Staff explicitly switches the app into Redeem Mode.
2. The customer presents their Wallet pass.
3. The app submits the pass serial number to `POST /api/taps/redeem`.
4. Authenticate and validate merchant, location, and device as for stamping.
5. Load and lock the pass row.
6. Decline wrong-merchant and inactive passes.
7. Read the active loyalty program threshold.
8. If `current_stamps < reward_threshold`, log and return `notEnoughStamps`.
9. Subtract exactly one threshold from the balance.
10. Record an immutable `redemption_events` row.
11. Set the pass update timestamp and commit.
12. Queue Wallet pass regeneration and APNs notification.
13. Return `rewardRedeemed` and the updated balance.

Subtracting the threshold instead of resetting to zero preserves balances above the threshold.

## 6. Apple Wallet Pass Update Flow

The backend owns Wallet pass generation and updates.

1. Store a stable `serial_number` and `pass_type_identifier` when issuing a pass.
2. Store the authoritative loyalty balance in `wallet_passes.current_stamps`.
3. Build `pass.json` from database state, including visible balance and reward messaging.
4. Package required assets and sign the `.pkpass` using the Pass Type ID certificate and Apple WWDR certificate.
5. Cache the generated package by pass ID and `last_updated_at` where practical.
6. On a successful stamp or redemption, update the database first.
7. Enqueue a pass-update job after transaction commit.
8. Send an APNs notification to each registered `push_token` from `pass_update_registrations`.
9. Apple Wallet requests the latest package from `GET /api/wallet/passes/:passTypeIdentifier/:serialNumber`.
10. Return the updated signed package.

Operational notes:
- Store signing certificates and private keys in a secure secret manager, never in source control.
- Process APNs updates asynchronously so merchant tap responses remain fast.
- Retry transient APNs failures with backoff.
- Remove invalid push tokens when APNs reports that they are no longer valid.
- The merchant API should return updated balance immediately without waiting for Wallet refresh.

## 7. Future NFC Integration Mapping

The iOS `PassReader` protocol is the boundary for future Apple NFC integration.

1. Add `NFCPassReader: PassReader` after Apple grants the required entitlement.
2. Use ProximityReader/readVAS to read the customer-presented Wallet NFC payload.
3. Map the NFC payload into the existing `CustomerPass` shape, with the stable `passSerialNumber` or an opaque backend-resolvable pass token.
4. Send that identifier to the backend through `PocketStampService`.
5. Let the backend load authoritative pass state and apply validation.

Do not trust merchant-app fields such as customer name, merchant ID, active status, balance, or threshold. These are useful for UI display in the mock implementation, but the production API must derive them from database state.

If exposing a raw pass serial number over NFC is undesirable, use an opaque signed or rotating token that the backend resolves to a Wallet pass record. Design replay and expiry controls before shipping.

## 8. Security and Abuse Controls

### Authentication and Authorization

- Authenticate merchant users through Supabase Auth or an equivalent provider.
- Use short-lived access tokens and secure refresh handling.
- Derive merchant scope from the authenticated user, not request-body IDs alone.
- Require registered, non-revoked devices for tap mutations.
- Store the app installation ID and tokens in the iOS Keychain.

### Pass Validation

- Confirm the pass exists and belongs to the authenticated merchant.
- Reject inactive, voided, expired, or blocked passes.
- Never accept client-provided balances or threshold values as authoritative.
- Validate location ownership and device ownership on every tap.

### Duplicate Prevention

- Require a unique `idempotencyKey` for every tap request.
- Return the original response when the same idempotency key is retried.
- Add a short configurable duplicate-tap window for the same pass, action, and device.
- Consider a confirmation interaction for unusually rapid repeated stamps.

### Audit and Monitoring

- Log successful and declined stamp and redemption attempts.
- Include user, merchant, location, device, pass serial, timestamp, and result.
- Preserve immutable event history.
- Rate-limit authentication and tap endpoints.
- Alert on unusual patterns such as high-frequency stamping, repeated wrong-merchant taps, or revoked-device requests.
- Redact authentication tokens, push tokens, and secrets from logs.

### Database Security

- Use Postgres constraints for non-negative balances and valid foreign keys.
- Apply row-level security where Supabase clients access tables directly.
- Prefer API-mediated balance mutations through database transactions or stored procedures.
- Restrict certificate and APNs credentials to the Wallet pass service.

## 9. MVP Implementation Plan

### Phase 1: Local Mock Only

Status: represented by the current SwiftUI project.

- Keep `MockPassReader` active.
- Keep `MockPocketStampService` active.
- Exercise stamp, redemption, wrong-merchant, inactive-pass, activity, and pass-detail flows locally.
- Treat `APIModels.swift`, `APIClient.swift`, and `RemotePocketStampService.swift` as compile-ready contracts only.

### Phase 2: Real Database and Merchant API

- Create the Supabase/Postgres schema and migrations.
- Configure Supabase Auth for merchant users.
- Implement device registration.
- Implement transactional stamp and redemption endpoints.
- Add idempotency and duplicate-tap prevention.
- Implement customer-pass detail and merchant activity endpoints.
- Map remote responses into the existing iOS models.
- Switch the app from `MockPocketStampService` to `RemotePocketStampService` behind a development configuration flag.

### Phase 3: Real Wallet Pass Generation and Updates

- Configure Pass Type ID certificate, signing secrets, and APNs credentials.
- Build initial `.pkpass` generation.
- Implement Apple Wallet web-service registration, pass download, unregister, and log endpoints.
- Persist Wallet device registrations.
- Regenerate passes and notify Wallet devices after successful stamp or redemption.
- Monitor APNs delivery and Wallet fetch failures.

### Phase 4: Real NFC Reader

- Obtain Apple entitlement approval.
- Add `NFCPassReader` conforming to the existing `PassReader` protocol.
- Map ProximityReader/readVAS output to a backend-resolvable pass identifier.
- Keep all stamp, redeem, activity, and Wallet-update logic unchanged behind `PocketStampService`.
- Validate replay and abuse controls with real devices before rollout.

## 10. Integration Notes for iOS

The current iOS architecture already exposes the required swap points:

| iOS component | Current implementation | Production implementation |
| --- | --- | --- |
| Pass reading | `MockPassReader` | `NFCPassReader` |
| Business/backend service | `MockPocketStampService` | `RemotePocketStampService` |
| Network transport | Inactive placeholder | `APIClient` |
| API contracts | Compile-ready DTOs | DTOs aligned with deployed endpoint responses |

### `RemotePocketStampService` Responsibilities

Implement `RemotePocketStampService` so it:

1. Calls `POST /api/merchant/login` from `authenticate(email:password:)`.
2. Caches the authenticated token and login context securely.
3. Maps merchant and default location DTOs into existing `Merchant` and `Location` models.
4. Calls `POST /api/devices/register` from `registerDevice(for:location:)`.
5. Calls `POST /api/taps/stamp` from `addStamp(to:merchant:location:)`.
6. Calls `POST /api/taps/redeem` from `redeemReward(for:merchant:location:)`.
7. Maps backend tap responses into existing `TapResult` and `CustomerPass` models.
8. Maps activity DTOs into `StampEvent`.
9. Loads `GET /api/customer-pass/:passSerialNumber` if the detail sheet needs a server refresh.
10. Loads `GET /api/merchant/activity` when the app starts or refreshes.

### Required iOS Contract Adjustments Before Remote Activation

The DTO layer is intentionally lightweight. Before activating the remote service:

- Add `installationId` and `idempotencyKey` to request DTOs and generate them in the app.
- Persist access and refresh tokens in Keychain.
- Decide whether `logActivity` remains a separate service call or whether tap responses always return the committed activity event.
- Add retry rules for transient network failures without duplicating taps.
- Add loading and offline messaging suitable for a counter device.
- Confirm the NFC payload format and whether it supplies a serial number or opaque token.

The merchant UI should remain simple: authenticate, register device, select Stamp or Redeem Mode, process a tap, show the latest result, and expose lightweight pass details. Reporting, customer search, campaigns, and manual adjustments belong in a separate merchant dashboard.
