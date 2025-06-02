// Models/Order.swift
import FirebaseFirestore
import SwiftUI

class Order: ObservableObject, Identifiable, Codable, Hashable {
    @DocumentID var id: String? // Firestore document ID
    var restaurantId: String
    var orderNumber: String // Human-readable order number (e.g., daily sequential)
    
    var tableIds: [String] // List of table identifiers (e.g., "T01", "T02", or "takeout")
    var isTakeout: Bool { tableIds.contains(AppConfig.shared.restaurantDetails.takeoutTableCode) }

    @Published var items: [OrderItem] = []
    
    var customerId: String? // If linking to a customer user
    @Published var numberOfGuests: Int = 1
    
    @Published var status: String = AppConfig.OrderStatus.pending // Overall order status
    @Published var paymentStatus: PaymentStatus = .unpaid
    @Published var paymentMethod: String? // e.g., "Cash", "Card_Visa", "PayPay"
    
    var subtotalAmount: Double { // Sum of all item.totalPrice before discounts/taxes
        items.filter { $0.status != AppConfig.OrderStatus.cancelled && $0.status != AppConfig.OrderStatus.removed }
             .reduce(0) { $0 + $1.totalPrice }
    }
    @Published var discountPercentage: Double = 0 // e.g., 10 for 10%
    var discountAmount: Double {
        (subtotalAmount * discountPercentage) / 100.0
    }
    @Published var taxAmount: Double = 0 // Calculated based on local rules
    @Published var serviceChargeAmount: Double = 0
    
    var totalAmount: Double { // Final amount due
        subtotalAmount - discountAmount + taxAmount + serviceChargeAmount
    }
    @Published var amountPaid: Double = 0 // Actual amount received from customer

    @Published var notes: String? // General notes for the order
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
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, restaurantId, orderNumber, tableIds, items, customerId, numberOfGuests,
             status, paymentStatus, paymentMethod, discountPercentage, taxAmount,
             serviceChargeAmount, amountPaid, notes, secretCode, orderedAt, lastUpdatedAt,
             printedAt, completedAt, createdByStaffId
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        restaurantId = try container.decode(String.self, forKey: .restaurantId)
        orderNumber = try container.decode(String.self, forKey: .orderNumber)
        tableIds = try container.decode([String].self, forKey: .tableIds)
        items = try container.decode([OrderItem].self, forKey: .items)
        customerId = try container.decodeIfPresent(String.self, forKey: .customerId)
        numberOfGuests = try container.decode(Int.self, forKey: .numberOfGuests)
        status = try container.decode(String.self, forKey: .status)
        paymentStatus = try container.decode(PaymentStatus.self, forKey: .paymentStatus)
        paymentMethod = try container.decodeIfPresent(String.self, forKey: .paymentMethod)
        discountPercentage = try container.decode(Double.self, forKey: .discountPercentage)
        taxAmount = try container.decode(Double.self, forKey: .taxAmount)
        serviceChargeAmount = try container.decode(Double.self, forKey: .serviceChargeAmount)
        amountPaid = try container.decode(Double.self, forKey: .amountPaid)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        secretCode = try container.decodeIfPresent(String.self, forKey: .secretCode)
        orderedAt = try container.decode(Timestamp.self, forKey: .orderedAt)
        lastUpdatedAt = try container.decode(Timestamp.self, forKey: .lastUpdatedAt)
        printedAt = try container.decodeIfPresent(Timestamp.self, forKey: .printedAt)
        completedAt = try container.decodeIfPresent(Timestamp.self, forKey: .completedAt)
        createdByStaffId = try container.decodeIfPresent(String.self, forKey: .createdByStaffId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(restaurantId, forKey: .restaurantId)
        try container.encode(orderNumber, forKey: .orderNumber)
        try container.encode(tableIds, forKey: .tableIds)
        try container.encode(items, forKey: .items)
        try container.encodeIfPresent(customerId, forKey: .customerId)
        try container.encode(numberOfGuests, forKey: .numberOfGuests)
        try container.encode(status, forKey: .status)
        try container.encode(paymentStatus, forKey: .paymentStatus)
        try container.encodeIfPresent(paymentMethod, forKey: .paymentMethod)
        try container.encode(discountPercentage, forKey: .discountPercentage)
        try container.encode(taxAmount, forKey: .taxAmount)
        try container.encode(serviceChargeAmount, forKey: .serviceChargeAmount)
        try container.encode(amountPaid, forKey: .amountPaid)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(secretCode, forKey: .secretCode)
        try container.encode(orderedAt, forKey: .orderedAt)
        try container.encode(lastUpdatedAt, forKey: .lastUpdatedAt)
        try container.encodeIfPresent(printedAt, forKey: .printedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(createdByStaffId, forKey: .createdByStaffId)
    }
    
    // MARK: - Hashable
    static func == (lhs: Order, rhs: Order) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Initialization
    init(restaurantId: String, orderNumber: String, id: String?, tableIds: [String], items: [OrderItem], status: String, orderedAt: Timestamp, numberOfGuests: Int) {
        self.restaurantId = restaurantId
        self.orderNumber = orderNumber
        self.id = id
        self.tableIds = tableIds
        self.items = items
        self.status = status
        self.orderedAt = orderedAt
        self.numberOfGuests = numberOfGuests
        self.lastUpdatedAt = orderedAt
    }
}

enum PaymentStatus: String, Codable, CaseIterable, Hashable {
    case unpaid
    case partiallyPaid
    case paid
    case refunded
    case partiallyRefunded
}
