import Foundation
import Combine
import FirebaseFirestore

@MainActor
class TablesViewModel: ObservableObject {
    @Published var tables: [Table] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let restaurantId: String
    private var tablesListener: ListenerRegistration?

    init(restaurantId: String) {
        self.restaurantId = restaurantId
        listenForTableUpdates()
    }

    deinit {
        tablesListener?.remove()
    }

    private func listenForTableUpdates() {
        isLoading = true
        errorMessage = nil
        tablesListener = TableService.shared.tablesListener(restaurantId: restaurantId) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            switch result {
            case .success(let tables):
                self.tables = tables
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                print("Error listening for table updates: \(error.localizedDescription)")
            }
        }
    }

    func fetchTables() async {
        isLoading = true
        errorMessage = nil
        do {
            self.tables = try await TableService.shared.fetchTables(restaurantId: restaurantId)
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error fetching tables: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func updateTableStatus(tableId: String, newStatus: TableStatus, currentOrderId: String? = nil) async {
        isLoading = true
        errorMessage = nil
        do {
            try await TableService.shared.updateTableStatus(restaurantId: restaurantId, tableId: tableId, newStatus: newStatus, currentOrderId: currentOrderId)
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error updating table status: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func updateMultipleTableStatuses(tableIds: [String], newStatus: TableStatus, currentOrderId: String? = nil) async {
        isLoading = true
        errorMessage = nil
        do {
            try await TableService.shared.updateMultipleTableStatuses(restaurantId: restaurantId, tableIds: tableIds, newStatus: newStatus, currentOrderId: currentOrderId)
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error updating multiple table statuses: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func addTable(code: String, capacity: Int, displayOrder: Int, section: String? = nil) async {
        isLoading = true
        errorMessage = nil
        do {
            let newTable = Table(id: UUID().uuidString, restaurantId: restaurantId, code: code, capacity: capacity, status: .available, displayOrder: displayOrder, currentOrderId: nil, section: section)
            try await TableService.shared.addTable(restaurantId: restaurantId,table: newTable)
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error adding table: \(error.localizedDescription)")
        }
        isLoading = false
    }
}
