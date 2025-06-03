import SwiftUI

enum SelectionContext {
    case newOrder(restaurantId: String, onComplete: ([MenuItem: Int]) -> Void)
    case existingOrder(order: Order)
}

struct ItemSelectionSheetView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var menuViewModel: MenuViewModel
    @State private var searchText = ""
    @State private var selectedCategory: MenuCategory?
    @State private var selectedItems: [MenuItem: Int] = [:]
    @State private var hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    let context: SelectionContext

    init(context: SelectionContext) {
        self.context = context
        switch context {
        case .newOrder(let restaurantId, _):
            self._menuViewModel = StateObject(wrappedValue: MenuViewModel(restaurantId: restaurantId))
        case .existingOrder(let order):
            self._menuViewModel = StateObject(wrappedValue: MenuViewModel(restaurantId: order.restaurantId))
        }
    }
    
    private var filteredItems: [MenuItem] {
        menuViewModel.menuItems.filter { item in
            let matchesSearch = searchText.isEmpty || 
                item.name.localizedCaseInsensitiveContains(searchText) ||
                (item.nameJP?.localizedCaseInsensitiveContains(searchText) ?? false)
            let matchesCategory = selectedCategory == nil || item.categoryId == selectedCategory?.id
            return matchesSearch && matchesCategory
        }
    }
    
    private var navigationTitle: String {
        switch context {
        case .newOrder:
            return "Add Items"
        case .existingOrder:
            return "Add Items to Order"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                VStack(spacing: 12) {
                    // Search Field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppConfig.Colors.secondaryText)
                        TextField("Search menu items...", text: $searchText)
                            .font(.body)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppConfig.Colors.secondaryText)
                            }
                        }
                    }
                    .padding(10)
                    .background(AppConfig.Colors.secondaryBackground)
                    .cornerRadius(10)
                    
                    // Category Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            CategoryPill(
                                name: "All",
                                isSelected: selectedCategory == nil,
                                action: {
                                    hapticFeedback.impactOccurred()
                                    selectedCategory = nil
                                }
                            )
                            
                            ForEach(menuViewModel.categories) { category in
                                CategoryPill(
                                    name: category.name,
                                    isSelected: selectedCategory?.id == category.id,
                                    action: {
                                        hapticFeedback.impactOccurred()
                                        selectedCategory = category
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding()
                .background(AppConfig.Colors.background)
                
                if menuViewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredItems.isEmpty {
                    EmptyStateView(
                        searchText: searchText,
                        section: selectedCategory?.name,
                        iconName: "fork.knife",
                        message: "No menu items available"
                    )
                } else {
                    // Menu Items List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredItems) { item in
                                MenuItemRow(
                                    item: item,
                                    quantity: selectedItems[item],
                                    onSelect: {
                                        hapticFeedback.impactOccurred()
                                        if let currentQty = selectedItems[item] {
                                            selectedItems[item] = currentQty + 1
                                        } else {
                                            selectedItems[item] = 1
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
                
                // Selected Items Summary
                if !selectedItems.isEmpty {
                    VStack(spacing: 12) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(selectedItems.keys), id: \.id) { item in
                                    HStack(spacing: 6) {
                                        Text("\(selectedItems[item] ?? 0)×")
                                            .fontWeight(.medium)
                                        Text(item.name)
                                        Button(action: {
                                            hapticFeedback.impactOccurred()
                                            selectedItems.removeValue(forKey: item)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(AppConfig.Colors.secondaryBackground)
                                    .cornerRadius(16)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Button(action: performAction) {
                            Text("Add \(selectedItems.values.reduce(0, +)) Items")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppConfig.Colors.primary)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .background(AppConfig.Colors.background)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            await menuViewModel.loadInitialData()
            hapticFeedback.prepare()
        }
    }
    
    private func performAction() {
        switch context {
        case .newOrder(_, let onComplete):
            onComplete(selectedItems)
        case .existingOrder(let order):
            for (menuItem, quantity) in selectedItems {
                let newOrderItem = OrderItem(
                    menuItem: menuItem,
                    quantity: quantity
                )
                order.items.append(newOrderItem)
            }
        }
        dismiss()
    }
}

