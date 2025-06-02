// Views/Main/Orders/OrdersListView.swift
import SwiftUI

struct OrdersListView: View {
    @StateObject private var ordersViewModel = OrdersViewModel()
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var appSettings: AppSettings

    @State private var showingCreateOrderSheet = false
    @State private var orderForAddingItems: Order? = nil // Holds the newly created order
    @State private var showingAddItemsToNewOrderSheet = false // Controls the item addition sheet

    // Toast message states
    @State private var showMessageToast = false
    @State private var toastMessage: String = ""
    @State private var toastType: ToastType = .info // Renamed from OrdersListView.ToastType for clarity
    enum ToastType { case info, success, error }

    // Haptic feedback generator
    @State private var hapticFeedbackMedium = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        List {
            newOrdersSection
            activeOrdersSection
        }
        .listStyle(InsetGroupedListStyle())
        // .navigationTitle("Restaurant Orders") // Title is now set by MainTabView's NavigationView
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                if ordersViewModel.isLoadingNewOrders || ordersViewModel.isLoadingActiveOrders || ordersViewModel.isPrinting {
                    ProgressView().frame(width: 20, height: 20)
                } else {
                    Button {
                        hapticFeedbackMedium.impactOccurred()
                        Task { await ordersViewModel.refreshAllData() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh orders list")
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    hapticFeedbackMedium.impactOccurred()
                    showingCreateOrderSheet = true
                } label: {
                    Label("New Order", systemImage: "plus.circle.fill")
                }
                .accessibilityLabel("Create new order")
            }
        }
        .sheet(isPresented: $showingCreateOrderSheet, onDismiss: {
            // This onDismiss is for the CreateManualOrderView sheet
        }) {
            // Changed: Remove binding argument and use closure initializer
            CreateManualOrderView { createdOrder in
                self.orderForAddingItems = createdOrder
                self.showingAddItemsToNewOrderSheet = true
            }
            .environmentObject(ordersViewModel)
            .environmentObject(userViewModel)
            .environmentObject(appSettings)
        }
        .sheet(isPresented: $showingAddItemsToNewOrderSheet, onDismiss: {
            orderForAddingItems = nil // Clear after the item addition sheet is dismissed
            // Optionally, refresh active orders here if items were added successfully
            // Task { await ordersViewModel.fetchActiveOrders() }
        }) {
            if let order = orderForAddingItems {
                AddItemsToOrderSheet(order: order)
                    .environmentObject(ordersViewModel)
            } else {
                Text("Error: Order context lost. Please try creating the order again.")
                    .padding()
            }
        }
        // Added: when orderForAddingItems is set, trigger the addition sheet
        .onChange(of: orderForAddingItems) {
            if orderForAddingItems != nil {
            showingAddItemsToNewOrderSheet = true
            }
        }
        .overlay(
            toastView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 20)
                .padding(.horizontal)
        )
        .onReceive(ordersViewModel.$errorMessage) { message in
            if let msg = message, !msg.isEmpty {
                self.toastMessage = msg
                self.toastType = .error
                self.showMessageToast = true
                // Clear VM's message so it doesn't reappear on other screens or re-navigating
                DispatchQueue.main.async { ordersViewModel.errorMessage = nil }
            }
        }
        .onReceive(ordersViewModel.$successMessage) { message in
            if let msg = message, !msg.isEmpty {
                self.toastMessage = msg
                self.toastType = .success
                self.showMessageToast = true
                DispatchQueue.main.async { ordersViewModel.successMessage = nil }
            }
        }
        .onAppear {
            // ViewModel's init handles initial load and listener setup.
            // If restaurantId could change dynamically (e.g., via appSettings),
            // you'd need to observe that change and potentially re-initialize
            // ordersViewModel or update its restaurantId and call refreshAllData.
            // For now, assuming restaurantId is stable after viewModel init.
        }
    }

    private var newOrdersSection: some View {
        Section(header: HStack {
            Text("New Web Orders")
            BadgeView(count: ordersViewModel.newOrders.count)
        }
        .font(.headline)) {
            if ordersViewModel.isLoadingNewOrders && ordersViewModel.newOrders.isEmpty {
                ProgressView("Loading new orders...").centeredInList()
            } else if ordersViewModel.newOrders.isEmpty {
                Text("No new web orders at the moment.")
                    .foregroundColor(.secondary).padding(.vertical).centeredInList()
            } else {
                ForEach(ordersViewModel.newOrders) { order in
                    NavigationLink {
                        // Changed: Pass ordersViewModel before order
                        OrderDetailView(ordersViewModel: ordersViewModel, order: order)
                    } label: {
                        OrderRow(order: order, isNew: true)
                    }
                }
            }
        }
    }

    private var activeOrdersSection: some View {
        Section(header: Text("Active Orders (\(ordersViewModel.activeOrders.count))").font(.headline)) {
            if ordersViewModel.isLoadingActiveOrders && ordersViewModel.activeOrders.isEmpty {
                ProgressView("Loading active orders...").centeredInList()
            } else if ordersViewModel.activeOrders.isEmpty {
                Text("No active orders. Tap the '+' button above to create one!")
                    .foregroundColor(.secondary).padding(.vertical).centeredInList()
            } else {
                ForEach(ordersViewModel.activeOrders) { order in
                    NavigationLink {
                        // Changed: Pass ordersViewModel before order
                        OrderDetailView(ordersViewModel: ordersViewModel, order: order)
                    } label: {
                        OrderRow(order: order, isNew: false)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var toastView: some View {
        if showMessageToast {
            Text(toastMessage)
                .padding()
                .background(toastType == .error ? Color.red.opacity(0.9) : (toastType == .success ? Color.green.opacity(0.9) : Color.blue.opacity(0.9)))
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(radius: 5)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { // Auto-dismiss
                        withAnimation {
                            self.showMessageToast = false
                        }
                    }
                }
        } else {
            EmptyView()
        }
    }
}

// MARK: - BadgeView
// (Can be in its own file, but included here for the subtask)

struct BadgeView: View {
    let count: Int
    var backgroundColor: Color = .red
    var textColor: Color = .white

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption.bold())
                .accessibilityLabel("\(count) new items") // Example label
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(backgroundColor)
                .foregroundColor(textColor)
                .clipShape(Capsule())
        } else {
            EmptyView() // Don't show the badge if count is 0
        }
    }
}

// Helper for centering content within List sections (if not already global)
fileprivate extension View {
    func centeredInList() -> some View { // `fileprivate` if only for this file
        HStack {
            Spacer()
            self
            Spacer()
        }
    }
}
