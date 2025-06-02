// Views/Main/Orders/OrderDetailView.swift
import SwiftUI
import FirebaseFirestore

struct OrderDetailView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var ordersViewModel: OrdersViewModel
    @State var order: Order // Passed as @State for local modifications if needed

    @StateObject private var menuViewModel = MenuViewModel()
    @State private var showingAddItemSheet = false
    @State private var showingPaymentSheet = false
    @State private var itemToEditQuantity: OrderItem? = nil
    @State private var itemToEditNote: OrderItem? = nil // For note editing sheet
    @State private var showingCancelConfirmation = false // Added for cancel order confirmation

    // Haptic feedback generator
    @State private var hapticFeedbackMedium = UIImpactFeedbackGenerator(style: .medium)
    @State private var hapticFeedbackLight = UIImpactFeedbackGenerator(style: .light) // For non-critical actions
    @State private var hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    // For toast messages within this view
    @State private var showDetailMessageToast = false
    @State private var detailToastMessage: String = ""
    @State private var detailToastType: OrdersListView.ToastType = .info // Reuse from OrdersListView

    // To access statusColor from OrderRow for the *order's* overall status display
    private let orderRowDisplayHelper: OrderRow

    init(ordersViewModel: OrdersViewModel, order: Order) {
        self.ordersViewModel = ordersViewModel
        self._order = State(initialValue: order)
        self.orderRowDisplayHelper = OrderRow(order: order, isNew: false) // For overall order status color
    }
    
    private var isOrderEditable: Bool {
        order.status != AppConfig.OrderStatus.finished &&
        order.status != AppConfig.OrderStatus.cancelled
    }
    
    private var isOrderPayable: Bool {
        isOrderEditable && // Must be editable to be payable
        order.items.contains(where: { $0.status != AppConfig.OrderStatus.cancelled && $0.status != AppConfig.OrderStatus.removed })
    }

    private var displayableItemIndices: [Int] {
        order.items.indices.filter { index in
            let item = order.items[index]
            return (isOrderEditable && item.status != AppConfig.OrderStatus.removed && item.status != AppConfig.OrderStatus.cancelled) || !isOrderEditable
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if geometry.size.width > 700 { // iPad landscape-like width
                    HStack(alignment: .top, spacing: 20) {
                        // Left Column
                        ScrollView { // Make left column scrollable if content exceeds height
                            VStack(alignment: .leading, spacing: 16) {
                                headerSection
                                summarySection
                                Spacer() // Pushes content up if not enough to fill
                            }
                            .padding([.leading, .trailing, .top]) // Add padding for scrollview content
                        }
                        .frame(width: geometry.size.width * 0.4)
                        .background(Color(UIColor.systemGroupedBackground))

                        // Right Column (Items & Actions)
                        ScrollView { // Make item list scrollable independently
                            VStack(alignment: .leading, spacing: 16) {
                                itemsSection
                            }
                            .padding([.trailing, .leading, .top])
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else { // Single column for smaller screens or portrait
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            headerSection
                            summarySection
                            itemsSection
                            Spacer(minLength: 100)
                        }
                        .padding()
                    }
                }
                
                if isOrderEditable {
                    VStack {
                        Spacer()
                        if ordersViewModel.isPrinting || ordersViewModel.isLoadingActiveOrders {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemBackground))
                        } else {
                            actionBarButtons
                        }
                    }
                    .padding()
                    .background(
                        Color(.systemBackground)
                            .shadow(color: .black.opacity(0.1), radius: 5, y: -2)
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
        .navigationTitle("Order #\(order.orderNumber)")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingAddItemSheet) {
            AddItemsToOrderSheet(order: order)
        }
        .sheet(item: $itemToEditQuantity) { itemToEdit in
             EditOrderItemQuantitySheet(item: itemToEdit, order: $order, ordersViewModel: ordersViewModel)
        }
        .sheet(item: $itemToEditNote) { itemNoteToEdit in
            if let index = order.items.firstIndex(where: { $0.id == itemNoteToEdit.id }) {
                ItemNoteEditSheetView(item: $order.items[index], ordersViewModel: ordersViewModel, orderId: order.id!)
            } else {
                Text("Error: Item not found for note editing.")
            }
        }
        .sheet(isPresented: $showingPaymentSheet) {
            PaymentSheetView(order: $order, ordersViewModel: ordersViewModel)
        }
        .overlay(toastOverlay)
        .onReceive(ordersViewModel.$errorMessage) { message in
            if let msg = message, !msg.isEmpty {
                self.detailToastMessage = msg
                self.detailToastType = .error
                self.showDetailMessageToast = true
                DispatchQueue.main.async { ordersViewModel.errorMessage = nil }
            }
        }
        .onReceive(ordersViewModel.$successMessage) { message in
            if let msg = message, !msg.isEmpty {
                self.detailToastMessage = msg
                self.detailToastType = .success
                self.showDetailMessageToast = true
                DispatchQueue.main.async { ordersViewModel.successMessage = nil }
            }
        }
        /**
        .onChange(of: ordersViewModel.activeOrders) { _, newActiveOrders in
            if let updatedOrder = newActiveOrders.first(where: { $0.id == self.order.id }) {
                self.order = updatedOrder
            }
        }
        .onChange(of: ordersViewModel.newOrders) { _, newNewOrders in
            if let updatedOrder = newNewOrders.first(where: { $0.id == self.order.id }) {
                self.order = updatedOrder
            }
        }*/
        .alert("Cancel Order", isPresented: $showingCancelConfirmation) {
            Button("Yes, Cancel", role: .destructive) {
                hapticFeedbackMedium.impactOccurred()
                Task {
                    await ordersViewModel.cancelOrder(order: self.order)
                    if ordersViewModel.errorMessage == nil {
                        dismiss()
                    }
                }
            }
            Button("No", role: .cancel) { }
        } message: {
            Text("Are you sure you want to cancel order #\(order.orderNumber)? This action cannot be undone and will free up the tables.")
        }
        .task {
            if menuViewModel.menuItems.isEmpty {
                menuViewModel.restaurantId = ordersViewModel.restaurantId 
                await menuViewModel.loadInitialData()
            }
        }
    }

    private var mainScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                summarySection
                itemsSection
                Spacer(minLength: 100)
            }
            .padding()
        }
    }

    private var stickyActionBar: some View {
        VStack {
            Spacer()
            if isOrderEditable {
                HStack(spacing: 12) {
                    if ordersViewModel.isPrinting || ordersViewModel.isLoadingActiveOrders {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemBackground))
                    } else {
                        actionBarButtons
                    }
                }
                .padding()
                .background(
                    Color(.systemBackground)
                        .shadow(color: .black.opacity(0.1), radius: 5, y: -2)
                )
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var actionBarButtons: some View {
        Group {
            Button(action: { showingAddItemSheet = true }) {
                Label("Add", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            
            Button {
                Task { await ordersViewModel.printOrderToKitchen(order: order) }
            } label: {
                Label("Print", systemImage: "printer.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(order.status == AppConfig.OrderStatus.printed || 
                    order.items.filter { $0.status != AppConfig.OrderStatus.cancelled && 
                                       $0.status != AppConfig.OrderStatus.removed }.isEmpty)
            
            if isOrderPayable {
                Button(action: { showingPaymentSheet = true }) {
                    Label("Pay", systemImage: "creditcard.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            
            Button(role: .destructive) {
                Task { await ordersViewModel.cancelOrder(order: order) }
            } label: {
                Label("Cancel", systemImage: "xmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if isOrderEditable && !ordersViewModel.isPrinting && !ordersViewModel.isLoadingActiveOrders {
                Button {
                    hapticFeedbackLight.impactOccurred()
                    showingAddItemSheet = true
                } label: { Label("Add Item", systemImage: "plus.circle.fill") }
                .accessibilityLabel("Add item to order")
            }
        }
    }

    private var toastOverlay: some View {
        toastViewForDetail
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 20)
            .padding(.horizontal)
    }

    // MARK: - Subviews for OrderDetailView

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Table(s): \(order.tableDisplayString)")
                    .font(.title2.weight(.semibold))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                Spacer()
                Text(order.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.callout.bold())
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(getStatusColor(order.status).opacity(0.2))
                    .foregroundColor(getStatusColor(order.status))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .foregroundColor(.secondary)
                        .imageScale(.small)
                        .accessibilityHidden(true)
                    Text("Guests: \(order.numberOfGuests)")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .imageScale(.small)
                        .accessibilityHidden(true)
                    Text("Opened: \(order.orderedAt.dateValue(), style: .time)")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                
                if let staffId = order.createdByStaffId, !staffId.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.key")
                            .foregroundColor(.secondary)
                            .imageScale(.small)
                            .accessibilityHidden(true)
                        Text("By Staff: \(staffId)")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Summary")
                .font(.headline)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Subtotal:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formattedPrice(order.subtotalAmount))
                }
                .font(.body)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                
                if order.discountAmount > 0 {
                    HStack {
                        Text("Discount (\(String(format: "%.0f%%", order.discountPercentage))):")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("-\(formattedPrice(order.discountAmount))")
                            .foregroundColor(.orange)
                    }
                    .font(.body)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                HStack {
                    Text("Total:")
                        .font(.headline)
                    Spacer()
                    Text(formattedPrice(order.totalAmount))
                        .font(.title3.bold())
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Order Items")
                    .font(.title3.bold())
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                Text("(\(displayableItemIndices.count))")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                Spacer()
                if isOrderEditable {
                    Button(action: { showingAddItemSheet = true }) {
                        Label("Add Items", systemImage: "plus.circle.fill")
                            .font(.callout.bold())
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            }
            
            if displayableItemIndices.isEmpty {
                Text(isOrderEditable ? "No active items. Add some!" : "No items were recorded.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(displayableItemIndices, id: \.self) { index in
                        if order.items.indices.contains(index) {
                            let currentOrderItem = order.items[index]
                            let menuItem = menuViewModel.menuItems.first(where: { $0.id == currentOrderItem.menuItemId })

                            OrderItemRow(
                                item: $order.items[index],
                                isOrderEditable: isOrderEditable,
                                ordersViewModel: ordersViewModel,
                                order: order,
                                menuItemImageUrl: menuItem?.imageUrl,
                                onEditQuantity: {
                                    hapticFeedback.impactOccurred()
                                    if order.items.indices.contains(index) {
                                        self.itemToEditQuantity = order.items[index]
                                    }
                                },
                                onEditNotes: {
                                    hapticFeedback.impactOccurred(intensity: 0.5)
                                    if order.items.indices.contains(index) {
                                        self.itemToEditNote = order.items[index]
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var printPayAndCancelButtons: some View {
        VStack(spacing: 12) {
            Button {
                hapticFeedbackMedium.impactOccurred()
                Task { await ordersViewModel.printOrderToKitchen(order: order) }
            } label: { Label("Print to Kitchen", systemImage: "printer.dotmatrix.fill").frame(maxWidth: .infinity) }
            .buttonStyle(.borderedProminent).tint(.orange)
            .disabled(ordersViewModel.isPrinting || ordersViewModel.isLoadingActiveOrders || order.status == AppConfig.OrderStatus.printed || order.items.filter { $0.status != AppConfig.OrderStatus.cancelled && $0.status != AppConfig.OrderStatus.removed }.isEmpty)

            if isOrderPayable {
                Button {
                    hapticFeedbackMedium.impactOccurred()
                    showingPaymentSheet = true
                } label: { Label("Proceed to Payment", systemImage: "creditcard.fill").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).tint(.green)
                .disabled(ordersViewModel.isPrinting || ordersViewModel.isLoadingActiveOrders)
            }
            
            Button {
                hapticFeedbackLight.impactOccurred() // Light haptic for bringing up a confirmation
                showingCancelConfirmation = true
            } label: {
                Label("Cancel Order", systemImage: "xmark.octagon.fill")
                    .frame(maxWidth: .infinity)
            }
            .accessibilityLabel("Cancel this order")
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(ordersViewModel.isLoadingActiveOrders || ordersViewModel.isPrinting)
        }
    }

    private func formattedPrice(_ price: Double) -> String {
        let formatter = NumberFormatter(); formatter.numberStyle = .currency; formatter.currencySymbol = "¥"; formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "¥\(Int(price))"
    }

    private var toastViewForDetail: some View {
        Group {
            if showDetailMessageToast {
                Text(detailToastMessage)
                    .font(.callout.bold())
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .padding()
                    .background(detailToastType == .error ? Color.red.opacity(0.9) :
                              (detailToastType == .success ? Color.green.opacity(0.9) :
                                Color.blue.opacity(0.9)))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                            withAnimation { self.showDetailMessageToast = false }
                        }
                    }
            }
        }
    }
}

// MARK: - Item Note Edit Sheet
struct ItemNoteEditSheetView: View {
    @Binding var item: OrderItem
    @ObservedObject var ordersViewModel: OrdersViewModel
    let orderId: String
    @Environment(\.dismiss) var dismiss
    @State private var noteText: String
    @State private var hapticFeedbackMedium = UIImpactFeedbackGenerator(style: .medium)

    init(item: Binding<OrderItem>, ordersViewModel: OrdersViewModel, orderId: String) {
        self._item = item
        self.ordersViewModel = ordersViewModel
        self.orderId = orderId
        // Initialize with current notes, or empty string if nil
        self._noteText = State(initialValue: item.wrappedValue.notes ?? "")
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                TextEditor(text: $noteText)
                    .accessibilityLabel("Item notes text editor")
                    .frame(height: 150)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(UIColor.systemGray3), lineWidth: 1)
                    )
                    .padding(.horizontal)

                Button("Save Note") {
                    hapticFeedbackMedium.impactOccurred()
                    Task {
                        let notesToSave = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                        await ordersViewModel.updateOrderItemNotes(
                            orderId: orderId,
                            itemId: item.id,
                            newNotes: notesToSave.isEmpty ? nil : notesToSave
                        )
                        // The @Binding 'item' in OrderItemRow should reflect this change
                        // if OrdersViewModel correctly updates the order in its published array,
                        // and OrderDetailView's @State order gets updated.
                        dismiss()
                    }
                }
                .accessibilityLabel("Save item note")
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Edit Note for \(item.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel editing note")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { // Clear button
                        noteText = ""
                    } label: { Image(systemName: "clear") }
                    .accessibilityLabel("Clear note text")
                }
            }
        }
    }
}


struct AddItemRow: View {
    let menuItem: MenuItem
    @Binding var selectedQuantity: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(menuItem.name).font(.headline)
                Text(menuItem.nameJP ?? "").font(.caption).foregroundColor(.secondary)
                Text(String(format: "¥%.0f", menuItem.price)).font(.subheadline)
            }
            Spacer()
            Stepper(value: $selectedQuantity, in: 0...20) {
                Text("Qty: \(selectedQuantity)")
            }
            .accessibilityLabel("Quantity of \(menuItem.name) to add, current quantity \(selectedQuantity)")
        }
    }
}

struct EditOrderItemQuantitySheet: View {
    let item: OrderItem
    @Binding var order: Order
    @ObservedObject var ordersViewModel: OrdersViewModel
    @Environment(\.dismiss) var dismiss
    @State private var newQuantity: Int
    @State private var quantityString: String = "" // For TextField
    @State private var hapticFeedbackMedium = UIImpactFeedbackGenerator(style: .medium)


    init(item: OrderItem, order: Binding<Order>, ordersViewModel: OrdersViewModel) {
        self.item = item
        self._order = order
        self.ordersViewModel = ordersViewModel
        let initialQuantity = item.quantity
        _newQuantity = State(initialValue: initialQuantity)
        _quantityString = State(initialValue: "\(initialQuantity)")
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Edit Quantity for").font(.title2.bold())
                Text(item.name).font(.title3)

                HStack {
                    TextField("Enter Quantity", text: $quantityString)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Quantity input field, current value \(quantityString)")
                        .onChange(of: quantityString) { _, newValue in
                            if let qty = Int(newValue), qty >= 0 {
                                let maxQty = 50
                                newQuantity = min(qty, maxQty)
                                if qty > maxQty {
                                    quantityString = "\(maxQty)"
                                }
                            } else if newValue.isEmpty {
                                newQuantity = 0
                            } else {
                                quantityString = "\(newQuantity)"
                            }
                        }
                    Stepper("Quantity: \(newQuantity)", value: $newQuantity, in: 0...50)
                        .accessibilityLabel("Quantity stepper, current quantity \(newQuantity)")
                        .onChange(of: newQuantity) { _, currentQty in
                            quantityString = "\(currentQty)"
                        }
                }
                .padding()
                .onAppear {
                    quantityString = "\(newQuantity)"
                }

                Button(newQuantity == 0 ? "Remove Item" : "Update Quantity") {
                    hapticFeedbackMedium.impactOccurred()
                    if let qtyFromString = Int(quantityString), qtyFromString != newQuantity {
                        newQuantity = qtyFromString >= 0 ? min(qtyFromString, 50) : 0
                    } else if Int(quantityString) == nil && !quantityString.isEmpty {
                        quantityString = "\(newQuantity)"
                    }

                    Task {
                        await ordersViewModel.updateOrderItemQuantity(orderId: order.id!, itemId: item.id, newQuantity: newQuantity)
                        dismiss()
                    }
                }
                .accessibilityLabel(newQuantity == 0 ? "Remove item from order" : "Update item quantity")
                .buttonStyle(.borderedProminent).tint(newQuantity == 0 ? .red : .blue)
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Item")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel editing quantity")
                }
            }
        }
    }
}

// Helper to get status color for order status
private func getStatusColor(_ status: String) -> Color {
    switch status.lowercased() {
    case "new": return .blue
    case "in_progress": return .orange
    case "printed": return .purple
    case "finished": return .green
    case "cancelled": return .red
    default: return .gray
    }
}
