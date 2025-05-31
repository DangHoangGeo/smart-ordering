// ViewModels/OrdersViewModel.swift
import SwiftUI
import Combine
import FirebaseFirestore // For ListenerRegistration, Timestamp
import UserNotifications // For local notifications example

@MainActor
class OrdersViewModel: ObservableObject {
    @Published var newOrders: [Order] = []         // Orders with status 'pending' from web
    @Published var activeOrders: [Order] = []      // Orders being processed (printed, preparing, etc.)
    // @Published var completedOrdersToday: [Order] = [] // Optional

    @Published var isLoadingNewOrders: Bool = false
    @Published var isLoadingActiveOrders: Bool = false
    @Published var isPrinting: Bool = false // Specific flag for printing operations
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let orderService = OrderService.shared
    private let printerService = PrinterService.shared
    private let tableService = TableService.shared // Added TableService
    private let printFormatter = PrintFormatter()
    private var newOrdersListener: ListenerRegistration?
    var restaurantId: String

    private var cancellables = Set<AnyCancellable>()

    init(restaurantId: String = AppConfig.shared.defaultRestaurantId) {
        self.restaurantId = restaurantId
        listenForNewOrders()
        Task {
            await fetchActiveOrders()
        }
    }

    func updateOrderItemNotes(orderId: String, itemId: String, newNotes: String?) async {
        guard var currentOrder = findOrderLocally(orderId: orderId),
              let itemIndex = currentOrder.items.firstIndex(where: { $0.id == itemId }) else {
            errorMessage = "Order or item not found for notes update."
            return
        }

        errorMessage = nil
        successMessage = nil

        let trimmedNotes = newNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
        // Update notes: set to nil if trimmed string is empty, otherwise use trimmed string
        currentOrder.items[itemIndex].notes = (trimmedNotes?.isEmpty ?? true) ? nil : trimmedNotes
        currentOrder.items[itemIndex].lastUpdatedAt = Timestamp(date: Date())
        currentOrder.lastUpdatedAt = Timestamp(date: Date())

        do {
            // Assuming orderService.updateOrder can save the whole order with modified item notes
            try await orderService.updateOrder(currentOrder)
            updateLocalOrder(currentOrder) // This should correctly update the @Published orders arrays
            successMessage = "Item notes updated successfully."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.successMessage = nil }
        } catch {
            self.errorMessage = (error as? OrderServiceError ?? OrderServiceError.firestoreError(error)).localizedDescription
        }
    }

    deinit {
        newOrdersListener?.remove()
        print("OrdersViewModel deinitialized, listener removed.")
    }

    // MARK: - Data Fetching and Listening
    func listenForNewOrders() {
        isLoadingNewOrders = true
        errorMessage = nil
        newOrdersListener?.remove() // Ensure no duplicate listeners

        newOrdersListener = orderService.newOrdersListener(restaurantId: restaurantId) { [weak self] result in
            guard let self = self else { return }
            self.isLoadingNewOrders = false
            switch result {
            case .success(let orders):
                let oldOrderIds = Set(self.newOrders.compactMap { $0.id })
                self.newOrders = orders.sorted(by: { $0.orderedAt.dateValue() > $1.orderedAt.dateValue() }) // Newest first
                
                // Check for genuinely new orders to trigger notification
                let currentOrderIds = Set(self.newOrders.compactMap { $0.id })
                let genuinelyNewOrders = self.newOrders.filter { !oldOrderIds.contains($0.id!) }
                
                if !genuinelyNewOrders.isEmpty {
                    self.triggerNewOrderNotification(genuinelyNewOrders.first)
                }
                
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                print("Error listening for new orders: \(error.localizedDescription)")
            }
        }
        print("Started listening for new orders for restaurant: \(restaurantId)")
    }

    func fetchActiveOrders() async {
        isLoadingActiveOrders = true
        errorMessage = nil
        do {
            self.activeOrders = try await orderService.fetchActiveOrders(restaurantId: restaurantId)
                                        .sorted(by: { $0.orderedAt.dateValue() < $1.orderedAt.dateValue() }) // Oldest active first
        } catch {
            self.errorMessage = (error as? OrderServiceError ?? OrderServiceError.firestoreError(error)).localizedDescription
            print("Error fetching active orders: \(error.localizedDescription)")
        }
        isLoadingActiveOrders = false
    }

    func refreshAllData() async {
        isLoadingNewOrders = true
        isLoadingActiveOrders = true
        errorMessage = nil
        successMessage = nil

        listenForNewOrders() // This will re-establish the listener and set isLoadingNewOrders
        await fetchActiveOrders()  // This sets isLoadingActiveOrders

        if errorMessage == nil { // Only show success if no errors occurred during refresh
            successMessage = "Order data refreshed."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.successMessage = nil }
        }
    }

    // MARK: - Order Creation
    func createManualOrder(tableIds: [String], numberOfGuests: Int, createdByStaffId: String) async -> Order? {
        errorMessage = nil
        successMessage = nil
        isLoadingActiveOrders = true // Indicate activity

        let newOrderNumber = await orderService.generateOrderNumber(restaurantId: self.restaurantId)
        
        var order = Order(
            restaurantId: self.restaurantId,
            orderNumber: newOrderNumber,
            tableIds: tableIds,
            numberOfGuests: numberOfGuests,
            status: AppConfig.OrderStatus.pending,
            createdByStaffId: createdByStaffId
        )
        
        do {
            let orderDocId = try await orderService.createOrder(order)
            order.id = orderDocId
            
            // Add to local list immediately for responsiveness
            if !activeOrders.contains(where: {$0.id == order.id}) {
                 activeOrders.append(order)
                 activeOrders.sort(by: { $0.orderedAt.dateValue() < $1.orderedAt.dateValue() })
            }

            // Update table statuses to .occupied
            do {
                try await tableService.updateMultipleTableStatuses(
                    restaurantId: self.restaurantId,
                    tableIds: order.tableIds,
                    newStatus: .occupied,
                    currentOrderId: order.id
                )
                successMessage = "Order \(order.orderNumber) created for table(s) \(order.tableDisplayString)."
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.successMessage = nil }
                isLoadingActiveOrders = false
                return order
            } catch {
                // If table status update fails, consider rolling back order creation or logging a critical error
                print("Error updating table status after order creation: \(error.localizedDescription)")
                self.errorMessage = "Order created, but failed to update table status: \(error.localizedDescription)"
                isLoadingActiveOrders = false
                return nil // Or return order and let UI handle partial success
            }
        } catch {
            self.errorMessage = (error as? OrderServiceError ?? OrderServiceError.firestoreError(error)).localizedDescription
            isLoadingActiveOrders = false
            return nil
        }
    }

    // MARK: - Status Updates
    func updateOrderStatus(order: Order, newStatus: String) async {
        guard let orderId = order.id else {
            self.errorMessage = "Order ID missing, cannot update status."
            return
        }
        errorMessage = nil
        successMessage = nil
        // Optimistically update UI before network call for faster perceived response (optional)
        // let originalStatus = order.status
        // updateLocalOrderStatus(orderId: orderId, newStatus: newStatus)
        
        do {
            try await orderService.updateOrderStatus(restaurantId: self.restaurantId, orderId: orderId, newStatus: newStatus)
            // Refresh local state after successful Firestore update to ensure consistency
            updateLocalOrderStatus(orderId: orderId, newStatus: newStatus, successful: true)
            successMessage = "Order \(order.orderNumber) status updated to \(newStatus.capitalized)."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.successMessage = nil }
        } catch {
            self.errorMessage = (error as? OrderServiceError ?? OrderServiceError.firestoreError(error)).localizedDescription
            // Revert optimistic update if it failed
            // updateLocalOrderStatus(orderId: orderId, newStatus: originalStatus)
            // For simplicity, a full refresh or relying on listeners might be easier than manual revert.
             await fetchActiveOrders() // Or specific list refresh
             await fetchNewOrdersIfNeeded() // If it could have been a new order
        }
    }
    
    // Helper to update local arrays
    private func updateLocalOrderStatus(orderId: String, newStatus: String, successful: Bool = true) {
        var orderToMove: Order?

        if let index = newOrders.firstIndex(where: { $0.id == orderId }) {
            if successful {
                newOrders[index].status = newStatus
                newOrders[index].lastUpdatedAt = Timestamp(date: Date())
                if newStatus != AppConfig.OrderStatus.pending { // Moved out of "new"
                    orderToMove = newOrders.remove(at: index)
                }
            }
        } else if let index = activeOrders.firstIndex(where: { $0.id == orderId }) {
             if successful {
                activeOrders[index].status = newStatus
                activeOrders[index].lastUpdatedAt = Timestamp(date: Date())
                 if newStatus == AppConfig.OrderStatus.finished || newStatus == AppConfig.OrderStatus.cancelled {
                    // Order is completed or cancelled, remove from active list
                    // orderToMove = activeOrders.remove(at: index)
                    // Optionally add to a 'completedOrdersToday' list
                    // self.completedOrdersToday.append(orderToMove)
                    // For now, just remove. A separate view can fetch completed orders.
                    activeOrders.remove(at: index)
                 }
             }
        }

        if let movedOrder = orderToMove {
            if movedOrder.status != AppConfig.OrderStatus.pending &&
               movedOrder.status != AppConfig.OrderStatus.finished &&
               movedOrder.status != AppConfig.OrderStatus.cancelled {
                activeOrders.append(movedOrder)
                activeOrders.sort(by: { $0.orderedAt.dateValue() < $1.orderedAt.dateValue() })
            }
        }
    }
    
    private func fetchNewOrdersIfNeeded() async {
        // Call if an operation might affect the newOrders list and listener isn't enough
        // For example, if an order status is reverted to pending.
        // This is a simplified refresh; the listener should ideally handle most cases.
        let tempListener = orderService.newOrdersListener(restaurantId: restaurantId) { [weak self] result in
            if case .success(let orders) = result { self?.newOrders = orders }
        }
        // Remove this temporary listener after one update or timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { tempListener.remove() }
    }


    func updateOrderItemStatus(order: Order, itemId: String, newStatus: String) async {
        guard let orderId = order.id else {
            self.errorMessage = "Order ID missing for item status update."
            return
        }
        errorMessage = nil
        successMessage = nil

        do {
            try await orderService.updateOrderItemStatus(restaurantId: self.restaurantId, orderId: orderId, itemId: itemId, newStatus: newStatus)
            
            // Update local order's item for immediate UI feedback
            var listToUpdate: UnsafeMutablePointer<[Order]>? = nil
            var orderIndex: Int? = nil

            if let idx = newOrders.firstIndex(where: { $0.id == orderId }) {
                listToUpdate = UnsafeMutablePointer(&newOrders)
                orderIndex = idx
            } else if let idx = activeOrders.firstIndex(where: { $0.id == orderId }) {
                listToUpdate = UnsafeMutablePointer(&activeOrders)
                orderIndex = idx
            }

            if let list = listToUpdate, let ordIdx = orderIndex, let itemIdx = list.pointee[ordIdx].items.firstIndex(where: { $0.id == itemId }) {
                list.pointee[ordIdx].items[itemIdx].status = newStatus
                list.pointee[ordIdx].items[itemIdx].lastUpdatedAt = Timestamp(date:Date())
                list.pointee[ordIdx].lastUpdatedAt = Timestamp(date:Date())
                // Trigger objectWillChange manually if direct array modification doesn't update UI sometimes
                // self.objectWillChange.send()
            }
            successMessage = "Item status updated to \(newStatus.capitalized)."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.successMessage = nil }
        } catch {
            self.errorMessage = (error as? OrderServiceError ?? OrderServiceError.firestoreError(error)).localizedDescription
        }
    }

    // MARK: - Item Modifications
    func addItemToOrder(orderId: String, item: OrderItem) async {
        guard var currentOrder = findOrderLocally(orderId: orderId) else {
            errorMessage = "Order not found to add item."
            return
        }
        
        errorMessage = nil
        successMessage = nil
        
        // Logic to increment quantity if item (by menuItemId or name) already exists
        if let menuItemId = item.menuItemId, !menuItemId.isEmpty,
           let existingItemIndex = currentOrder.items.firstIndex(where: { $0.menuItemId == menuItemId && $0.notes == item.notes && $0.status != AppConfig.OrderStatus.cancelled && $0.status != AppConfig.OrderStatus.removed }) {
            currentOrder.items[existingItemIndex].quantity += item.quantity
            currentOrder.items[existingItemIndex].lastUpdatedAt = Timestamp(date: Date())
        } else {
            var newItem = item
            newItem.createdAt = Timestamp(date:Date()) // Ensure createdAt is set
            newItem.lastUpdatedAt = Timestamp(date:Date())
            currentOrder.items.append(newItem)
        }
        currentOrder.lastUpdatedAt = Timestamp(date: Date())

        do {
            try await orderService.updateOrder(currentOrder)
            updateLocalOrder(currentOrder)
            successMessage = "\(item.name) added to order \(currentOrder.orderNumber)."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.successMessage = nil }
        } catch {
            self.errorMessage = (error as? OrderServiceError ?? OrderServiceError.firestoreError(error)).localizedDescription
        }
    }

    func updateOrderItemQuantity(orderId: String, itemId: String, newQuantity: Int) async {
         guard var currentOrder = findOrderLocally(orderId: orderId),
               let itemIndex = currentOrder.items.firstIndex(where: {$0.id == itemId}) else {
             errorMessage = "Order or item not found for quantity update."
             return
         }
        
        errorMessage = nil
        successMessage = nil

        guard newQuantity > 0 else {
            await removeOrderItem(orderId: orderId, itemId: itemId, softDelete: true)
            return
        }

        currentOrder.items[itemIndex].quantity = newQuantity
        currentOrder.items[itemIndex].lastUpdatedAt = Timestamp(date: Date())
        currentOrder.lastUpdatedAt = Timestamp(date: Date())
        
        do {
            try await orderService.updateOrder(currentOrder)
            updateLocalOrder(currentOrder)
            successMessage = "Item quantity updated."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.successMessage = nil }
        } catch {
            self.errorMessage = (error as? OrderServiceError ?? OrderServiceError.firestoreError(error)).localizedDescription
        }
    }

    func removeOrderItem(orderId: String, itemId: String, softDelete: Bool = true) async {
        guard var currentOrder = findOrderLocally(orderId: orderId),
               let itemIndex = currentOrder.items.firstIndex(where: {$0.id == itemId}) else {
             errorMessage = "Order or item not found for removal."
             return
         }
        errorMessage = nil
        successMessage = nil

        let itemWasAlreadyPersisted = currentOrder.items[itemIndex].status != AppConfig.OrderStatus.pending // Or more robust check
        
        if softDelete && itemWasAlreadyPersisted {
            currentOrder.items[itemIndex].status = AppConfig.OrderStatus.removed
            currentOrder.items[itemIndex].lastUpdatedAt = Timestamp(date: Date())
        } else {
            currentOrder.items.remove(at: itemIndex)
        }
        currentOrder.lastUpdatedAt = Timestamp(date: Date())
        
        do {
            try await orderService.updateOrder(currentOrder)
            updateLocalOrder(currentOrder)
            successMessage = "Item removed from order."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.successMessage = nil }
        } catch {
            self.errorMessage = (error as? OrderServiceError ?? OrderServiceError.firestoreError(error)).localizedDescription
        }
    }

    private func findOrderLocally(orderId: String) -> Order? {
        if let order = newOrders.first(where: {$0.id == orderId}) { return order }
        if let order = activeOrders.first(where: {$0.id == orderId}) { return order }
        return nil
    }

    private func updateLocalOrder(_ order: Order) {
        if let index = newOrders.firstIndex(where: {$0.id == order.id}) { newOrders[index] = order }
        if let index = activeOrders.firstIndex(where: {$0.id == order.id}) { activeOrders[index] = order }
        objectWillChange.send() // Ensure UI updates with nested changes
    }

    // MARK: - Printing
    func printOrderToKitchen(order: Order) async {
        guard let orderId = order.id else {
            self.errorMessage = "Order ID missing, cannot print."
            return
        }
        
        isPrinting = true
        errorMessage = nil
        successMessage = nil

        guard let printData = printFormatter.formatOrderForKitchen(order: order) else {
            self.errorMessage = "Failed to format order for printing."
            isPrinting = false
            return
        }

        do {
            try await printerService.connectAndSendData(data: printData)
            // After successful print, update order status to 'printed'
            // This will also update its lastUpdatedAt and printedAt fields if logic is in service
            try await orderService.updateOrderStatus(
                restaurantId: self.restaurantId,
                orderId: orderId,
                newStatus: AppConfig.OrderStatus.printed
            )
            
            // Update local state
            var printedOrder = order
            printedOrder.status = AppConfig.OrderStatus.printed
            printedOrder.printedAt = Timestamp(date: Date()) // Set printed time
            printedOrder.lastUpdatedAt = Timestamp(date:Date())
            
            updateLocalOrderStatus(orderId: orderId, newStatus: AppConfig.OrderStatus.printed, successful: true)
            
            successMessage = "Order \(order.orderNumber) sent to kitchen printer."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.successMessage = nil }
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? "An unknown printing error occurred."
            print("Printing error: \(error)")
        }
        isPrinting = false
    }

    func printCustomerReceipt(order: Order, isOfficialReceipt: Bool) async {
        isPrinting = true
        errorMessage = nil
        successMessage = nil
        
        printFormatter.setIsReceipt(isReceipt: isOfficialReceipt)
        guard let printData = printFormatter.formatOrderForCustomerReceipt(order: order) else {
            self.errorMessage = "Failed to format receipt for printing."
            isPrinting = false
            return
        }

        do {
            try await printerService.connectAndSendData(data: printData)
            successMessage = "Customer receipt for order \(order.orderNumber) printed."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.successMessage = nil }
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? "Receipt printing error."
        }
        isPrinting = false
    }

    // MARK: - Order Finalization
    func finalizeOrder(order: Order, paymentMethod: String, amountPaid: Double, discountPercentage: Double) async {
        guard let orderId = order.id else {
            self.errorMessage = "Order ID missing, cannot finalize."
            return
        }
        isLoadingActiveOrders = true // Use this or a specific 'isFinalizing' flag
        errorMessage = nil
        successMessage = nil

        var orderToFinalize = order
        orderToFinalize.paymentMethod = paymentMethod
        orderToFinalize.amountPaid = amountPaid
        orderToFinalize.discountPercentage = discountPercentage
        // Recalculate totalAmount within the model if discountPercentage can change at payment time
        // orderToFinalize.totalAmount = orderToFinalize.subtotalAmount - orderToFinalize.discountAmount + orderToFinalize.taxAmount ...

        orderToFinalize.status = AppConfig.OrderStatus.finished
        orderToFinalize.paymentStatus = (amountPaid >= orderToFinalize.totalAmount) ? .paid : .partiallyPaid // Handles underpayment
        orderToFinalize.completedAt = Timestamp(date: Date())
        orderToFinalize.lastUpdatedAt = Timestamp(date: Date())

        do {
            try await orderService.updateOrder(orderToFinalize) // Service updates Firestore
            
            // Update local state: Remove from active orders
            activeOrders.removeAll { $0.id == orderId }
            // Optionally add to a 'completedOrdersToday' list or rely on fetching them separately
            
            successMessage = "Order \(order.orderNumber) finalized and paid."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.successMessage = nil }
            
            // Update table statuses to .available
            do {
                try await tableService.updateMultipleTableStatuses(
                    restaurantId: self.restaurantId,
                    tableIds: orderToFinalize.tableIds,
                    newStatus: .available,
                    currentOrderId: nil
                )
            } catch {
                print("Error updating table status after order finalization: \(error.localizedDescription)")
                self.errorMessage = "Order finalized, but failed to free up tables: \(error.localizedDescription)"
            }

        } catch {
            self.errorMessage = (error as? OrderServiceError ?? OrderServiceError.firestoreError(error)).localizedDescription
        }
        isLoadingActiveOrders = false
    }
    
    // MARK: - Order Cancellation
    func cancelOrder(order: Order) async {
        guard let orderId = order.id else {
            self.errorMessage = "Order ID missing, cannot cancel."
            return
        }
        isLoadingActiveOrders = true // Or a specific 'isCancelling' flag
        errorMessage = nil
        successMessage = nil

        do {
            // 1. Update order status to cancelled
            try await orderService.updateOrderStatus(
                restaurantId: self.restaurantId,
                orderId: orderId,
                newStatus: AppConfig.OrderStatus.cancelled
            )
            
            // 2. Free up associated tables
            try await tableService.updateMultipleTableStatuses(
                restaurantId: self.restaurantId,
                tableIds: order.tableIds,
                newStatus: .available,
                currentOrderId: nil
            )
            
            // 3. Update local activeOrders list
            updateLocalOrderStatus(orderId: orderId, newStatus: AppConfig.OrderStatus.cancelled, successful: true)
            
            successMessage = "Order \(order.orderNumber) has been cancelled and tables freed."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.successMessage = nil }

        } catch {
            self.errorMessage = (error as? OrderServiceError ?? OrderServiceError.firestoreError(error)).localizedDescription
            print("Error cancelling order: \(error.localizedDescription)")
        }
        isLoadingActiveOrders = false
    }

    // MARK: - Notifications
    private func triggerNewOrderNotification(_ order: Order?) {
        guard let order = order else { return }
        
        // Check if app has notification permissions
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("Notification permission not granted.")
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = "🍜 New Order Received!"
            content.body = "Order #\(order.orderNumber) for Table(s): \(order.tableDisplayString)."
            content.sound = UNNotificationSound.default // Or a custom sound
            content.userInfo = ["orderId": order.id ?? ""] // For handling tap

            // Deliver the notification in 1 second.
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: order.id ?? UUID().uuidString, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error adding notification request: \(error.localizedDescription)")
                } else {
                    print("New order notification scheduled for order #\(order.orderNumber).")
                }
            }
        }
    }
}
