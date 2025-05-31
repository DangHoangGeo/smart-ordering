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

    // For toast messages within this view
    @State private var showDetailMessageToast = false
    @State private var detailToastMessage: String = ""
    @State private var detailToastType: OrdersListView.ToastType = .info // Reuse from OrdersListView

    // To access statusColor from OrderRow for the *order's* overall status display
    private let orderRowDisplayHelper: OrderRow

    init(ordersViewModel: OrdersViewModel, order: Order) {
        self.ordersViewModel = ordersViewModel
        self._order = State(initialValue: order)
        self.orderRowDisplayHelper = OrderRow(order: order) // For overall order status color
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
                    .background(Color(UIColor.systemGroupedBackground)) // Optional: give columns distinct backgrounds

                    // Right Column (Items & Actions)
                    ScrollView { // Make item list scrollable independently
                        VStack(alignment: .leading, spacing: 16) { // Add a VStack for spacing
                            itemsSection
                        }
                        .padding([.trailing, .leading, .top]) // Add padding for scrollview content
                    }
                    .frame(maxWidth: .infinity) // Takes remaining space
                }
                // .padding(.top) // Add padding to the HStack if needed, or rely on ScrollView's padding
            } else { // Single column for smaller screens or portrait
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerSection
                        summarySection
                        itemsSection
                        Spacer() // Pushes content up if not enough to fill
                    }
                    .padding() // Standard padding for single column
                }
            }
        }
        .navigationTitle("Order #\(order.orderNumber)")
        .toolbar {
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
        .sheet(isPresented: $showingAddItemSheet) {
            AddItemsToOrderSheet(order: $order, ordersViewModel: ordersViewModel, menuViewModel: menuViewModel)
        }
        .sheet(item: $itemToEditQuantity) { itemToEdit in
             EditOrderItemQuantitySheet(item: itemToEdit, order: $order, ordersViewModel: ordersViewModel)
        }
        .sheet(item: $itemToEditNote) { itemNoteToEdit in
            // We need to find the binding to the item in the order.items array
            // This ensures that if the sheet makes direct local changes (though it shouldn't here, VM handles it),
            // they are on the correct source. More importantly, it's about passing the correct item context.
            // The view model will handle the actual update.
            if let index = order.items.firstIndex(where: { $0.id == itemNoteToEdit.id }) {
                ItemNoteEditSheetView(item: $order.items[index], ordersViewModel: ordersViewModel, orderId: order.id!)
            } else {
                // Fallback or error view if item is not found - should not happen if logic is correct
                Text("Error: Item not found for note editing.")
            }
        }
        .sheet(isPresented: $showingPaymentSheet) {
            PaymentSheetView(order: $order, ordersViewModel: ordersViewModel)
        }
        // Overlay for toast messages specific to this view or passed from ViewModel
        .overlay(
            toastViewForDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 20)
                .padding(.horizontal)
        )
        .onReceive(ordersViewModel.$errorMessage) { message in
            if let msg = message, !msg.isEmpty {
                self.detailToastMessage = msg; self.detailToastType = .error; self.showDetailMessageToast = true
                // Important: Decide where the VM's message gets cleared.
                // If OrdersListView also shows it, avoid double clearing or race conditions.
                // For now, let OrderDetailView clear it if it's the active view.
                 DispatchQueue.main.async { ordersViewModel.errorMessage = nil }
            }
        }
        .alert("Cancel Order", isPresented: $showingCancelConfirmation) {
            Button("Yes, Cancel", role: .destructive) {
                hapticFeedbackMedium.impactOccurred() // Haptic for destructive action
                Task {
                    await ordersViewModel.cancelOrder(order: self.order)
                    // Optionally dismiss view after successful cancellation
                    if ordersViewModel.errorMessage == nil {
                        dismiss()
                    }
                }
            }
            Button("No", role: .cancel) { }
        } message: {
            Text("Are you sure you want to cancel order #\(order.orderNumber)? This action cannot be undone and will free up the tables.")
        }
        .onReceive(ordersViewModel.$successMessage) { message in
            if let msg = message, !msg.isEmpty {
                self.detailToastMessage = msg; self.detailToastType = .success; self.showDetailMessageToast = true
                 DispatchQueue.main.async { ordersViewModel.successMessage = nil }
            }
        }
        .task {
            if menuViewModel.menuItems.isEmpty {
                menuViewModel.restaurantId = ordersViewModel.restaurantId
                await menuViewModel.loadInitialData()
            }
        }
        // Listen for changes in the order passed from OrdersViewModel (if it's a shared instance that gets updated)
        // This ensures that if another part of the app updates this order, this view reflects it.
        // This is more relevant if `order` was an @ObservedObject from a shared source.
        // Since `order` is @State here, it's primarily updated via bindings or direct calls.
        // However, if the `order` in `ordersViewModel.activeOrders` array changes, this @State copy won't automatically.
        // A better pattern might be to pass order.id and fetch/observe it here or ensure the @State var is updated
        // when the source in ordersViewModel changes (e.g. by making `order` an @ObservedObject if it's a class,
        // or by finding and re-assigning it from ordersViewModel.activeOrders on some trigger).
        // For now, we rely on actions within this view triggering updates that also update the VM's source.
        .onChange(of: ordersViewModel.activeOrders) { _, newActiveOrders in
             if let updatedOrder = newActiveOrders.first(where: { $0.id == self.order.id }) {
                 self.order = updatedOrder // Keep local @State in sync
             } else if !isOrderEditable { // If order became finished/cancelled, it might be removed from activeOrders
                 // Potentially dismiss or show a message if the order is no longer "active"
                 // For now, this view will persist with its last known state of the order.
             }
        }
        .onChange(of: ordersViewModel.newOrders) { _, newNewOrders in // Less likely relevant for OrderDetailView
             if let updatedOrder = newNewOrders.first(where: { $0.id == self.order.id }) {
                 self.order = updatedOrder
             }
        }
    }

    // MARK: - Subviews for OrderDetailView

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Table(s): \(order.tableDisplayString)")
                    .font(.title2.bold())
                Spacer()
                Text(order.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption.bold())
                    .padding(6)
                    .background(orderRowDisplayHelper.statusColor(order.status).opacity(0.2))
                    .foregroundColor(orderRowDisplayHelper.statusColor(order.status))
                    .cornerRadius(6)
            }
            Text("Guests: \(order.numberOfGuests)")
                .font(.subheadline).foregroundColor(.secondary)
            Text("Opened: \(order.orderedAt.dateValue(), style: .time)")
                .font(.subheadline).foregroundColor(.secondary)
            if let staffId = order.createdByStaffId, !staffId.isEmpty {
                 Text("By Staff: \(staffId)")
                    .font(.caption).foregroundColor(.gray)
            }
        }
        .padding(.bottom)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Subtotal:"); Spacer(); Text(formattedPrice(order.subtotalAmount)) }
            if order.discountAmount > 0 {
                HStack { Text("Discount (\(String(format: "%.0f%%", order.discountPercentage))):"); Spacer(); Text("-\(formattedPrice(order.discountAmount))").foregroundColor(.orange) }
            }
            HStack { Text("Total:"); Spacer(); Text(formattedPrice(order.totalAmount)).font(.headline.bold()) }
        }
        .font(.subheadline).padding().background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(10)
    }

    private var itemsSection: some View {
        Section(header: Text("Order Items (\(displayableItemIndices.count))").font(.title3.weight(.semibold))) {
            if displayableItemIndices.isEmpty {
                Text(isOrderEditable ? "No active items. Add some!" : "No items were recorded.")
                    .foregroundColor(.secondary).padding(.vertical).frame(maxWidth: .infinity)
            } else {
                ForEach(displayableItemIndices, id: \.self) { index in
                    // Check if index is valid before accessing, crucial if array can change
                    if order.items.indices.contains(index) {
                        let currentOrderItem = order.items[index]
                        let menuItem = menuViewModel.menuItems.first(where: { $0.id == currentOrderItem.menuItemId })

                        OrderItemRow(
                            item: $order.items[index],
                            isOrderEditable: isOrderEditable,
                            ordersViewModel: ordersViewModel,
                            order: order,
                            menuItemImageUrl: menuItem?.imageUrl, // Pass the image URL
                            onEditQuantity: {
                                if order.items.indices.contains(index) { // Double check index validity
                                    self.itemToEditQuantity = order.items[index]
                                }
                            },
                            onEditNotes: { // New callback
                                if order.items.indices.contains(index) {
                                    self.itemToEditNote = order.items[index]
                                }
                            }
                        )
                    }
                }
            }
            
            actionButtonsSection // Extracted action buttons to a new computed property
        }
    }
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        if ordersViewModel.isPrinting || ordersViewModel.isLoadingActiveOrders {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }.padding(.top)
        }
        
        if isOrderEditable {
             printPayAndCancelButtons
                .padding(.top)
        } else if order.status == AppConfig.OrderStatus.finished {
            Button {
                Task { await ordersViewModel.printCustomerReceipt(order: order, isOfficialReceipt: false) }
            } label: { Label("Re-Print Customer Receipt", systemImage: "printer.fill").frame(maxWidth: .infinity) }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .disabled(ordersViewModel.isPrinting || ordersViewModel.isLoadingActiveOrders)
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

    @ViewBuilder
    private var toastViewForDetail: some View {
        if showDetailMessageToast {
            Text(detailToastMessage)
                .padding().background(detailToastType == .error ? Color.red.opacity(0.9) : (detailToastType == .success ? Color.green.opacity(0.9) : Color.blue.opacity(0.9)))
                .foregroundColor(.white).cornerRadius(10).shadow(radius: 5)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                        withAnimation { self.showDetailMessageToast = false }
                    }
                }
        } else { EmptyView() }
    }
}

// MARK: - Item Note Edit Sheet
struct ItemNoteEditSheetView: View {
    @Binding var item: OrderItem
    @ObservedObject var ordersViewModel: OrdersViewModel
    let orderId: String
    @Environment(\.dismiss) var dismiss
    @State private var noteText: String

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


// MARK: - Sheet for Adding Items to Order
struct AddItemsToOrderSheet: View {
    @Binding var order: Order
    @ObservedObject var ordersViewModel: OrdersViewModel
    @ObservedObject var menuViewModel: MenuViewModel // For existing menu items

    @Environment(\.dismiss) var dismiss
    
    // State for selecting existing menu items
    @State private var selectedExistingItems: [MenuItem: Int] = [:]
    @State private var menuSearchText: String = ""
    @FocusState private var isCustomItemNameFieldFocused: Bool // For auto-focus

    // State for adding a custom item
    @State private var showingCustomItemForm = false
    @State private var customItemName: String = ""
    @State private var customItemPriceString: String = ""
    @State private var customItemQuantity: Int = 1
    @State private var customItemNotes: String = ""
    // Optional: category for custom item printing (e.g., "FOOD_CUSTOM", "DRINK_CUSTOM")
    @State private var customItemCategoryForPrint: String = "CUSTOM_FOOD"
    let customCategoriesForPrint = ["CUSTOM_FOOD", "CUSTOM_DRINK", "CUSTOM_OTHER"]


    var body: some View {
        NavigationView {
            VStack {
                Picker("Mode", selection: $showingCustomItemForm) {
                    Text("From Menu").tag(false)
                    Text("Custom Item").tag(true)
                }
                .accessibilityLabel("Select mode for adding items: from menu or custom item")
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top)
                .onChange(of: showingCustomItemForm) { _, isNowCustom in
                    if isNowCustom {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Delay for sheet animation
                            isCustomItemNameFieldFocused = true
                        }
                    }
                }

                if showingCustomItemForm {
                    customItemEntryForm
                } else {
                    menuItemSelectionList
                }
                
                actionButtons
            }
            .navigationTitle("Add Items to Order #\(order.orderNumber)")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
            }
            .task { // Load menu items if not already loaded
                if !showingCustomItemForm && menuViewModel.menuItems.isEmpty {
                    menuViewModel.restaurantId = ordersViewModel.restaurantId
                    await menuViewModel.loadInitialData()
                }
            }
        }
    }

    // Subview for selecting existing menu items
    private var menuItemSelectionList: some View {
        VStack {
            SearchBar(text: $menuSearchText, placeholder: "Search menu...") // Re-use SearchBar from MenuListView
                .padding(.horizontal)
                .padding(.bottom, 5)
            
            List {
                if menuViewModel.isLoading {
                    ProgressView()
                } else if filteredMenuItemsBySearch.isEmpty && !menuSearchText.isEmpty {
                    Text("No menu items match '\(menuSearchText)'.")
                        .foregroundColor(.secondary)
                } else if menuViewModel.menuItems.isEmpty {
                     Text("No menu items available to select.")
                        .foregroundColor(.secondary)
                } else {
                    // Use menuViewModel.itemsGroupedForDisplay logic or a simplified version
                    let categoriesToDisplay = menuViewModel.categories.filter { cat in
                        menuViewModel.menuItems.contains(where: { $0.categoryId == cat.id && $0.isAvailable && (menuSearchText.isEmpty || $0.name.localizedCaseInsensitiveContains(menuSearchText) || ($0.nameJP?.localizedCaseInsensitiveContains(menuSearchText) ?? false)) })
                    }.sorted()

                    ForEach(categoriesToDisplay) { category in
                        Section(header: Text(category.name)) {
                            ForEach(menuViewModel.menuItems.filter { $0.categoryId == category.id && $0.isAvailable && (menuSearchText.isEmpty || $0.name.localizedCaseInsensitiveContains(menuSearchText) || ($0.nameJP?.localizedCaseInsensitiveContains(menuSearchText) ?? false)) }.sorted(by: {$0.displayOrder < $1.displayOrder})) { menuItem in
                                AddItemRow(menuItem: menuItem, selectedQuantity: Binding(
                                    get: { selectedExistingItems[menuItem, default: 0] },
                                    set: { newValue in
                                        if newValue > 0 {
                                            selectedExistingItems[menuItem] = newValue
                                        } else {
                                            selectedExistingItems.removeValue(forKey: menuItem)
                                        }
                                    }
                                ))
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var filteredMenuItemsBySearch: [MenuItem] {
        if menuSearchText.isEmpty {
            return menuViewModel.menuItems.filter { $0.isAvailable }
        }
        return menuViewModel.menuItems.filter {
            $0.isAvailable &&
            ($0.name.localizedCaseInsensitiveContains(menuSearchText) ||
             ($0.nameJP?.localizedCaseInsensitiveContains(menuSearchText) ?? false) ||
             ($0.code?.localizedCaseInsensitiveContains(menuSearchText) ?? false)
            )
        }
    }


    // Subview for entering a custom item
    private var customItemEntryForm: some View {
        Form {
            Section(header: Text("Custom Item Details")) {
                TextField("Item Name (e.g., Special Request)", text: $customItemName)
                    .focused($isCustomItemNameFieldFocused)
                    .accessibilityLabel("Custom item name")
                HStack {
                    Text("Price (¥):")
                    TextField("0", text: $customItemPriceString)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Custom item price")
                }
                Stepper("Quantity: \(customItemQuantity)", value: $customItemQuantity, in: 1...20)
                    .accessibilityLabel("Custom item quantity stepper, current quantity \(customItemQuantity)")
                TextField("Notes (optional)", text: $customItemNotes, axis: .vertical)
                    .lineLimit(3)
                    .accessibilityLabel("Custom item notes")
                Picker("Category for Printing", selection: $customItemCategoryForPrint) {
                    ForEach(customCategoriesForPrint, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ")) }
                }
                .accessibilityLabel("Custom item category for printing")
            }
        }
    }
    
    private var actionButtons: some View {
        VStack {
            if showingCustomItemForm {
                Button("Add Custom Item to Order") {
                    // Consider haptic if this is a primary action in this sheet
                    hapticFeedbackMedium.impactOccurred()
                    addCustomItemToOrder()
                }
                .padding()
                .buttonStyle(.borderedProminent)
                .disabled(customItemName.isEmpty || (Double(customItemPriceString) == nil) || customItemQuantity == 0)
                .accessibilityLabel("Add custom item to order button")
            } else {
                if !selectedExistingItems.isEmpty {
                     Button("Add \(selectedExistingItems.values.reduce(0, +)) Selected Item(s)") {
                        // Consider haptic
                        hapticFeedbackMedium.impactOccurred()
                        addSelectedMenuItemsToOrder()
                    }
                    .padding()
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Add \(selectedExistingItems.values.reduce(0, +)) selected menu items to order button")
                }
            }
        }
        .padding(.bottom)
    }

    private func addSelectedMenuItemsToOrder() {
        Task {
            for (menuItem, quantity) in selectedExistingItems {
                if quantity > 0 {
                    let orderItem = OrderItem(menuItem: menuItem, quantity: quantity)
                    await ordersViewModel.addItemToOrder(orderId: order.id!, item: orderItem)
                }
            }
            if ordersViewModel.errorMessage == nil { // Only dismiss if successful
                dismiss()
            }
        }
    }
    
    private func addCustomItemToOrder() {
        guard !customItemName.isEmpty,
              let price = Double(customItemPriceString), price >= 0,
              customItemQuantity > 0 else {
            // Basic validation, could show an alert
            ordersViewModel.errorMessage = "Invalid custom item details."
            return
        }
        
        let customOrderItem = OrderItem(
            customName: customItemName,
            quantity: customItemQuantity,
            unitPrice: price,
            notes: customItemNotes.isEmpty ? nil : customItemNotes,
            categoryIdForPrint: customItemCategoryForPrint
        )
        
        Task {
            await ordersViewModel.addItemToOrder(orderId: order.id!, item: customOrderItem)
            if ordersViewModel.errorMessage == nil { // Only dismiss if successful
                 dismiss()
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



struct PaymentSheetView: View {
    @Binding var order: Order
    @ObservedObject var ordersViewModel: OrdersViewModel
    @Environment(\.dismiss) var dismiss
    @State private var hapticFeedbackMedium = UIImpactFeedbackGenerator(style: .medium)


    @State private var selectedPaymentMethod: String = AppConfig.PaymentMethods.cash
    @State private var amountTenderedString: String = ""
    @State private var discountPercentString: String = "0"
    
    let paymentMethods = [AppConfig.PaymentMethods.cash, AppConfig.PaymentMethods.payPay, AppConfig.PaymentMethods.creditCard]
    
    private var currentDiscountPercentage: Double { Double(discountPercentString) ?? order.discountPercentage }
    private var subtotalAfterItemDiscounts: Double { order.subtotalAmount }
    private var orderDiscountAmount: Double { (subtotalAfterItemDiscounts * currentDiscountPercentage) / 100.0 }
    private var finalTotal: Double { subtotalAfterItemDiscounts - orderDiscountAmount }
    private var amountTendered: Double? { Double(amountTenderedString) }
    
    private var changeDue: Double? {
        guard let tendered = amountTendered else { return nil }
        return tendered - finalTotal
    }
    
    var canFinalize: Bool {
        if selectedPaymentMethod == AppConfig.PaymentMethods.cash {
            return amountTendered != nil && amountTendered! >= finalTotal
        }
        return true
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Order Summary") {
                    // ... (content as provided before) ...
                    HStack { Text("Subtotal:"); Spacer(); Text(formattedPrice(subtotalAfterItemDiscounts)) }
                    HStack {
                        Text("Order Discount (%):")
                        Spacer()
                        TextField("0", text: $discountPercentString)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 60)
                            .accessibilityLabel("Order discount percentage input")
                    }
                    HStack { Text("Discount Amount:"); Spacer(); Text("-\(formattedPrice(orderDiscountAmount))").foregroundColor(.orange) }
                    HStack { Text("Final Total:"); Spacer(); Text(formattedPrice(finalTotal)).font(.headline.bold()) }
                }

                Section("Payment") {
                    Picker("Payment Method", selection: $selectedPaymentMethod) {
                        ForEach(paymentMethods, id: \.self) { Text($0.capitalized) }
                    }
                    .accessibilityLabel("Select payment method, current method \(selectedPaymentMethod)")
                    
                    if selectedPaymentMethod == AppConfig.PaymentMethods.cash {
                        HStack {
                            Text("Amount Tendered:")
                            Spacer()
                            TextField("Enter amount", text: $amountTenderedString).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .accessibilityLabel("Amount tendered input")
                        }
                        HStack(spacing: 10) {
                            ForEach([1000, 2000, 5000, 10000], id: \.self) { amount in
                                Button("¥\(amount)") {
                                    amountTenderedString = String(amount)
                                }
                                .buttonStyle(.bordered)
                                .fontWeight(.medium)
                                .accessibilityLabel("Set tendered amount to \(amount) yen")
                            }
                            Button("Exact") {
                                amountTenderedString = String(format: "%.0f", finalTotal)
                            }
                            .buttonStyle(.bordered)
                            .fontWeight(.medium)
                            .accessibilityLabel("Set tendered amount to exact total")
                        }
                        .padding(.top, 5)
                        .frame(maxWidth: .infinity, alignment: .center)

                        if let change = changeDue, change >= 0 {
                            HStack { Text("Change Due:"); Spacer(); Text(formattedPrice(change)).font(.headline).foregroundColor(.green) }
                        } else if amountTendered != nil && amountTendered! < finalTotal {
                             Text("Amount tendered is less than total.").foregroundColor(.red).font(.caption).frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                
                Section {
                    Button("Finalize & Pay") {
                        hapticFeedbackMedium.impactOccurred()
                        Task {
                            await ordersViewModel.finalizeOrder(
                                order: order,
                                paymentMethod: selectedPaymentMethod,
                                amountPaid: selectedPaymentMethod == AppConfig.PaymentMethods.cash ? (amountTendered ?? finalTotal) : finalTotal,
                                discountPercentage: currentDiscountPercentage
                            )
                            if ordersViewModel.errorMessage == nil {
                                var finalOrderState = order
                                finalOrderState.paymentMethod = selectedPaymentMethod
                                finalOrderState.amountPaid = selectedPaymentMethod == AppConfig.PaymentMethods.cash ? (amountTendered ?? finalTotal) : finalTotal
                                finalOrderState.discountPercentage = currentDiscountPercentage
                                
                                await ordersViewModel.printCustomerReceipt(order: finalOrderState, isOfficialReceipt: true)
                                dismiss()
                            }
                        }
                    }
                    .disabled(!canFinalize || ordersViewModel.isLoadingActiveOrders || ordersViewModel.isPrinting)
                    .frame(maxWidth: .infinity)
                }
                
                if ordersViewModel.isLoadingActiveOrders || ordersViewModel.isPrinting { ProgressView().frame(maxWidth: .infinity) }
                if let error = ordersViewModel.errorMessage { Text(error).foregroundColor(.red).frame(maxWidth: .infinity) }
            }
            .navigationTitle("Complete Payment")
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } } }
            .onAppear { discountPercentString = String(format: "%.0f", order.discountPercentage) }
        }
    }
    
    private func formattedPrice(_ price: Double) -> String {
        let formatter = NumberFormatter(); formatter.numberStyle = .currency; formatter.currencySymbol = "¥"; formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "¥\(Int(price))"
    }
}
