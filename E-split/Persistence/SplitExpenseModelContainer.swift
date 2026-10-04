import Foundation
import SwiftData

enum SplitExpenseSchema {
    static let models: [any PersistentModel.Type] = [
        UserAccountEntity.self,
        GroupEntity.self,
        GroupMemberEntity.self,
        ExpenseEntity.self,
        ExpenseSplitEntity.self,
        SettlementEntity.self
    ]

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "SplitExpense_v2",
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(
            for: UserAccountEntity.self,
            GroupEntity.self,
            GroupMemberEntity.self,
            ExpenseEntity.self,
            ExpenseSplitEntity.self,
            SettlementEntity.self,
            configurations: configuration
        )
    }
}
