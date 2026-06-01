import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var email = "staff@kitchenatthewharf.co.uk"
    @State private var password = "prototype"

    var body: some View {
        ZStack {
            PocketStampTheme.cream
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 50)
                    branding
                    loginCard
                    prototypeNote
                }
                .padding(22)
            }
        }
    }

    private var branding: some View {
        VStack(spacing: 12) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 52))
                .foregroundStyle(PocketStampTheme.brown)

            Text("PocketStamp")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(PocketStampTheme.espresso)

            Text("Merchant Reader")
                .font(.headline)
                .foregroundStyle(PocketStampTheme.brown)
        }
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Sign in to your cafe")
                .font(.title2.weight(.semibold))
                .foregroundStyle(PocketStampTheme.espresso)

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .padding()
                .background(PocketStampTheme.cream.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            SecureField("Password", text: $password)
                .textContentType(.password)
                .padding()
                .background(PocketStampTheme.cream.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await viewModel.login(email: email, password: password) }
            } label: {
                HStack {
                    if viewModel.isBusy {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.isBusy ? "Signing in..." : "Sign In")
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(PocketStampTheme.espresso)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(viewModel.isBusy)
        }
        .padding(22)
        .pocketStampCard()
    }

    private var prototypeNote: some View {
        Text("Merchant app prototype. NFC reader mocked until entitlement approval.")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
    }
}

#Preview {
    LoginView(viewModel: AppViewModel())
}
