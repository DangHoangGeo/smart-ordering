//
//  AddTableView.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/31.
//

import SwiftUI

struct AddTableView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var tablesViewModel: TablesViewModel

    @State private var tableCode: String = ""
    @State private var capacity: String = "" // Use String for TextField, convert to Int for model
    @State private var displayOrder: String = "" // Use String for TextField, convert to Int for model
    @State private var section: String = ""
    @State private var selectedStatus: TableStatus = .available

    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Table Details") {
                    TextField("Table Code (e.g., T10, B5)", text: $tableCode)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)

                    TextField("Capacity", text: $capacity)
                        .keyboardType(.numberPad)

                    TextField("Display Order", text: $displayOrder)
                        .keyboardType(.numberPad)

                    TextField("Section (Optional, e.g., Patio)", text: $section)
                }

                Section("Initial Status") {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(TableStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if tablesViewModel.isLoading {
                    ProgressView("Adding Table...")
                }

                if let errorMessage = tablesViewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Add New Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTable()
                    }
                    .disabled(tablesViewModel.isLoading)
                }
            }
            .alert("Validation Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func saveTable() {
        // Client-side validation
        guard !tableCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Table Code is required."
            showingAlert = true
            return
        }

        guard let capacityInt = Int(capacity), capacityInt > 0 else {
            alertMessage = "Capacity must be a positive number."
            showingAlert = true
            return
        }

        guard let displayOrderInt = Int(displayOrder) else {
            alertMessage = "Display Order must be a number."
            showingAlert = true
            return
        }

        Task {
            await tablesViewModel.addTable(
                code: tableCode.trimmingCharacters(in: .whitespacesAndNewlines),
                capacity: capacityInt,
                displayOrder: displayOrderInt,
                section: section.isEmpty ? nil : section.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            if tablesViewModel.errorMessage == nil {
                dismiss() // Dismiss on successful save
            }
        }
    }
}

struct AddTableView_Previews: PreviewProvider {
    static var previews: some View {
        AddTableView()
            .environmentObject(TablesViewModel(restaurantId: "preview_rest_id")) // Provide a mock TablesViewModel
    }
}
