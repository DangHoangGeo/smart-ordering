import SwiftUI

// MARK: - TableStatus Color Extension
extension TableStatus {
    var color: Color {
        switch self {
        case .available: return .green
        case .occupied: return .red
        case .reserved: return .orange
        case .needsCleaning: return .yellow
        case .outOfService: return .gray
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .available: return Color.green.opacity(0.2)
        case .occupied: return Color.red.opacity(0.2)
        case .reserved: return Color.orange.opacity(0.2)
        case .needsCleaning: return Color.yellow.opacity(0.2)
        case .outOfService: return Color.gray.opacity(0.2)
        }
    }
}

// MARK: - TablesListView
struct TablesListView: View {
    @StateObject private var tablesViewModel = TablesViewModel(restaurantId: AppConfig.shared.defaultRestaurantId)
    @State private var showingAddTableSheet = false

    let columns = [
        GridItem(.adaptive(minimum: 100))
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
                    Text("No tables found.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(tablesViewModel.tables.sorted(), id: \.id) { table in
                            TableTileView(table: table)
                                .onTapGesture {
                                    // Future: Navigate to table details or quick actions
                                    print("Tapped on table: \(table.code)")
                                }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Tables")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTableSheet = true
                    } label: {
                        Label("Add Table", systemImage: "plus.circle.fill")
                    }
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
