//
//  OrderRow.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/31.
//
import SwiftUI

struct OrderRow: View {
    let order: Order
    var isNew: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("Order: \(order.orderNumber)")
                    .font(.headline)
                // Removed foregroundColor change, will use background highlight
                Text("Table(s): \(order.tableDisplayString)")
                    .font(.subheadline)

                Text(itemPreviewString())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(order.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption.bold())
                    .padding(5)
                    .background(statusColor(order.status).opacity(0.2))
                    .foregroundColor(statusColor(order.status))
                    .cornerRadius(5)
                Text(order.orderedAt.dateValue(), style: .time)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(timeElapsedString(from: order.orderedAt.dateValue()))
                    .font(.caption2) // Smaller font for less emphasis
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8) // Increased padding a bit for the new line
        .background(isNew ? Color.blue.opacity(0.1) : Color.clear) // Highlight for new orders
        .cornerRadius(isNew ? 5 : 0) // Optional: round corners if highlighted
        .accessibilityHint(isNew ? "This is a new order." : "This is an existing order.")
    }

    private func itemPreviewString() -> String {
        let itemsCount = order.items.count
        let totalString = "Total: \(formattedPrice(order.totalAmount))"

        if itemsCount == 0 {
            return "Items: 0 | \(totalString)"
        }

        let firstItemName = order.items.first?.name ?? "N/A"
        if itemsCount == 1 {
            return "Item: \(firstItemName) | \(totalString)"
        } else {
            // Example: "Items: Pizza, +2 more | Total: ¥3000"
            return "Items: \(firstItemName), +\(itemsCount - 1) more | \(totalString)"
        }
    }

    private func timeElapsedString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated // e.g., "5 min. ago"
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    internal func formattedPrice(_ price: Double) -> String { // Changed to internal for potential reuse if needed
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "¥\(Int(price))"
    }
    
    // This needs to be accessible by OrderDetailView if it creates an OrderRow instance
    // for this helper. If OrderDetailView has its own statusColor, then this can be private.
    // For simplicity and given the previous error, let's make it internal.
    func statusColor(_ status: String) -> Color {
        switch status {
        case AppConfig.OrderStatus.pending: return .orange
        case AppConfig.OrderStatus.printed: return .purple
        case AppConfig.OrderStatus.preparing: return Color(UIColor.systemYellow) // Use system yellow for adaptability
        case AppConfig.OrderStatus.readyForDelivery: return .cyan
        case AppConfig.OrderStatus.delivered: return .indigo
        case AppConfig.OrderStatus.finished: return .green
        case AppConfig.OrderStatus.cancelled, AppConfig.OrderStatus.removed: return .gray
        default: return .primary
        }
    }
}

// Helper extension for Date, could be moved to a separate file
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full // e.g., "5 minutes ago"
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
