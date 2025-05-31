//
//  TableService.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/31.
//

import Foundation
import FirebaseFirestore

enum TableServiceError: Error, LocalizedError {
    case firestoreError(Error)
    case tableNotFound
    case failedToUpdateStatus(String) // String for table ID

    var errorDescription: String? {
        switch self {
        case .firestoreError(let err): return "Table Firestore error: \(err.localizedDescription)"
        case .tableNotFound: return "Table not found."
        case .failedToUpdateStatus(let tableId): return "Failed to update status for table \(tableId)."
        }
    }
}

class TableService {
    static let shared = TableService()
    private let db = Firestore.firestore()

    private func tablesCollectionRef(restaurantId: String) -> CollectionReference {
        db.collection(FirestorePaths.tablesCollection(restaurantId))
    }

    private func tableDocumentRef(restaurantId: String, tableId: String) -> DocumentReference {
        tablesCollectionRef(restaurantId: restaurantId).document(tableId)
    }

    func fetchTables(restaurantId: String) async throws -> [Table] {
        do {
            let snapshot = try await tablesCollectionRef(restaurantId: restaurantId)
                                    .order(by: "displayOrder") // Assuming you want to sort by displayOrder
                                    .getDocuments()
            return try snapshot.documents.compactMap { try $0.data(as: Table.self) }
        } catch {
            throw TableServiceError.firestoreError(error)
        }
    }
    
    // Listener for real-time table updates
    func tablesListener(restaurantId: String, completion: @escaping (Result<[Table], TableServiceError>) -> Void) -> ListenerRegistration {
        let query = tablesCollectionRef(restaurantId: restaurantId)
            .order(by: "displayOrder")

        return query.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(.firestoreError(error)))
                return
            }
            guard let documents = querySnapshot?.documents else {
                completion(.success([])) // No documents
                return
            }
            let tables = documents.compactMap { doc -> Table? in
                do {
                    return try doc.data(as: Table.self)
                } catch {
                    print("Error decoding table \(doc.documentID): \(error)")
                    return nil
                }
            }
            completion(.success(tables))
        }
    }


    // Update status for a single table
    func updateTableStatus(restaurantId: String, tableId: String, newStatus: TableStatus, currentOrderId: String? = nil) async throws {
        var dataToUpdate: [String: Any] = [
            "status": newStatus.rawValue,
            "updatedAt": Timestamp(date: Date())
        ]
        // Manage currentOrderId based on status
        if newStatus == .occupied {
            if let orderId = currentOrderId { dataToUpdate["currentOrderId"] = orderId }
        } else if newStatus == .available {
            dataToUpdate["currentOrderId"] = FieldValue.delete() // Remove currentOrderId when table becomes available
        }
        // Similar logic for reservationId if managing reservations directly on table

        do {
            try await tableDocumentRef(restaurantId: restaurantId, tableId: tableId).updateData(dataToUpdate)
        } catch {
            throw TableServiceError.failedToUpdateStatus(tableId)
        }
    }

    // Update status for multiple tables (e.g., when an order spans multiple tables)
    func updateMultipleTableStatuses(restaurantId: String, tableIds: [String], newStatus: TableStatus, currentOrderId: String? = nil) async throws {
        let batch = db.batch()
        var dataToUpdate: [String: Any] = [
            "status": newStatus.rawValue,
            "updatedAt": Timestamp(date: Date())
        ]
        
        if newStatus == .occupied {
            if let orderId = currentOrderId { dataToUpdate["currentOrderId"] = orderId }
        } else if newStatus == .available {
            dataToUpdate["currentOrderId"] = FieldValue.delete()
        }

        for tableId in tableIds {
            // Skip "takeout" or other special non-physical table codes
            if tableId.lowercased() == AppConfig.shared.restaurantDetails.takeoutTableCode.lowercased() {
                continue
            }
            let ref = tableDocumentRef(restaurantId: restaurantId, tableId: tableId)
            batch.updateData(dataToUpdate, forDocument: ref)
        }
        
        do {
            try await batch.commit()
        } catch {
            throw TableServiceError.failedToUpdateStatus(tableIds.joined(separator: ", "))
        }
    }
    
    // Add Table (Example - UI would call this)
    func addTable(_ table: Table, restaurantId: String) async throws -> String {
        var mutableTable = table
        mutableTable.restaurantId = restaurantId
        mutableTable.createdAt = Timestamp(date:Date())
        mutableTable.updatedAt = Timestamp(date:Date())
        
        // If ID is pre-defined (like "T01"), use it. Otherwise, Firestore auto-generates.
        // For tables, usually IDs are pre-defined.
        guard let tableId = mutableTable.id, !tableId.isEmpty else {
            // Or allow Firestore to auto-generate if IDs are not fixed (less common for tables)
             let ref = try tablesCollectionRef(restaurantId: restaurantId).addDocument(from: mutableTable)
             return ref.documentID
        }
        
        do {
            try tableDocumentRef(restaurantId: restaurantId, tableId: tableId).setData(from: mutableTable)
            return tableId
        } catch {
            throw TableServiceError.firestoreError(error)
        }
    }
}
