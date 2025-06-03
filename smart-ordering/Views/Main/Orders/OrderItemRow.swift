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
    let ordersViewModel: OrdersViewModel
    let order: Order
    let menuItemImageUrl: String?
    
    var onEditQuantity: () -> Void
    var onEditNotes: () -> Void
    
    @State private var showCancelConfirm = false
    @State private var showRemoveConfirm = false
    @State private var hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    @State private var highlightBackground: Bool = false // New state for visual feedback

    private let imageSize: CGFloat = 60
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Item Image
                Group {
                    if let imageUrl = menuItemImageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                Image(systemName: "fork.knife.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 30))
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Image(systemName: "fork.knife.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .font(.system(size: 30))
                    }
                }
                .frame(width: imageSize, height: imageSize)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    // Item Name and Price
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.headline)
                                .strikethrough(item.status == AppConfig.OrderStatus.removed || 
                                             item.status == AppConfig.OrderStatus.cancelled, 
                                             color: .red)
                            if let nameJP = item.nameJP {
                                Text(nameJP)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(item.quantity)×")
                                .font(.title3.bold()) // Increased font size and made bold
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                                .contentShape(Rectangle()) // Make the entire padded area tappable
                                .onTapGesture {
                                    if isOrderEditable {
                                        hapticFeedback.impactOccurred()
                                        onEditQuantity()
                                    }
                                }
                            
                            Text(formattedPrice(item.totalPrice))
                                .font(.headline)
                        }
                    }
                    
                    // Notes and Status
                    VStack(alignment: .leading, spacing: 6) {
                        if let notes = item.notes, !notes.isEmpty {
                            HStack {
                                Image(systemName: "text.bubble")
                                    .foregroundColor(.secondary)
                                Text(notes)
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                    .italic()
                                if isOrderEditable {
                                    Button(action: {
                                        hapticFeedback.impactOccurred(intensity: 0.5)
                                        onEditNotes()
                                    }) {
                                        Image(systemName: "pencil.circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        if isOrderEditable {
                            Picker("Status", selection: $item.status) {
                                Text("Pending").tag(AppConfig.OrderStatus.pending)
                                Text("Preparing").tag(AppConfig.OrderStatus.preparing)
                                Text("Ready").tag(AppConfig.OrderStatus.readyForDelivery)
                                Text("Delivered").tag(AppConfig.OrderStatus.delivered)
                                Text("Cancel").tag(AppConfig.OrderStatus.cancelled)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .onChange(of: item.status) { oldStatus, newStatus in
                                if newStatus == AppConfig.OrderStatus.cancelled && oldStatus != AppConfig.OrderStatus.cancelled {
                                    item.status = oldStatus
                                    hapticFeedback.impactOccurred()
                                    showCancelConfirm = true
                                } else if newStatus != AppConfig.OrderStatus.removed && newStatus != AppConfig.OrderStatus.cancelled {
                                    hapticFeedback.impactOccurred(intensity: 0.5)
                                    Task {
                                        await ordersViewModel.updateOrderItemStatus(order: order, itemId: item.id, newStatus: newStatus)
                                        // Add visual feedback after successful update
                                        withAnimation(.easeInOut(duration: 0.1)) {
                                            highlightBackground = true
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                highlightBackground = false
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            HStack {
                                Circle()
                                    .fill(statusColorForItem(item.status))
                                    .frame(width: 8, height: 8)
                                Text(item.status.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.callout)
                                    .foregroundColor(statusColorForItem(item.status))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(highlightBackground ? Color.accentColor.opacity(0.2) : Color(.systemBackground)) // Conditional background
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            )
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isOrderEditable {
                Button(role: .destructive) {
                    hapticFeedback.impactOccurred()
                    showRemoveConfirm = true
                } label: { Label("Remove", systemImage: "trash") }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
             if isOrderEditable {
                Button {
                    hapticFeedback.impactOccurred(intensity: 0.5)
                    onEditQuantity()
                } label: { Label("Edit Qty", systemImage: "square.and.pencil") }
                .tint(.blue)
                
                Button {
                    hapticFeedback.impactOccurred(intensity: 0.5)
                    onEditNotes()
                } label: { Label("Notes", systemImage: "text.bubble") }
                .tint(.orange)
             }
        }
        .alert("Confirm Cancel Item", isPresented: $showCancelConfirm) {
            Button("Cancel Item", role: .destructive) {
                hapticFeedback.impactOccurred()
                Task {
                    await ordersViewModel.updateOrderItemStatus(order: order, itemId: item.id, newStatus: AppConfig.OrderStatus.cancelled)
                }
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel this item: \(item.name)?")
        }
        .alert("Confirm Remove Item", isPresented: $showRemoveConfirm) {
            Button("Remove Item", role: .destructive) {
                hapticFeedback.impactOccurred()
                Task {
                    await ordersViewModel.removeOrderItem(orderId: order.id!, itemId: item.id, softDelete: true)
                }
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove this item: \(item.name)? It will be marked as removed.")
        }
    }
    
    private func formattedPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "¥\(Int(price))"
    }

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
