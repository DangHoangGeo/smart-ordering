import SwiftUI

// Note: TableStatus color/style extensions are now expected to be globally available
// or co-located with TableTileView.swift or the TableStatus model definition.
// The local extension previously here has been removed to avoid conflict/duplication.

// MARK: - TablesListView
struct TablesListView: View {
    @StateObject private var tablesViewModel = TablesViewModel(restaurantId: AppConfig.shared.defaultRestaurantId)
    @State private var showingAddTableSheet = false
    @State private var hapticFeedbackLight = UIImpactFeedbackGenerator(style: .light)


    // Adjusted columns for better fit with TableTileView's fixed width of 150
    let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                if tablesViewModel.isLoading {
                    ProgressView("Loading Tables...")
                        .padding()
                } else if let errorMessage = tablesViewModel.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else if tablesViewModel.tables.isEmpty {
                    Text("No tables found. Tap the '+' button to add a new table.")
                        .foregroundColor(.secondary) // Changed to secondary for better empty state appearance
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // Center it
                } else {
                    LazyVGrid(columns: columns, spacing: 16) { // Consistent spacing with columns
                        ForEach(tablesViewModel.tables.sorted(), id: \.id) { table in // Ensure Table conforms to Comparable or sort here
                            TableTileView(table: table)
                                .onTapGesture {
                                    // Future: Navigate to table details or quick actions
                                    print("Tapped on table: \(table.code)")
                                    // Consider showing a context menu or navigating to a detail view.
                                }
                                .accessibilityHint("Tap to view details or actions for table \(table.code)")
                        }
                    }
                    .padding(.horizontal) // Apply horizontal padding to the grid container
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        hapticFeedbackLight.impactOccurred()
                        showingAddTableSheet = true
                    } label: {
                        Label("Add Table", systemImage: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add new table")
                }
            }
            .refreshable {
                await tablesViewModel.fetchTables()
            }
            .onAppear {
                // Fetch tables only if not already loaded or if an error occurred
                if tablesViewModel.tables.isEmpty && tablesViewModel.errorMessage == nil {
                    Task {
                        await tablesViewModel.fetchTables()
                    }
                }
            }
            .sheet(isPresented: $showingAddTableSheet) {
                AddTableView()
                    .environmentObject(tablesViewModel)
            }
        }
    }
}

// MARK: - Preview
struct TablesListView_Previews: PreviewProvider {
    static var previews: some View {
        TablesListView()
    }
}
