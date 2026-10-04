import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Split Expense")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(AppTheme.primary)
                        Text(viewModel.isRegistering ? "Create an account to track your expenses." : "Log in to add expenses and join groups.")
                            .foregroundStyle(AppTheme.secondary)
                    }
                    .padding(.top, 24)

                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    VStack(spacing: 16) {
                        if viewModel.isRegistering {
                            TextField("Your name", text: $viewModel.name)
                                .textContentType(.name)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .background(AppTheme.cardFill, in: RoundedRectangle(cornerRadius: 12))
                        }

                        TextField("Email", text: $viewModel.email)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(AppTheme.cardFill, in: RoundedRectangle(cornerRadius: 12))

                        SecureField("Password", text: $viewModel.password)
                            .textContentType(.password)
                            .padding()
                            .background(AppTheme.cardFill, in: RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        Task { _ = await viewModel.submit() }
                    } label: {
                        Text(viewModel.isRegistering ? "Create account" : "Log in")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
                    .disabled(viewModel.isWorking)

                    Button(viewModel.isRegistering ? "Already have an account? Log in" : "New here? Create an account") {
                        viewModel.isRegistering.toggle()
                        viewModel.errorMessage = nil
                    }
                    .foregroundStyle(AppTheme.primary)
                    .frame(maxWidth: .infinity)

                    Text(SupabaseConfig.isEnabled
                         ? "Your account syncs across phones, so invite links work for anyone with the app."
                         : "Add your Supabase URL and anon key in Info.plist to sync accounts and invites across phones.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondary)
                        .padding(.top, 8)
                }
                .padding()
            }
            .background(AppTheme.canvas)
            .navigationBarHidden(true)
        }
    }
}
