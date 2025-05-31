//
//  User.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/26.
//

import FirebaseFirestore // For @DocumentID

struct AppUser: Identifiable, Codable, Hashable {
    @DocumentID var id: String? // Firestore document ID, maps to Firebase Auth UID
    var email: String
    var displayName: String?
    var photoURL: String?
    var role: UserRole
    var restaurantId: String? // If your app supports multiple restaurants for a user
    var lastLogin: Date?
    var createdAt: Date?

    // Default to a single restaurant for now, can be expanded
    var currentRestaurantId: String {
        restaurantId ?? AppConfig.shared.defaultRestaurantId
    }
}

enum UserRole: String, Codable, CaseIterable, Hashable {
    case owner = "OWNER"         // Highest level access, can manage multiple restaurants
    case manager = "MANAGER"     // Manages a single restaurant
    case chef = "CHEF"
    case staff = "STAFF"         // General staff, e.g., waiter
    case cashier = "CASHIER"     // For POS/payment terminal focused roles (was PC_COUNTER)
    case customer = "CUSTOMER"   // If customers can log in
    case unassigned = "UNASSIGNED" // Default for new users until role is set
}
