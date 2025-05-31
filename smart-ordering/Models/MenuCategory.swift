//
//  MenuCategory.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/26.
//

import FirebaseFirestore

struct MenuCategory: Identifiable, Codable, Hashable, Comparable {
    @DocumentID var id: String?
    var restaurantId: String

    var name: String // e.g., "Appetizers", "Main Courses", "Drinks", "Desserts"
    var nameJP: String?
    var description: String?
    var displayOrder: Int = 0 // For sorting categories

    var createdAt: Timestamp? = Timestamp(date: Date())
    var updatedAt: Timestamp? = Timestamp(date: Date())

    // For Comparable
    static func < (lhs: MenuCategory, rhs: MenuCategory) -> Bool {
        lhs.displayOrder < rhs.displayOrder
    }
    static func == (lhs: MenuCategory, rhs: MenuCategory) -> Bool {
        lhs.id == rhs.id
    }
}
