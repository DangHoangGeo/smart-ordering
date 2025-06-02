// Services/OrderService.swift
import Foundation
import FirebaseFirestore
import FirebaseStorage

enum OrderServiceError: Error, LocalizedError {
    case firestoreError(Error)
    case decodingError(Error)
    case orderNotFound
    case invalidOrderData
    case itemNotFoundInOrder
    case invalidOrderStatus
    case printerError(Error)

    var errorDescription: String? {
        switch self {
        case .firestoreError(let err): return "Firestore error: \(err.localizedDescription)"
        case .decodingError(let err): return "Decoding error: \(err.localizedDescription)"
        case .orderNotFound: return "Order not found."
        case .invalidOrderData: return "Invalid order data."
        case .itemNotFoundInOrder: return "Item not found within the order."
        case .invalidOrderStatus: return "Invalid order status."
        case .printerError(let err): return "Printer error: \(err.localizedDescription)"
        }
    }
}

class OrderService {
    static let shared = OrderService()
    private let db = Firestore.firestore()
    
    private func ordersCollectionRef(restaurantId: String) -> CollectionReference {
        db.collection(FirestorePaths.ordersCollection(restaurantId))
    }
    
    private func orderDocumentRef(restaurantId: String, orderId: String) -> DocumentReference {
        ordersCollectionRef(restaurantId: restaurantId).document(orderId)
    }

    // MARK: - Order Listeners
    
    // Listen for new orders (initial status: pending)
    func newOrdersListener(restaurantId: String, completion: @escaping (Result<[Order], OrderServiceError>) -> Void) -> ListenerRegistration {
        let query = ordersCollectionRef(restaurantId: restaurantId)
            .whereField("status", isEqualTo: AppConfig.OrderStatus.pending)
            .order(by: "orderedAt", descending: true)

        return query.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(.firestoreError(error)))
                return
            }
            
            guard let documents = querySnapshot?.documents else {
                completion(.success([]))
                return
            }

            let orders = documents.compactMap { document -> Order? in
                do {
                    return try document.data(as: Order.self)
                } catch {
                    print("Error decoding order: \(error) for document \(document.documentID)")
                    return nil
                }
            }
            completion(.success(orders))
        }
    }
    
    // Listen for active orders (printed, preparing, ready)
    func activeOrdersListener(restaurantId: String, completion: @escaping (Result<[Order], OrderServiceError>) -> Void) -> ListenerRegistration {
        let activeStatuses = [
            AppConfig.OrderStatus.printed,
            AppConfig.OrderStatus.preparing,
            AppConfig.OrderStatus.readyForDelivery
        ]
        
        let query = ordersCollectionRef(restaurantId: restaurantId)
            .whereField("status", in: activeStatuses)
            .order(by: "orderedAt", descending: false)

        return query.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(.firestoreError(error)))
                return
            }
            
            guard let documents = querySnapshot?.documents else {
                completion(.success([]))
                return
            }

            let orders = documents.compactMap { document -> Order? in
                do {
                    return try document.data(as: Order.self)
                } catch {
                    print("Error decoding order: \(error) for document \(document.documentID)")
                    return nil
                }
            }
            completion(.success(orders))
        }
    }
    
    func fetchActiveOrders(restaurantId: String) async throws -> [Order] { // Ensured this exists and is public (default internal)
        let activeStatuses = [
            AppConfig.OrderStatus.pending,
            AppConfig.OrderStatus.printed,
            AppConfig.OrderStatus.preparing,
            AppConfig.OrderStatus.readyForDelivery,
            AppConfig.OrderStatus.delivered
        ]
        
        guard activeStatuses.count <= 30 else {
             throw OrderServiceError.firestoreError(NSError(domain: "OrderService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Too many statuses for 'in' query."]))
        }

        do {
            let snapshot = try await ordersCollectionRef(restaurantId: restaurantId)
                .whereField("status", in: activeStatuses)
                .order(by: "orderedAt", descending: false)
                .getDocuments()
            
            return snapshot.documents.compactMap { document -> Order? in
                do {
                    return try document.data(as: Order.self)
                } catch {
                     print("Error decoding active order: \(error) for document \(document.documentID)")
                    return nil
                }
            }
        } catch {
            throw OrderServiceError.firestoreError(error)
        }
    }

    // MARK: - Order Operations
    
    // Fetch a single order by ID
    func fetchOrder(restaurantId: String, orderId: String) async throws -> Order {
        do {
            let document = try await orderDocumentRef(restaurantId: restaurantId, orderId: orderId).getDocument()
            if let order = try? document.data(as: Order.self) {
                return order
            }
            throw OrderServiceError.orderNotFound
        } catch {
            throw OrderServiceError.firestoreError(error)
        }
    }

    // Create a new order
    func createOrder(_ order: Order) async throws -> String {
        let orderToSave = order
        orderToSave.orderedAt = Timestamp(date: Date())
        orderToSave.lastUpdatedAt = Timestamp(date: Date())
        
        // Generate orderNumber if not provided
        if orderToSave.orderNumber.isEmpty {
            orderToSave.orderNumber = await generateOrderNumber(restaurantId: order.restaurantId)
        }

        do {
            let ref = try ordersCollectionRef(restaurantId: order.restaurantId).addDocument(from: orderToSave)
            return ref.documentID
        } catch {
            throw OrderServiceError.firestoreError(error)
        }
    }
    
    func updateOrder(_ order: Order) async throws {
        guard let orderId = order.id else { throw OrderServiceError.orderNotFound }
        let orderToSave = order // Make a mutable copy
        orderToSave.lastUpdatedAt = Timestamp(date: Date()) // Ensure lastUpdatedAt is current
        
        do {
            // Use setData(from:merge:) to update the entire document or specific fields.
            // If 'order' contains all fields, merge:false can be used.
            // merge:true is safer if 'order' might be a partial representation.
            try orderDocumentRef(restaurantId: order.restaurantId, orderId: orderId).setData(from: orderToSave, merge: true)
        } catch {
            throw OrderServiceError.firestoreError(error)
        }
    }

    // Update order status with transaction
    func updateOrderStatus(restaurantId: String, orderId: String, newStatus: String) async throws {
        let orderRef = orderDocumentRef(restaurantId: restaurantId, orderId: orderId)
        
        try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let orderSnapshot: DocumentSnapshot
            do {
                orderSnapshot = try transaction.getDocument(orderRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let order = try? orderSnapshot.data(as: Order.self) else {
                let error = NSError(domain: "OrderService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Order not found"])
                errorPointer?.pointee = error
                return nil
            }
            
            order.status = newStatus
            order.lastUpdatedAt = Timestamp(date: Date())
            
            if newStatus == AppConfig.OrderStatus.printed {
                order.printedAt = Timestamp(date: Date())
            } else if newStatus == AppConfig.OrderStatus.finished {
                order.completedAt = Timestamp(date: Date())
            }
            
            do {
                try transaction.setData(from: order, forDocument: orderRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            
            return nil
        }
    }

    // Update order item status
    func updateOrderItemStatus(restaurantId: String, orderId: String, itemId: String, newStatus: String) async throws {
        let orderRef = orderDocumentRef(restaurantId: restaurantId, orderId: orderId)
        
        try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let orderSnapshot: DocumentSnapshot
            do {
                orderSnapshot = try transaction.getDocument(orderRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let order = try? orderSnapshot.data(as: Order.self) else {
                let error = NSError(domain: "OrderService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Order not found"])
                errorPointer?.pointee = error
                return nil
            }
            
            guard let itemIndex = order.items.firstIndex(where: { $0.id == itemId }) else {
                let error = NSError(domain: "OrderService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Item not found within the order"])
                errorPointer?.pointee = error
                return nil
            }
            
            order.items[itemIndex].status = newStatus
            order.items[itemIndex].lastUpdatedAt = Timestamp(date: Date())
            order.lastUpdatedAt = Timestamp(date: Date())
            
            order.status = self.calculateOrderStatus(items: order.items)
            
            do {
                try transaction.setData(from: order, forDocument: orderRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            
            return nil
        }
    }

    // Add items to an existing order
    func addItemsToOrder(restaurantId: String, orderId: String, items: [OrderItem]) async throws {
        let orderRef = orderDocumentRef(restaurantId: restaurantId, orderId: orderId)
        
        try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let orderSnapshot: DocumentSnapshot
            do {
                orderSnapshot = try transaction.getDocument(orderRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let order = try? orderSnapshot.data(as: Order.self) else {
                let error = NSError(domain: "OrderService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Order not found"])
                errorPointer?.pointee = error
                return nil
            }
            
            order.items.append(contentsOf: items)
            order.lastUpdatedAt = Timestamp(date: Date())
            
            do {
                try transaction.setData(from: order, forDocument: orderRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            
            return nil
        }
    }

    // Update payment status and record payment
    func updatePaymentStatus(restaurantId: String, orderId: String, newStatus: PaymentStatus, amountPaid: Double, paymentMethod: String) async throws {
        let orderRef = orderDocumentRef(restaurantId: restaurantId, orderId: orderId)
        
        try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let orderSnapshot: DocumentSnapshot
            do {
                orderSnapshot = try transaction.getDocument(orderRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let order = try? orderSnapshot.data(as: Order.self) else {
                let error = NSError(domain: "OrderService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Order not found"])
                errorPointer?.pointee = error
                return nil
            }
            
            order.paymentStatus = newStatus
            order.amountPaid = amountPaid
            order.paymentMethod = paymentMethod
            order.lastUpdatedAt = Timestamp(date: Date())
            
            if newStatus == .paid {
                order.status = AppConfig.OrderStatus.finished
                order.completedAt = Timestamp(date: Date())
            }
            
            do {
                try transaction.setData(from: order, forDocument: orderRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            
            return nil
        }
    }

    // MARK: - Helper Functions
    
    func calculateOrderStatus(items: [OrderItem]) -> String {
        let activeStatuses = items.filter { 
            $0.status != AppConfig.OrderStatus.cancelled && 
            $0.status != AppConfig.OrderStatus.removed 
        }.map { $0.status }
        
        if activeStatuses.isEmpty {
            return AppConfig.OrderStatus.cancelled
        }
        
        if activeStatuses.allSatisfy({ $0 == AppConfig.OrderStatus.delivered }) {
            return AppConfig.OrderStatus.delivered
        }
        
        if activeStatuses.allSatisfy({ $0 == AppConfig.OrderStatus.readyForDelivery }) {
            return AppConfig.OrderStatus.readyForDelivery
        }
        
        if activeStatuses.contains(AppConfig.OrderStatus.preparing) {
            return AppConfig.OrderStatus.preparing
        }
        
        if activeStatuses.allSatisfy({ $0 == AppConfig.OrderStatus.printed }) {
            return AppConfig.OrderStatus.printed
        }
        
        return AppConfig.OrderStatus.pending
    }

    func generateOrderNumber(restaurantId: String) async -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: Date())
        
        let counterRef = db.collection("\(FirestorePaths.restaurantBase(restaurantId: restaurantId))/counters")
                          .document("dailyOrderCounter_\(dateString)")
        
        do {
            let newCount = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
                let doc: DocumentSnapshot
                do {
                    doc = try transaction.getDocument(counterRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                var count = 1
                if doc.exists, let data = doc.data(), let currentCount = data["count"] as? Int {
                    count = currentCount + 1
                }
                
                transaction.setData([
                    "count": count,
                    "lastUpdatedAt": Timestamp(date: Date())
                ], forDocument: counterRef)
                
                return count
            }) as? Int ?? 1
            
            return "\(dateString)-\(String(format: "%04d", newCount))"
        } catch {
            print("Error generating order number: \(error). Falling back to UUID.")
            return "ORD-\(UUID().uuidString.prefix(8))"
        }
    }
}
