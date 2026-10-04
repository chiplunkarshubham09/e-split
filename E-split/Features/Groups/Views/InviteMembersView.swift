import SwiftUI

struct InviteMembersView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: InviteMembersViewModel

    init(viewModel: InviteMembersViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                Text("Share this link. Anyone with a Split Expense account can join as themselves.")
                    .foregroundStyle(AppTheme.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Invite code")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondary)
                    Text(viewModel.group.inviteCode)
                        .font(.title2.weight(.bold).monospaced())
                        .foregroundStyle(AppTheme.primary)
                    Text(viewModel.inviteURL.absoluteString)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppTheme.cardFill, in: RoundedRectangle(cornerRadius: 16))

                ShareLink(item: viewModel.inviteURL, subject: Text(viewModel.group.name), message: Text(viewModel.inviteMessage)) {
                    Label("Share invite link", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)

                Button("Create a new link") {
                    Task { await viewModel.refreshCode() }
                }
                .foregroundStyle(AppTheme.secondary)
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding()
            .background(AppTheme.canvas)
            .navigationTitle("Invite members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await viewModel.ensureCode() }
        }
    }
}
