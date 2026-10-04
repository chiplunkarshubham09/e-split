import SwiftUI

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: CreateGroupViewModel
    let onCreated: (ExpenseGroup) -> Void

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        ErrorBanner(message: errorMessage)
                    }
                }

                Section("Group") {
                    TextField("Name", text: $viewModel.name)
                        .textInputAutocapitalization(.words)
                    TextField("Description", text: $viewModel.description, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("Currency", selection: $viewModel.currency) {
                        ForEach(viewModel.currencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                }

                Section("Type (optional)") {
                    Picker("Type", selection: $viewModel.type) {
                        Text("None").tag(Optional<GroupType>.none)
                        ForEach(GroupType.allCases) { type in
                            Label(type.title, systemImage: type.systemImage).tag(Optional(type))
                        }
                    }
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            if let group = await viewModel.create() {
                                onCreated(group)
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
