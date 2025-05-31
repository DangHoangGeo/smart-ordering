//
//  CreateManualOrderView.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/31.
//
// Views/Main/Orders/CreateManualOrderView.swift
import SwiftUI

struct CreateManualOrderView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var ordersViewModel: OrdersViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var appSettings: AppSettings // Assuming AppSettings provides restaurantId or other config

    @State private var numberOfGuests: Int = 1
    @State private var orderNotes: String = ""
    
    // For future visual table selection
    @State private var showingTableSelectionSheet = false
    @State private var selectedTableObjects: [Table] = []

    @State private var errorMessage: String?
    
    // Completion handler to pass back the created order
    var onOrderCreated: ((Order) -> Void)?


    var body: some View {
        NavigationView {
            Form {
                Section("Order Details") {
                    Button(action: { showingTableSelectionSheet = true }) {
                        HStack {
                            Text(selectedTableObjects.isEmpty ? "Select Tables" : "Tables: \(selectedTableObjects.map(\.code).joined(separator: ", "))")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                    .foregroundColor(.primary)

                    Stepper("Guests: \(numberOfGuests)", value: $numberOfGuests, in: 1...50) // Increased max guests
                    
                    VStack(alignment: .leading) {
                        Text("Order Notes (optional):")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextEditor(text: $orderNotes)
                            .frame(height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                            )
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Section {
                    Button(action: validateAndCreateOrder) {
                        HStack {
                            Spacer()
                            if ordersViewModel.isLoadingActiveOrders {
                                ProgressView()
                            } else {
                                Text("Create Order & Add Items")
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(ordersViewModel.isLoadingActiveOrders || selectedTableObjects.isEmpty)
                }
            }
            .navigationTitle("New Manual Order")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingTableSelectionSheet) {
                TableSelectionSheet(selectedTables: Binding(
                    get: { Set(selectedTableObjects) },
                    set: { selectedTableObjects = Array($0) }
                ))
            }
            .onTapGesture { // Dismiss keyboard on tap outside
                 hideKeyboard()
            }
        }
    }

    private func validateAndCreateOrder() {
        hideKeyboard()
        errorMessage = nil
        
        guard !selectedTableObjects.isEmpty else {
            errorMessage = "Please select at least one table."
            return
        }
        
        let tableIdsToUse = selectedTableObjects.compactMap { $0.id }
        
        let isTakeoutOrder = selectedTableObjects.contains { $0.code.localizedCaseInsensitiveCompare(AppConfig.shared.restaurantDetails.takeoutTableCode) == .orderedSame }
        if isTakeoutOrder && selectedTableObjects.count > 1 {
            errorMessage = "Takeout order cannot be combined with other tables. Please select only '\(AppConfig.shared.restaurantDetails.takeoutTableCode)'."
            return
        }
        let finalTableIds = isTakeoutOrder ? [AppConfig.shared.restaurantDetails.takeoutTableCode] : tableIdsToUse


        // TODO: Add validation if non-takeout table codes actually exist using TableService (once Table module is built)

        Task {
            // Pass orderNotes to the view model if the model/service supports it.
            // For now, assuming createManualOrder can take notes or we add it later.
            if let newOrder = await ordersViewModel.createManualOrder(
                tableIds: finalTableIds,
                numberOfGuests: numberOfGuests,
                // notes: orderNotes, // Assuming createManualOrder will be updated for this
                createdByStaffId: userViewModel.appUser?.id ?? "unknown_staff"
            ) {
                print("New manual order created: \(newOrder.orderNumber)")
                onOrderCreated?(newOrder) // Call completion handler
                dismiss()
            } else {
                // ordersViewModel.errorMessage should be set by the createManualOrder function on failure
                self.errorMessage = ordersViewModel.errorMessage ?? "An unknown error occurred while creating the order."
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
