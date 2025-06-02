//
//  FirestorePaths.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/26.
//

// Configuration/FirestorePaths.swift
import Foundation

struct FirestorePaths {
    static var config = AppConfig.shared // To access prefix and restaurantId

    // Users
    static func user(userId: String) -> String {
        return "\(config.firestoreCollectionPrefix)/manage/users/\(userId)"
    }
    static var usersCollection: String {
        return "\(config.firestoreCollectionPrefix)/manage/users"
    }

    // Restaurants (base path, specific restaurant data is nested)
    static func restaurantBase(restaurantId: String = config.defaultRestaurantId) -> String {
        return "\(config.firestoreCollectionPrefix)/\(restaurantId)"
    }

    // Orders within a specific restaurant
    // Orders could be stored daily or monthly for archival, but active orders might be in a simpler path.
    // For now, let's assume a general orders collection, and you can decide on archival later.
    // Path for an order by its ID
    static func order(id: String, restaurantId: String = config.defaultRestaurantId) -> String {
        return "\(restaurantBase(restaurantId: restaurantId))/orders/\(id)"
    }
    // Path for the orders collection
    static var ordersCollection: (String) -> String = { restaurantId in
        return "\(restaurantBase(restaurantId: restaurantId))/orders"
    }
    
    // Temporary orders (e.g., from web before confirmation or initial print)
    // These might have a simpler structure or TTL.
    static func temporaryOrder(id: String, restaurantId: String = config.defaultRestaurantId) -> String {
        return "\(restaurantBase(restaurantId: restaurantId))/tmp_orders/\(id)"
    }
    static var temporaryOrdersCollection: (String) -> String = { restaurantId in
        return "\(restaurantBase(restaurantId: restaurantId))/tmp_orders"
    }

    // Menu Items within a specific restaurant
    static func menuItem(id: String, restaurantId: String = config.defaultRestaurantId) -> String {
        return "\(restaurantBase(restaurantId: restaurantId))/menuItems/\(id)"
    }
    static var menuItemsCollection: (String) -> String = { restaurantId in
        return "\(restaurantBase(restaurantId: restaurantId))/menuItems"
    }
    static func menuCategoriesCollection(restaurantId: String = config.defaultRestaurantId) -> String {
        return "\(restaurantBase(restaurantId: restaurantId))/menuCategories"
    }


    // Tables within a specific restaurant
    static func table(id: String, restaurantId: String = config.defaultRestaurantId) -> String {
        return "\(restaurantBase(restaurantId: restaurantId))/tables/\(id)"
    }
    static var tablesCollection: (String) -> String = { restaurantId in
        return "\(restaurantBase(restaurantId: restaurantId))/tables"
    }

    // Add other paths as needed (e.g., reservations, transactions)
    // For example:
    // static func transactionsCollection(restaurantId: String = config.defaultRestaurantId, date: String) -> String {
    //     return "\(restaurantBase(restaurantId: restaurantId))/transactionsByDate/\(date)"
    // }
}
