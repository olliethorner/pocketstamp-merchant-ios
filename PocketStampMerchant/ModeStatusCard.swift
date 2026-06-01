import SwiftUI

struct ModeStatusCard: View {
    let mode: MerchantMode
    let isBusy: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: mode == .stamp ? "sensor.tag.radiowaves.forward.fill" : "giftcard.fill")
                .font(.system(size: 30))
                .foregroundStyle(mode == .stamp ? PocketStampTheme.brown : PocketStampTheme.redeem)
                .frame(width: 54, height: 54)
                .background(accentColor.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 5) {
                Text(mode.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PocketStampTheme.espresso)

                Text(mode == .stamp ? "Every valid tap adds 1 stamp." : "Tap customer Wallet pass to redeem reward.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(isBusy ? "Reading customer pass..." : mode.readyMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .pocketStampCard()
    }

    private var accentColor: Color {
        mode == .stamp ? PocketStampTheme.brown : PocketStampTheme.redeem
    }
}
