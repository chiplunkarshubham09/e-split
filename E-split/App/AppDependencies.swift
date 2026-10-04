import Foundation
import SwiftData
import SwiftUI

@Observable
final class AppDependencies {
    let authRepository: AuthRepository
    let groupRepository: GroupRepositoryProtocol
    let expenseRepository: ExpenseRepositoryProtocol
    let settlementRepository: SettlementRepositoryProtocol
    let notificationService: NotificationScheduling

    var currentUserStore: CurrentUserProviding { authRepository }

    init(
        authRepository: AuthRepository,
        groupRepository: GroupRepositoryProtocol,
        expenseRepository: ExpenseRepositoryProtocol,
        settlementRepository: SettlementRepositoryProtocol,
        notificationService: NotificationScheduling
    ) {
        self.authRepository = authRepository
        self.groupRepository = groupRepository
        self.expenseRepository = expenseRepository
        self.settlementRepository = settlementRepository
        self.notificationService = notificationService
    }

    static func live(container: ModelContainer) -> AppDependencies {
        let context = ModelContext(container)
        let local = SwiftDataLocalDataSource(context: context)
        let remote: RemoteBackend?
        if SupabaseConfig.isEnabled, let url = SupabaseConfig.projectURL, let key = SupabaseConfig.anonKey {
            remote = SupabaseRemoteDataSource(url: url, anonKey: key)
        } else {
            remote = nil
        }
        return AppDependencies(
            authRepository: AuthRepository(local: local, remote: remote),
            groupRepository: GroupRepository(local: local, remote: remote),
            expenseRepository: ExpenseRepository(local: local, remote: remote),
            settlementRepository: SettlementRepository(local: local, remote: remote),
            notificationService: NotificationService()
        )
    }
}

private struct AppDependenciesKey: EnvironmentKey {
    static var defaultValue: AppDependencies = {
        let container = try! SplitExpenseSchema.makeContainer(inMemory: true)
        return .live(container: container)
    }()
}

extension EnvironmentValues {
    var dependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}
