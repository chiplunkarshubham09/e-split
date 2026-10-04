import SwiftUI

struct EditGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: EditGroupViewModel

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage = viewModel.errorMessage {
                    Section { ErrorBanner(message: errorMessage) }
                }
                Section("Group") {
                    TextField("Name", text: $viewModel.name)
                    TextField("Description", text: $viewModel.description, axis: .vertical)
                    Picker("Currency", selection: $viewModel.currency) {
                        ForEach(viewModel.currencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    Picker("Type", selection: $viewModel.type) {
                        Text("None").tag(Optional<GroupType>.none)
                        ForEach(GroupType.allCases) { type in
                            Text(type.title).tag(Optional(type))
                        }
                    }
                }
                Section("Members") {
                    ForEach(viewModel.members) { member in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(member.name)
                                Text(member.role.title)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondary)
                            }
                            Spacer()
                            Button("Remove", role: .destructive) {
                                Task {
                                    if let message = await viewModel.removeMember(member) {
                                        viewModel.errorMessage = message
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
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
