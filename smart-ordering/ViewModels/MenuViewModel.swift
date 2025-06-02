//
//  MenuViewModel.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/26.
//

import SwiftUI
import Combine
import FirebaseFirestore // For Timestamp

@MainActor
class MenuViewModel: ObservableObject {
    @Published var restaurantId: String = AppConfig.shared.defaultRestaurantId
    @Published var categories: [MenuCategory] = []
    @Published var menuItems: [MenuItem] = [] // All items for the current restaurant
    @Published var itemsByCategory: [String: [MenuItem]] = [:] // Grouped by categoryID

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // For search and filter
    @Published var searchText: String = ""
    @Published var selectedCategoryIdFilter: String? = nil // nil means "All"

    private let menuService = MenuService.shared
    //private var restaurantId: String // Current restaurant ID

    init(restaurantId: String = AppConfig.shared.defaultRestaurantId) {
        self.restaurantId = restaurantId
        // Initial data load can be triggered here or from the view's .onAppear
    }

    func loadInitialData() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        async let categoriesFetch: () = fetchCategories()
        async let menuItemsFetch: () = fetchAllMenuItems()
        
        _ = await [categoriesFetch, menuItemsFetch] // Wait for both
        
        isLoading = false
    }

    func fetchCategories() async {
        do {
            self.categories = try await menuService.fetchCategories(restaurantId: restaurantId)
            if self.categories.isEmpty {
                 // Optionally add a default "Uncategorized" or prompt user to add categories
                print("No categories found for restaurant \(restaurantId). Consider adding some.")
            }
        } catch {
            self.errorMessage = (error as? MenuServiceError ?? MenuServiceError.firestoreError(error)).localizedDescription
        }
    }

    func fetchAllMenuItems() async {
        do {
            let allItems = try await menuService.fetchAllMenuItems(restaurantId: restaurantId)
            self.menuItems = allItems
            groupItemsByCategory()
        } catch {
            self.errorMessage = (error as? MenuServiceError ?? MenuServiceError.firestoreError(error)).localizedDescription
        }
    }

    private func groupItemsByCategory() {
        itemsByCategory = Dictionary(grouping: menuItems, by: { $0.categoryId })
        // Ensure categories without items are still present if needed for UI
        for category in categories {
            if itemsByCategory[category.id ?? ""] == nil {
                itemsByCategory[category.id ?? ""] = []
            }
        }
    }

    var filteredAndSortedItems: [MenuItem] {
        let filteredBySearch = menuItems.filter { item in
            searchText.isEmpty ||
            item.name.localizedCaseInsensitiveContains(searchText) ||
            (item.nameJP?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (item.code?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (item.tags?.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) ?? false)
        }

        if let categoryIdFilter = selectedCategoryIdFilter {
            return filteredBySearch.filter { $0.categoryId == categoryIdFilter }
                                   .sorted(by: { $0.displayOrder < $1.displayOrder })
        }
        return filteredBySearch // If no category filter, or already grouped, this might not be needed directly by List view
    }
    
    // Grouped items for display in sections
    var itemsGroupedForDisplay: [(category: MenuCategory, items: [MenuItem])] {
        var result: [(MenuCategory, [MenuItem])] = []
        
        let currentCategories = categories.sorted() // Ensure categories are sorted by their displayOrder

        for category in currentCategories {
            guard let categoryId = category.id else { continue }
            
            let itemsInThisCategory = menuItems.filter { item in
                item.categoryId == categoryId &&
                (searchText.isEmpty ||
                 item.name.localizedCaseInsensitiveContains(searchText) ||
                 (item.nameJP?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                 (item.code?.localizedCaseInsensitiveContains(searchText) ?? false))
            }.sorted(by: { $0.displayOrder < $1.displayOrder })
            
            // If a category filter is active, only include that category
            if let categoryIdFilter = selectedCategoryIdFilter {
                if categoryId == categoryIdFilter {
                    result.append((category, itemsInThisCategory))
                }
            } else { // No category filter, include all categories that have matching search items (or all if no search)
                if !itemsInThisCategory.isEmpty || searchText.isEmpty { // Show category if it has items or if no search
                     result.append((category, itemsInThisCategory))
                }
            }
        }
        return result
    }


    // MARK: - CRUD Operations for Menu Items
    func saveMenuItem(_ menuItem: MenuItem, imageData: Data?) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            _ = try await menuService.saveMenuItem(menuItem, restaurantId: restaurantId, imageData: imageData)
            // Refetch or update local list
            await fetchAllMenuItems() // Simplest way to refresh, or smarter update
            successMessage = menuItem.id == nil ? "Menu item added successfully." : "Menu item updated successfully."
        } catch {
            self.errorMessage = (error as? MenuServiceError ?? MenuServiceError.firestoreError(error)).localizedDescription
        }
        isLoading = false
    }

    func deleteMenuItem(_ menuItem: MenuItem) async {
        guard let itemId = menuItem.id else {
            errorMessage = "Cannot delete item without an ID."
            return
        }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            try await menuService.deleteMenuItem(restaurantId: restaurantId, itemId: itemId, imageUrl: menuItem.imageUrl)
            menuItems.removeAll { $0.id == itemId }
            groupItemsByCategory()
            successMessage = "Menu item deleted."
        } catch {
            self.errorMessage = (error as? MenuServiceError ?? MenuServiceError.firestoreError(error)).localizedDescription
        }
        isLoading = false
    }
    
    func toggleItemAvailability(_ menuItem: MenuItem) async {
        var updatedItem = menuItem
        updatedItem.isAvailable.toggle()
        // No image data needed for just toggling availability
        await saveMenuItem(updatedItem, imageData: nil)
    }

    // MARK: - CRUD for Categories (Example)
    func addCategory(name: String, nameJP: String? = nil, displayOrder: Int) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        let newCategory = MenuCategory(restaurantId: self.restaurantId, name: name, nameJP: nameJP, displayOrder: displayOrder)
        do {
            _ = try await menuService.addCategory(newCategory, restaurantId: self.restaurantId)
            await fetchCategories() // Refresh categories list
            successMessage = "Category '\(name)' added."
        } catch {
             self.errorMessage = (error as? MenuServiceError ?? MenuServiceError.firestoreError(error)).localizedDescription
        }
        isLoading = false
    }
    
    func updateCategory(_ category: MenuCategory) async {
        // Similar to saveMenuItem
        isLoading = true; errorMessage = nil; successMessage = nil
        do {
            try await menuService.updateCategory(category, restaurantId: self.restaurantId)
            await fetchCategories()
            successMessage = "Category '\(category.name)' updated."
        } catch {
            self.errorMessage = (error as? MenuServiceError ?? MenuServiceError.firestoreError(error)).localizedDescription
        }
        isLoading = false
    }
    
    func deleteCategory(_ category: MenuCategory) async {
        guard let categoryId = category.id else {
            errorMessage = "Cannot delete category without an ID."
            return
        }
        isLoading = true; errorMessage = nil; successMessage = nil
        do {
            try await menuService.deleteCategory(restaurantId: self.restaurantId, categoryId: categoryId)
            categories.removeAll { $0.id == categoryId }
            // Also remove/update items from the deleted category if necessary
            await fetchAllMenuItems() // To regroup items
            successMessage = "Category '\(category.name)' deleted."
        } catch {
            self.errorMessage = (error as? MenuServiceError ?? MenuServiceError.firestoreError(error)).localizedDescription
        }
        isLoading = false
    }
}
