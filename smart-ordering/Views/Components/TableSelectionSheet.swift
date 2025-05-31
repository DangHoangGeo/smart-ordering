import SwiftUI

struct TableSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedTables: Set<Table>
    @StateObject private var tablesViewModel = TablesViewModel(restaurantId: "1") // Replace "1" with actual restaurant ID
    
    @State private var internalSelectedTables: Set<Table> // Use an internal state for selection
    
    init(selectedTables: Binding<Set<Table>>) {
        self._selectedTables = selectedTables
        self._internalSelectedTables = State(initialValue: selectedTables.wrappedValue)
    }

    var body: some View {
        NavigationView {
            VStack {
                Text("Select Tables")
                    .font(.largeTitle)
                    .padding()

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 16)], spacing: 16) {
                        ForEach(tablesViewModel.tables) { table in
                            TableTileView(table: table)
                                .onTapGesture {
                                    if table.status == .available {
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
                                .opacity(table.status == .available ? 1.0 : 0.5) // Dim unavailable tables
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

                    Spacer()

                    Button("Done") {
                        selectedTables = internalSelectedTables // Update the binding
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(internalSelectedTables.isEmpty)
                }
                .padding()
            }
            .navigationBarHidden(true) // Hide default navigation bar
            .onAppear {
				Task {
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
