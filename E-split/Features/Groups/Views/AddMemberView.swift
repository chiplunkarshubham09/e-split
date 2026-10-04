import SwiftUI

struct AddMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddMemberViewModel

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage = viewModel.errorMessage {
                    Section { ErrorBanner(message: errorMessage) }
                }
                Section("Member") {
                    TextField("Name", text: $viewModel.name)
                        .textInputAutocapitalization(.words)
                    TextField("Account email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textContentType(.username)
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            if await viewModel.add() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }
}
