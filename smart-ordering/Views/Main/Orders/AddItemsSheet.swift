// Views/Main/Orders/AddItemsSheet.swift
import SwiftUI

struct MenuAddItemsSheet: View {
    let order: Order
    let onComplete: ([OrderItem]) async -> Void
    
    @StateObject private var menuViewModel = MenuViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var selectedItems: [String: OrderItemInput] = [:]
    @State private var searchText = ""
    @State private var selectedCategoryId: String?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    struct OrderItemInput: Identifiable {
        let id: String
        let menuItem: MenuItem
        var quantity: Int
        var notes: String
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                MenuSearchFilterBar(
                    searchText: $searchText,
                    selectedCategoryId: $selectedCategoryId,
                    categories: menuViewModel.categories
                )
                .padding()
                
                // Menu Items List
                if menuViewModel.isLoading {
                    ProgressView("Loading menu items...")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(menuViewModel.itemsGroupedForDisplay, id: \.category.id) { section in
                                if !section.items.isEmpty {
                                    MenuItemSection(
                                        category: section.category,
                                        items: section.items,
                                        selectedItems: $selectedItems
                                    )
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                // Selected Items Summary
                if !selectedItems.isEmpty {
                    selectedItemsSummary
                }
            }
            .navigationTitle("Add Items")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Add") { addSelectedItems() }
                    .disabled(selectedItems.isEmpty || isProcessing)
            )
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
        .task {
            await menuViewModel.loadInitialData()
        }
    }

    private var selectedItemsSummary: some View {
        VStack(spacing: 0) {
            Divider()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(selectedItems.values)) { item in
                        MenuSelectedItemChip(
                            item: item,
                            onDelete: { selectedItems.removeValue(forKey: item.id) }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            HStack {
                Text("\(selectedItems.count) items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: addSelectedItems) {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Text("Add to Order")
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedItems.isEmpty || isProcessing)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 5, y: -2)
    }
    
    private func addSelectedItems() {
        let orderItems = selectedItems.values.map { input in
            OrderItem(
                menuItem: input.menuItem,
                quantity: input.quantity,
                notes: input.notes.isEmpty ? nil : input.notes
            )
        }
        
        Task {
            isProcessing = true
            await onComplete(orderItems)
            isProcessing = false
            dismiss()
        }
    }
}

// MARK: - Search and Filter Bar
private struct MenuSearchFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedCategoryId: String?
    let categories: [MenuCategory]
    
    var body: some View {
        VStack(spacing: 12) {
            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search menu items...", text: $searchText)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // Categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    MenuCategoryChip(
                        name: "All",
                        isSelected: selectedCategoryId == nil,
                        action: { selectedCategoryId = nil }
                    )
                    
                    ForEach(categories) { category in
                        MenuCategoryChip(
                            name: category.name,
                            isSelected: selectedCategoryId == category.id,
                            action: { selectedCategoryId = category.id }
                        )
                    }
                }
            }
        }
    }
}

private struct MenuCategoryChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// MARK: - Menu Section
private struct MenuItemSection: View {
    let category: MenuCategory
    let items: [MenuItem]
    @Binding var selectedItems: [String: MenuAddItemsSheet.OrderItemInput]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.name)
                .font(.headline)
                .padding(.bottom, 4)
            
            ForEach(items) { item in
                MenuSheetItemRow(
                    menuItem: item,
                    selectedItem: selectedItems[item.id ?? ""],
                    onSelect: { input in
                        if let id = item.id {
                            selectedItems[id] = input
                        }
                    },
                    onDeselect: {
                        if let id = item.id {
                            selectedItems.removeValue(forKey: id)
                        }
                    }
                )
            }
        }
    }
}

private struct MenuSheetItemRow: View {
    let menuItem: MenuItem
    let selectedItem: MenuAddItemsSheet.OrderItemInput?
    let onSelect: (MenuAddItemsSheet.OrderItemInput) -> Void
    let onDeselect: () -> Void
    
    @State private var showingQuantitySheet = false
    
    var body: some View {
        Button(action: { showingQuantitySheet = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(menuItem.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    if let nameJP = menuItem.nameJP {
                        Text(nameJP)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let selectedItem = selectedItem {
                    HStack {
                        Text("\(selectedItem.quantity)x")
                            .fontWeight(.medium)
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .foregroundColor(.blue)
                }
                
                Text("¥\(menuItem.price, specifier: "%.0f")")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(selectedItem != nil ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingQuantitySheet) {
            MenuQuantityInputSheet(
                menuItem: menuItem,
                initialQuantity: selectedItem?.quantity ?? 1,
                initialNotes: selectedItem?.notes ?? "",
                onComplete: { quantity, notes in
                    if quantity > 0 {
                        onSelect(MenuAddItemsSheet.OrderItemInput(
                            id: menuItem.id ?? UUID().uuidString,
                            menuItem: menuItem,
                            quantity: quantity,
                            notes: notes
                        ))
                    } else {
                        onDeselect()
                    }
                }
            )
        }
    }
}

private struct MenuQuantityInputSheet: View {
    let menuItem: MenuItem
    let initialQuantity: Int
    let initialNotes: String
    let onComplete: (Int, String) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var quantity: Int
    @State private var notes: String
    
    init(menuItem: MenuItem, initialQuantity: Int, initialNotes: String, onComplete: @escaping (Int, String) -> Void) {
        self.menuItem = menuItem
        self.initialQuantity = initialQuantity
        self.initialNotes = initialNotes
        self.onComplete = onComplete
        _quantity = State(initialValue: initialQuantity)
        _notes = State(initialValue: initialNotes)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item")) {
                    Text(menuItem.name)
                    if let nameJP = menuItem.nameJP {
                        Text(nameJP)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Quantity")) {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 0...99)
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextField("Add special instructions...", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle("Add to Order")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Done") {
                    onComplete(quantity, notes)
                    dismiss()
                }
            )
        }
    }
}

private struct MenuSelectedItemChip: View {
    let item: MenuAddItemsSheet.OrderItemInput
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(item.quantity)x")
                .fontWeight(.medium)
            
            Text(item.menuItem.name)
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}
