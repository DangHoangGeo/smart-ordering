//
//  OrderRow.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/31.
//
import SwiftUI
import FirebaseCore

struct OrderRow: View {
    let order: Order
    let isNew: Bool
    @State private var hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        HStack {
            OrderInfoSection(order: order, isNew: isNew)
            Spacer()
            OrderStatusSection(order: order)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppConfig.Colors.background)
                .shadow(color: isNew ? AppConfig.Colors.primary.opacity(0.1) : AppConfig.Colors.text.opacity(0.05),
                       radius: isNew ? 6 : 3,
                       y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isNew ? AppConfig.Colors.primary.opacity(0.3) : Color.clear,
                       lineWidth: isNew ? 2 : 0)
        )
        .onTapGesture {
            hapticFeedback.impactOccurred()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(buildAccessibilityLabel())
        .accessibilityHint("Double tap to view order details")
    }
    
    private func buildAccessibilityLabel() -> String {
        var components: [String] = []
        
        if isNew {
            components.append("New")
        }
        
        components.append("Order \(order.orderNumber)")
        components.append("Tables: \(order.tableDisplayString)")
        components.append("\(order.items.count) items")
        components.append("Total \(formattedPrice(order.totalAmount))")
        components.append("Status: \(order.status.replacingOccurrences(of: "_", with: " ").capitalized)")
        
        let pendingCount = order.items.filter { $0.status == AppConfig.OrderStatus.pending }.count
        if pendingCount > 0 {
            components.append("\(pendingCount) pending items")
        }
        
        return components.joined(separator: ", ")
    }
    
    private func formattedPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "¥\(Int(price))"
    }
}

private struct OrderInfoSection: View {
    let order: Order
    let isNew: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            OrderHeaderView(order: order, isNew: isNew)
            
            Text("Table(s): \(order.tableDisplayString)")
                .font(.subheadline)
                .foregroundColor(AppConfig.Colors.text)
                .accessibilityLabel("Assigned to tables: \(order.tableDisplayString)")
            
            OrderDetailsView(order: order)
            
            if let createdByStaffId = order.createdByStaffId {
                StaffInfoView(staffId: createdByStaffId)
            }
        }
    }
}

private struct OrderHeaderView: View {
    let order: Order
    let isNew: Bool
    
    var body: some View {
        HStack {
            Text("Order: \(order.orderNumber)")
                .font(.headline)
                .foregroundColor(isNew ? AppConfig.Colors.primary : AppConfig.Colors.text)
            if isNew {
                Image(systemName: "sparkles")
                    .foregroundColor(AppConfig.Colors.primary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isNew ? "New " : "")Order number \(order.orderNumber)")
    }
}

private struct OrderDetailsView: View {
    let order: Order
    
    var body: some View {
        HStack {
            Image(systemName: "cart")
                .foregroundColor(AppConfig.Colors.secondaryText)
                .accessibilityHidden(true)
            Text("\(order.items.count) items")
                .font(.caption)
            Text("•")
                .foregroundColor(AppConfig.Colors.secondaryText)
                .accessibilityHidden(true)
            Image(systemName: "yensign")
                .foregroundColor(AppConfig.Colors.secondaryText)
                .accessibilityHidden(true)
            Text(formattedPrice(order.totalAmount))
                .font(.caption)
        }
        .foregroundColor(AppConfig.Colors.secondaryText)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(order.items.count) items, total \(formattedPrice(order.totalAmount))")
    }
    
    private func formattedPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "¥\(Int(price))"
    }
}

private struct OrderStatusSection: View {
    let order: Order
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 5) {
            StatusBadge(status: order.status)
                .accessibilityLabel("Status: \(order.status.replacingOccurrences(of: "_", with: " ").capitalized)")
            
            Text(order.orderedAt.dateValue(), style: .time)
                .font(.caption)
                .foregroundColor(AppConfig.Colors.secondaryText)
                .accessibilityLabel("Ordered at \(order.orderedAt.dateValue(), style: .time)")
            
            if !order.items.filter({ $0.status == AppConfig.OrderStatus.pending }).isEmpty {
                PendingItemsBadge(count: order.items.filter({ $0.status == AppConfig.OrderStatus.pending }).count)
                    .accessibilityLabel("\(order.items.filter({ $0.status == AppConfig.OrderStatus.pending }).count) pending items")
            }
        }
    }
}

private struct StaffInfoView: View {
    let staffId: String
    
    var body: some View {
        HStack {
            Image(systemName: "person")
                .foregroundColor(AppConfig.Colors.secondaryText)
                .accessibilityHidden(true)
            Text(staffId)
                .font(.caption2)
                .foregroundColor(AppConfig.Colors.secondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Created by staff \(staffId)")
    }
}

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        let backgroundColor = AppConfig.Colors.statusColor(status, opacity: 0.2)
        let textColor = AppConfig.Colors.statusColor(status)
        
        Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(8)
    }
}

struct PendingItemsBadge: View {
    let count: Int
    
    var body: some View {
        Text("\(count) pending")
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppConfig.Colors.warning.opacity(0.2))
            .foregroundColor(AppConfig.Colors.warning)
            .cornerRadius(6)
    }
}

