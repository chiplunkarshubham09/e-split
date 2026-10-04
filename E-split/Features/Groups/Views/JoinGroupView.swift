import SwiftUI

struct JoinGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: JoinGroupViewModel
    let onJoined: (ExpenseGroup) -> Void

    init(viewModel: JoinGroupViewModel, onJoined: @escaping (ExpenseGroup) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onJoined = onJoined
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let errorMessage = viewModel.errorMessage, viewModel.groupPreview == nil {
                    ErrorBanner(message: errorMessage)
                } else if let group = viewModel.groupPreview {
                    Image(systemName: group.type?.systemImage ?? "person.3.fill")
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.onPrimary)
                        .frame(width: 72, height: 72)
                        .background(AppTheme.primary.gradient, in: RoundedRectangle(cornerRadius: 18))
                    Text("Join \(group.name)")
                        .font(.title2.weight(.semibold))
                    Text("\(group.members.count) members · \(group.currency)")
                        .foregroundStyle(AppTheme.secondary)
                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(message: errorMessage)
                    }
                    Button {
                        Task {
                            if let joined = await viewModel.join() {
                                onJoined(joined)
                                dismiss()
                            }
                        }
                    } label: {
                        Text("Join group")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.primary)
                    .disabled(viewModel.isJoining)
                } else {
                    ProgressView()
                }
                Spacer()
            }
            .padding()
            .background(AppTheme.canvas)
            .navigationTitle("Group invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await viewModel.loadPreview() }
        }
    }
}
