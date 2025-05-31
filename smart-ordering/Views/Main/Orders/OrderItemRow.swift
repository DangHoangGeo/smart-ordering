//
//  OrderItemRow.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/31.
//

import SwiftUI

struct OrderItemRow: View {
    @Binding var item: OrderItem
    let isOrderEditable: Bool
    let ordersViewModel: OrdersViewModel // To call update functions
    let order: Order // Pass the whole order for context for updates
    // let orderRowHelper: OrderRow // No longer needed if statusColor is local or static

    var onEditQuantity: () -> Void
    
    @State private var showCancelConfirm = false // For confirmation alert
    @State private var showRemoveConfirm = false // For confirmation alert


    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(.headline)
                        .strikethrough(item.status == AppConfig.OrderStatus.removed || item.status == AppConfig.OrderStatus.cancelled, color: .red)
                    if let nameJP = item.nameJP, !nameJP.isEmpty {
                        Text(nameJP).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                // Status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColorForItem(item.status))
                        .frame(width: 12, height: 12)
                    Text(item.status.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption.bold())
                        .foregroundColor(statusColorForItem(item.status))
                }
                Text("x\(item.quantity)")
                    .font(.headline)
                    .padding(.horizontal, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
                    .onTapGesture { if isOrderEditable { onEditQuantity() } }
                Text(formattedPrice(item.totalPrice))
                    .font(.subheadline.weight(.medium))
            }
            if let notes = item.notes, !notes.isEmpty {
                Text("Notes: \(notes)").font(.caption).italic().foregroundColor(.gray)
            }

            if isOrderEditable {
                HStack {
                    Picker("Status", selection: $item.status) {
                        Text("Pending").tag(AppConfig.OrderStatus.pending)
                        Text("Preparing").tag(AppConfig.OrderStatus.preparing)
                        Text("Ready").tag(AppConfig.OrderStatus.readyForDelivery)
                        Text("Delivered").tag(AppConfig.OrderStatus.delivered)
                        Text("Cancel Item").tag(AppConfig.OrderStatus.cancelled)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: item.status) { oldStatus, newStatus in
                        if newStatus == AppConfig.OrderStatus.cancelled && oldStatus != AppConfig.OrderStatus.cancelled {
                            item.status = oldStatus // Revert, show confirmation
                            showCancelConfirm = true
                        } else if newStatus != AppConfig.OrderStatus.removed && newStatus != AppConfig.OrderStatus.cancelled {
                            Task {
                                await ordersViewModel.updateOrderItemStatus(order: order, itemId: item.id, newStatus: newStatus)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            } else {
                Text("Status: \(item.status.replacingOccurrences(of: "_", with: " ").capitalized)")
                    .font(.caption)
                    .foregroundColor(statusColorForItem(item.status)) // Local status color
            }
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isOrderEditable {
                Button(role: .destructive) {
                    showRemoveConfirm = true
                } label: { Label("Remove", systemImage: "trash") }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
             if isOrderEditable {
                Button { onEditQuantity() } label: { Label("Edit Qty", systemImage: "square.and.pencil") }.tint(.blue)
             }
        }
        .alert("Confirm Cancel Item", isPresented: $showCancelConfirm) {
            Button("Cancel Item", role: .destructive) {
                Task { await ordersViewModel.updateOrderItemStatus(order: order, itemId: item.id, newStatus: AppConfig.OrderStatus.cancelled) }
            }
            Button("Keep", role: .cancel) {}
        } message: { Text("Are you sure you want to cancel this item: \(item.name)?") }
        .alert("Confirm Remove Item", isPresented: $showRemoveConfirm) {
            Button("Remove Item", role: .destructive) {
                Task { await ordersViewModel.removeOrderItem(orderId: order.id!, itemId: item.id, softDelete: true) }
            }
            Button("Keep", role: .cancel) {}
        } message: { Text("Are you sure you want to remove this item: \(item.name)? It will be marked as removed.") }
    }
    
    private func formattedPrice(_ price: Double) -> String {
        let formatter = NumberFormatter(); formatter.numberStyle = .currency; formatter.currencySymbol = "¥"; formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "¥\(Int(price))"
    }

    // Local status color helper for items, can be different from overall order status colors
    private func statusColorForItem(_ status: String) -> Color {
        switch status {
        case AppConfig.OrderStatus.pending: return .gray
        case AppConfig.OrderStatus.preparing: return .orange
        case AppConfig.OrderStatus.readyForDelivery: return .blue
        case AppConfig.OrderStatus.delivered: return .green
        case AppConfig.OrderStatus.cancelled, AppConfig.OrderStatus.removed: return .red.opacity(0.7)
        default: return .primary
        }
    }
}

