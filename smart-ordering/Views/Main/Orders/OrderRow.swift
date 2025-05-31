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
                    .foregroundColor(isNew ? .blue : .primary)
                Text("Table(s): \(order.tableDisplayString)")
                    .font(.subheadline)
                Text("Items: \(order.items.count) | Total: \(formattedPrice(order.totalAmount))")
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
            }
        }
        .padding(.vertical, 4)
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
        case AppConfig.OrderStatus.preparing: return Color.yellow.opacity(0.8) // System yellow can be hard to see
        case AppConfig.OrderStatus.readyForDelivery: return .cyan
        case AppConfig.OrderStatus.delivered: return .indigo
        case AppConfig.OrderStatus.finished: return .green
        case AppConfig.OrderStatus.cancelled, AppConfig.OrderStatus.removed: return .gray
        default: return .primary
        }
    }
}
