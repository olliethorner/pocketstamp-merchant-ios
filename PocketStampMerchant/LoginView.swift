import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var demoEmail = "staff@pocketstamp.demo"
    @State private var demoPassword = ""

    var body: some View {
        ZStack {
            PocketStampTheme.cream
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 50)
                    branding
                    accessModePicker
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

    private var accessModePicker: some View {
        Picker("Access mode", selection: accessModeBinding) {
            ForEach(MerchantAccessMode.allCases, id: \.self) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var accessModeBinding: Binding<MerchantAccessMode> {
        Binding {
            viewModel.accessMode
        } set: { mode in
            viewModel.setAccessMode(mode)
        }
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(viewModel.accessMode == .demo ? "Demo mode" : "Merchant login")
                .font(.title2.weight(.semibold))
                .foregroundStyle(PocketStampTheme.espresso)

            Text(viewModel.accessMode == .demo ? "Internal testing with demo merchants and mocked Wallet taps." : "Sign in with your merchant account.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if viewModel.accessMode == .demo {
                demoLoginFields
            } else {
                merchantLoginFields
            }
        }
        .padding(22)
        .pocketStampCard()
    }

    private var demoLoginFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Email", text: $demoEmail)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .padding()
                .background(PocketStampTheme.cream.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            SecureField("Password", text: $demoPassword)
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
                Task {
                    await viewModel.login(email: demoEmail, password: demoPassword)
                    demoPassword = ""
                }
            } label: {
                signInLabel(title: viewModel.isBusy ? "Opening demo..." : "Use demo mode")
            }
            .disabled(viewModel.isBusy)
        }
    }

    private var merchantLoginFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Email", text: $viewModel.authEmail)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding()
                .background(PocketStampTheme.cream.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            SecureField("Password", text: $viewModel.authPassword)
                .textContentType(.password)
                .padding()
                .background(PocketStampTheme.cream.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            if let authErrorMessage = viewModel.authErrorMessage {
                Text(authErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await viewModel.authenticateMerchant() }
            } label: {
                signInLabel(title: viewModel.isAuthenticating ? "Signing in..." : "Sign In")
            }
            .disabled(viewModel.isAuthenticating || viewModel.authEmail.isEmpty || viewModel.authPassword.isEmpty)
        }
    }

    private func signInLabel(title: String) -> some View {
        HStack {
            if viewModel.isBusy || viewModel.isAuthenticating {
                ProgressView()
                    .tint(.white)
            }
            Text(title)
        }
        .fontWeight(.semibold)
        .frame(maxWidth: .infinity)
        .padding()
        .background(PocketStampTheme.espresso)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var prototypeNote: some View {
        Text("Merchant login is the production path. Demo mode remains available for internal testing.")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
    }
}

#Preview {
    LoginView(viewModel: AppViewModel())
}
