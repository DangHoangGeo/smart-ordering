//
//  MenuItem.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/26.
//

// Models/MenuItem.swift
import FirebaseFirestore // For Timestamp

struct MenuItem: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var restaurantId: String // To associate with a specific restaurant

    var name: String
    var nameJP: String? // Japanese name
    var namePrint: String? // Name for printing (e.g., shorter, specific characters)
    
    var description: String?
    var price: Double // Use Double for currency
    var imageUrl: String? // URL of the image in Firebase Storage
    
    var categoryId: String // ID of the MenuCategory it belongs to
    var subcategoryId: String? // Optional: for finer-grained grouping within a category

    var code: String? // Optional: Item code like "F001"
    var tags: [String]? // For searching, e.g., ["spicy", "vegetarian"]
    
    var isAvailable: Bool = true // Chef can toggle this
    var displayOrder: Int = 0 // For sorting within a category

    var allergens: [String]? // List of allergens
    var nutritionalInfo: String? // Could be text or a link

    var createdAt: Timestamp? = Timestamp(date: Date())
    var updatedAt: Timestamp? = Timestamp(date: Date())

    // Non-Codable property for holding UIImage during add/edit
    // This will not be saved to Firestore directly.
    var localImage: Data? = nil
}

