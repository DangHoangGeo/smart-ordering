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
    let menuItemImageUrl: String? // New property for menu item image
    // let orderRowHelper: OrderRow // No longer needed if statusColor is local or static

    var onEditQuantity: () -> Void
    var onEditNotes: () -> Void // New callback for editing notes
    
    @State private var showCancelConfirm = false // For confirmation alert
    @State private var showRemoveConfirm = false // For confirmation alert


    var body: some View {
        HStack(alignment: .top, spacing: 10) { // Main HStack for image + content
            if let imageUrlString = menuItemImageUrl, let url = URL(string: imageUrlString) {
                AsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            } else {
                // Placeholder if no image URL, to maintain layout consistency (optional)
                // For now, let it collapse if no image, or use below:
                // Image(systemName: "fork.knife.circle").resizable().scaledToFit().frame(width: 40, height: 40).foregroundColor(.gray.opacity(0.3))
            }

            VStack(alignment: .leading) { // Existing content VStack
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
                Text("x\(item.quantity)")
                    .font(.headline)
                    .padding(.horizontal, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
                    .onTapGesture { if isOrderEditable { onEditQuantity() } }
                Text(formattedPrice(item.totalPrice))
                    .font(.subheadline.weight(.medium))
            }

            // Notes Display and Editing
            if isOrderEditable {
                HStack {
                    if let notes = item.notes, !notes.isEmpty {
                        Text("Notes: \(notes)")
                            .font(.caption).italic().foregroundColor(.gray)
                            .lineLimit(2) // Show a couple of lines
                        Spacer()
                        Button { onEditNotes() } label: { Image(systemName: "pencil.line") }
                            .padding(.leading, 5)
                    } else {
                        Button("Add Note") { onEditNotes() }
                            .font(.caption)
                    }
                }
                .padding(.top, 2)
            } else if let notes = item.notes, !notes.isEmpty {
                Text("Notes: \(notes)").font(.caption).italic().foregroundColor(.gray).lineLimit(2)
            }


            if isOrderEditable {
                HStack {
                    // If more item statuses are added, consider using a Menu { } Picker for scalability.
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

