import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        Group {
            if viewModel.isRestoringSession {
                ZStack {
                    PocketStampTheme.cream
                        .ignoresSafeArea()

                    ProgressView()
                        .tint(PocketStampTheme.brown)
                }
            } else if viewModel.isAuthenticated {
                MerchantHomeView(viewModel: viewModel)
            } else {
                LoginView(viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isRestoringSession)
    }
}

#Preview {
    ContentView()
}
