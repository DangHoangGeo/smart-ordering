import SwiftUI

struct TableSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var tablesViewModel = TablesViewModel(restaurantId: AppConfig.shared.defaultRestaurantId)
    @Binding var selectedTables: Set<Table>
    @State private var searchText = ""
    @State private var section: String?
    @State private var hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    private var sections: [String] {
        Array(Set(tablesViewModel.tables.compactMap { $0.section })).sorted()
    }
    
    private var filteredTables: [Table] {
        tablesViewModel.tables.filter { table in
            let matchesSearch = searchText.isEmpty || 
                table.code.localizedCaseInsensitiveContains(searchText)
            let matchesSection = section == nil || table.section == section
            return matchesSearch && matchesSection &&
            table.status.rawValue != AppConfig.TableStatus.outOfService
        }.sorted()
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
                        TextField("Search tables...", text: $searchText)
                            .font(.body)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                            .foregroundColor(AppConfig.Colors.text)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppConfig.Colors.secondaryText)
                            }
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(10)
                    .background(AppConfig.Colors.secondaryBackground)
                    .cornerRadius(10)
                    
                    // Section Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            CategoryPill(
                                name: "All",
                                isSelected: section == nil,
                                action: {
                                    hapticFeedback.impactOccurred()
                                    section = nil
                                }
                            )
                            
                            ForEach(sections, id: \.self) { sectionName in
                                CategoryPill(
                                    name: sectionName,
                                    isSelected: section == sectionName,
                                    action: {
                                        hapticFeedback.impactOccurred()
                                        section = sectionName
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding()
                .background(AppConfig.Colors.background)
                
                if tablesViewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredTables.isEmpty {
                    EmptyStateView(
                        searchText: searchText,
                        section: section,
                        iconName: "table",
                        message: "No tables available"
                    )
                } else {
                    // Tables Grid
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 150), spacing: 16)
                            ],
                            spacing: 16
                        ) {
                            ForEach(filteredTables) { table in
                                TableTileView(
                                    table: table,
                                    isSelected: selectedTables.contains(where: { $0.id == table.id }),
                                    onTap: {
                                        hapticFeedback.impactOccurred()
                                        toggleTableSelection(table)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Select Tables")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppConfig.Colors.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.headline)
                        .foregroundColor(AppConfig.Colors.primary)
                }
            }
        }
        .task {
            await tablesViewModel.fetchTables()
        }
    }
    
    private func toggleTableSelection(_ table: Table) {
        guard let id = table.id else { return }
        if let existing = selectedTables.first(where: { $0.id == id }) {
            selectedTables.remove(existing)
        } else {
            selectedTables.insert(table)
        }
    }
}

