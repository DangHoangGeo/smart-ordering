import SwiftUI

struct TableSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedTables: Set<Table>
    // Ensure restaurantId is passed correctly or use a shared instance from Environment
    @StateObject private var tablesViewModel = TablesViewModel(restaurantId: AppConfig.shared.defaultRestaurantId)
    
    @State private var internalSelectedTables: Set<Table>
    @State private var hapticFeedbackLight = UIImpactFeedbackGenerator(style: .light)
    @State private var hapticFeedbackMedium = UIImpactFeedbackGenerator(style: .medium)

    init(selectedTables: Binding<Set<Table>>) {
        self._selectedTables = selectedTables
        self._internalSelectedTables = State(initialValue: selectedTables.wrappedValue)
        // Consider passing restaurantId if it's dynamic
        // For now, using default from AppConfig as an example if this sheet is used globally
    }

    var body: some View {
        NavigationView {
            VStack {
                Text("Select Tables")
                    .font(.largeTitle)
                    .padding()
                    .accessibilityAddTraits(.isHeader)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 16)], spacing: 16) {
                        ForEach(tablesViewModel.tables) { table in
                            TableTileView(table: table)
                                .onTapGesture {
                                    if table.status == .available {
                                        hapticFeedbackLight.impactOccurred()
                                        if internalSelectedTables.contains(table) {
                                            internalSelectedTables.remove(table)
                                        } else {
                                            internalSelectedTables.insert(table)
                                        }
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(internalSelectedTables.contains(table) ? Color.accentColor : Color.clear, lineWidth: 3)
                                )
                                .opacity(table.status == .available ? 1.0 : 0.5)
                                .accessibilityElement(children: .combine) // Combine children for row-level actions
                                .accessibilityLabel("Table \(table.code), Capacity \(table.capacity), Status \(table.status.displayName)")
                                .accessibilityHint(table.status == .available ? (internalSelectedTables.contains(table) ? "Tap to deselect table" : "Tap to select table") : "Table is not available for selection")
                                .accessibilityAddTraits(table.status == .available ? (internalSelectedTables.contains(table) ? .isSelected : .isButton) : .isStaticText)
                        }
                    }
                    .padding()
                }

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityLabel("Cancel table selection")

                    Spacer()

                    Button("Done") {
                        hapticFeedbackMedium.impactOccurred()
                        selectedTables = internalSelectedTables
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(internalSelectedTables.isEmpty)
                    .accessibilityLabel("Confirm selected tables")
                }
                .padding()
            }
            .navigationBarHidden(true)
            .onAppear {
				Task {
                    // Ensure restaurantId is correct before fetching
                    // tablesViewModel.restaurantId = ... // if dynamic
					await tablesViewModel.fetchTables()
				}
            }
        }
    }
}

struct TableSelectionSheet_Previews: PreviewProvider {
    @State static var previewSelectedTables: Set<Table> = []
    static var previews: some View {
        TableSelectionSheet(selectedTables: $previewSelectedTables)
    }
}
