//
//  TableService.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/31.
//

import Foundation
import FirebaseFirestore

final class TableService {
    static let shared = TableService()
    private let db = Firestore.firestore()
    private init() {}

    enum TableServiceError: LocalizedError {
        case firestoreError(Error)
        case notFound
        case unknown
        var errorDescription: String? {
            switch self {
            case .firestoreError(let err): return err.localizedDescription
            case .notFound: return "Table not found."
            case .unknown: return "Unknown table service error."
            }
        }
    }

    func fetchTables(restaurantId: String) async throws -> [Table] {
        let snapshot = try await db.collection("restaurants").document(restaurantId).collection("tables").getDocuments()
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: Table.self)
        }
    }

    func tablesListener(restaurantId: String, onChange: @escaping (Result<[Table], TableServiceError>) -> Void) -> ListenerRegistration {
        db.collection("restaurants").document(restaurantId).collection("tables").addSnapshotListener { snapshot, error in
            if let error = error {
                onChange(.failure(.firestoreError(error)))
                return
            }
            guard let docs = snapshot?.documents else {
                onChange(.failure(.unknown)); return
            }
            let tables = docs.compactMap { try? $0.data(as: Table.self) }
            onChange(.success(tables))
        }
    }

    func updateTableStatus(restaurantId: String, tableId: String, newStatus: TableStatus, currentOrderId: String?) async throws {
        let ref = db.collection("restaurants").document(restaurantId).collection("tables").document(tableId)
        try await ref.updateData([
            "status": newStatus.rawValue,
            "currentOrderId": currentOrderId as Any,
            "lastUpdatedAt": Timestamp(date: Date())
        ])
    }

    func updateMultipleTableStatuses(restaurantId: String, tableIds: [String], newStatus: TableStatus, currentOrderId: String?) async throws {
        let batch = db.batch()
        let now = Timestamp(date: Date())
        for tableId in tableIds {
            let ref = db.collection("restaurants").document(restaurantId).collection("tables").document(tableId)
            batch.updateData([
                "status": newStatus.rawValue,
                "currentOrderId": currentOrderId as Any,
                "lastUpdatedAt": now
            ], forDocument: ref)
        }
        try await batch.commit()
    }

    func addTable(restaurantId: String, table: Table) async throws {
        let ref = db.collection("restaurants").document(restaurantId).collection("tables").document(table.id!)
        try ref.setData(from: table)
    }
}
