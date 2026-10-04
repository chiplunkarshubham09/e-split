import Foundation

protocol SettlementRepositoryProtocol {
    func fetchSettlements(groupId: UUID) async throws -> [Settlement]
    func saveSettlement(_ settlement: Settlement) async throws
    func deleteSettlement(id: UUID) async throws
}

final class SettlementRepository: SettlementRepositoryProtocol {
    private let local: LocalExpenseDataSource
    private let remote: RemoteBackend?

    init(local: LocalExpenseDataSource, remote: RemoteBackend? = nil) {
        self.local = local
        self.remote = remote
    }

    func fetchSettlements(groupId: UUID) async throws -> [Settlement] {
        if let remote {
            do {
                let settlements = try await remote.fetchSettlements(groupId: groupId)
                for settlement in settlements {
                    try? local.saveSettlement(settlement)
                }
                return settlements
            } catch {
                return try local.fetchSettlements(groupId: groupId)
            }
        }
        return try local.fetchSettlements(groupId: groupId)
    }

    func saveSettlement(_ settlement: Settlement) async throws {
        if let remote {
            try await remote.saveSettlement(settlement)
        }
        try local.saveSettlement(settlement)
    }

    func deleteSettlement(id: UUID) async throws {
        try local.deleteSettlement(id: id)
    }
}
