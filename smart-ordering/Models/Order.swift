// Models/Order.swift
import FirebaseFirestore

struct Order: Identifiable, Codable, Hashable {
    @DocumentID var id: String? // Firestore document ID
    var restaurantId: String
    var orderNumber: String // Human-readable order number (e.g., daily sequential)
    
    var tableIds: [String] // List of table identifiers (e.g., "T01", "T02", or "takeout")
    var isTakeout: Bool { tableIds.contains(AppConfig.shared.restaurantDetails.takeoutTableCode) }

    var items: [OrderItem] = []
    
    var customerId: String? // If linking to a customer user
    var numberOfGuests: Int = 1
    
    var status: String = AppConfig.OrderStatus.pending // Overall order status
    var paymentStatus: PaymentStatus = .unpaid
    var paymentMethod: String? // e.g., "Cash", "Card_Visa", "PayPay"
    
    var subtotalAmount: Double { // Sum of all item.totalPrice before discounts/taxes
        items.filter { $0.status != AppConfig.OrderStatus.cancelled && $0.status != AppConfig.OrderStatus.removed }
             .reduce(0) { $0 + $1.totalPrice }
    }
    var discountPercentage: Double = 0 // e.g., 10 for 10%
    var discountAmount: Double {
        (subtotalAmount * discountPercentage) / 100.0
    }
    var taxAmount: Double = 0 // Calculated based on local rules
    var serviceChargeAmount: Double = 0
    
    var totalAmount: Double { // Final amount due
        subtotalAmount - discountAmount + taxAmount + serviceChargeAmount
    }
    var amountPaid: Double = 0 // Actual amount received from customer

    var notes: String? // General notes for the order
    var secretCode: String? // For customer web access
    
    var orderedAt: Timestamp = Timestamp(date: Date()) // When the order was first placed
    var lastUpdatedAt: Timestamp = Timestamp(date: Date())
    var printedAt: Timestamp? // When it was first printed to kitchen
    var completedAt: Timestamp? // When order status became "finished"
    var createdByStaffId: String? // Staff member who took/entered the order

    // Computed property for easy display of tables
    var tableDisplayString: String {
        if isTakeout && tableIds.count == 1 {
            return "Takeout"
        }
        return tableIds.joined(separator: ", ")
    }
}

enum PaymentStatus: String, Codable, CaseIterable, Hashable {
    case unpaid
    case partiallyPaid
    case paid
    case refunded
    case partiallyRefunded
}
