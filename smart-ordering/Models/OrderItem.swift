// Models/OrderItem.swift
import FirebaseFirestore

struct OrderItem: Identifiable, Codable, Hashable {
    var id = UUID().uuidString // Client-generated ID for uniqueness within the order's items array
    
    var menuItemId: String?      // Link to the original MenuItem, if from menu
    var menuItemCode: String?    // Copy of MenuItem.code
    var name: String             // Name of the item (could be custom if not from menu)
    var nameJP: String?
    var namePrint: String?

    var quantity: Int
    var unitPrice: Double        // Price per unit at the time of order
    
    var totalPrice: Double {
        Double(quantity) * unitPrice
    }

    var categoryId: String?      // Copied from MenuItem, for kitchen routing/printing
    var notes: String?          // Customer or staff notes for this item
    var status: String = AppConfig.OrderStatus.pending // e.g., pending, preparing, ready, delivered, cancelled

    var createdAt: Timestamp = Timestamp(date: Date()) // When this item was added to the order
    var lastUpdatedAt: Timestamp = Timestamp(date: Date())
    
    // Initializer for adding a MenuItem to an order
    init(menuItem: MenuItem, quantity: Int, notes: String? = nil) {
        self.menuItemId = menuItem.id
        self.menuItemCode = menuItem.code
        self.name = menuItem.name
        self.nameJP = menuItem.nameJP
        self.namePrint = menuItem.namePrint
        self.quantity = quantity
        self.unitPrice = menuItem.price
        self.categoryId = menuItem.categoryId
        self.notes = notes
        self.status = AppConfig.OrderStatus.pending // Default status when added
    }

    // Initializer for custom/off-menu items
    init(customName: String, quantity: Int, unitPrice: Double, notes: String? = nil, categoryIdForPrint: String? = "CUSTOM_FOOD") {
        self.name = customName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.notes = notes
        self.status = AppConfig.OrderStatus.pending
        self.categoryId = categoryIdForPrint // Helps kitchen printer categorize
    }
}
