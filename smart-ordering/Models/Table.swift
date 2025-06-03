//
//  Table.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/31.
//

import FirebaseFirestore

struct Table: Identifiable, Codable, Hashable, Comparable {
    @DocumentID var id: String?
    var restaurantId: String

    var code: String // User-facing table identifier (e.g., "T01", "1A", "Patio 3")
    var capacity: Int
    var status: TableStatus = .available
    var displayOrder: Int = 0 // For sorting in UI

    var currentOrderId: String? // ID of the order currently occupying this table
    var reservationId: String?  // ID of a reservation holding this table

    var notes: String?
    var section: String? // e.g., "Main Dining", "Bar", "Patio"

    var createdAt: Timestamp? = Timestamp(date: Date())
    var updatedAt: Timestamp? = Timestamp(date: Date())
    
    // For Comparable (based on displayOrder, then code)
    static func < (lhs: Table, rhs: Table) -> Bool {
        if lhs.displayOrder != rhs.displayOrder {
            return lhs.displayOrder < rhs.displayOrder
        }
        return lhs.code.localizedStandardCompare(rhs.code) == .orderedAscending
    }

    static func == (lhs: Table, rhs: Table) -> Bool {
        lhs.id == rhs.id
    }
}

enum TableStatus: String, Codable, CaseIterable, Hashable {
    case available = "Available"
    case occupied = "Occupied"
    case reserved = "Reserved"
    case needsCleaning = "Needs Cleaning"
    case outOfService = "Out of Service"
    // Add other statuses as needed
}
