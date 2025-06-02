import SwiftUI

struct PaymentSheetView: View {
    @Binding var order: Order
    @ObservedObject var ordersViewModel: OrdersViewModel
    @Environment(\.dismiss) var dismiss
    @State private var hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    @State private var selectedPaymentMethod: String = AppConfig.PaymentMethods.cash
    @State private var amountTenderedString: String = ""
    @State private var discountPercentString: String = "0"
    
    let paymentMethods = [AppConfig.PaymentMethods.cash, AppConfig.PaymentMethods.payPay, AppConfig.PaymentMethods.creditCard]
    
    private var currentDiscountPercentage: Double { Double(discountPercentString) ?? order.discountPercentage }
    private var subtotalAfterItemDiscounts: Double { order.subtotalAmount }
    private var orderDiscountAmount: Double { (subtotalAfterItemDiscounts * currentDiscountPercentage) / 100.0 }
    private var finalTotal: Double { subtotalAfterItemDiscounts - orderDiscountAmount }
    private var amountTendered: Double? { Double(amountTenderedString) }
    private var changeDue: Double? {
        guard let tendered = amountTendered else { return nil }
        return tendered - finalTotal
    }
    
    var canFinalize: Bool {
        if selectedPaymentMethod == AppConfig.PaymentMethods.cash {
            return amountTendered != nil && amountTendered! >= finalTotal
        }
        return true
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Order Summary") {
                    ForEach(order.items) { item in
                        HStack {
                            Text("\(item.quantity)× \(item.name)")
                            Spacer()
                            Text(formattedPrice(item.unitPrice * Double(item.quantity)))
                        }
                    }
                    
                    HStack { Text("Subtotal:"); Spacer(); Text(formattedPrice(subtotalAfterItemDiscounts)) }
                    
                    HStack {
                        Text("Order Discount (%):")
                        Spacer()
                        TextField("0", text: $discountPercentString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    
                    HStack { Text("Discount Amount:"); Spacer(); Text("-\(formattedPrice(orderDiscountAmount))").foregroundColor(.orange) }
                    HStack { Text("Final Total:"); Spacer(); Text(formattedPrice(finalTotal)).font(.headline.bold()) }
                }
                
                Section("Payment") {
                    Picker("Payment Method", selection: $selectedPaymentMethod) {
                        ForEach(paymentMethods, id: \.self) { Text($0.capitalized) }
                    }
                    
                    if selectedPaymentMethod == AppConfig.PaymentMethods.cash {
                        HStack {
                            Text("Amount Tendered:")
                            Spacer()
                            TextField("Enter amount", text: $amountTenderedString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack(spacing: 10) {
                            ForEach([1000, 2000, 5000, 10000], id: \.self) { amount in
                                Button("¥\(amount)") {
                                    amountTenderedString = String(amount)
                                }
                                .buttonStyle(.bordered)
                                .fontWeight(.medium)
                            }
                            Button("Exact") {
                                amountTenderedString = String(format: "%.0f", finalTotal)
                            }
                            .buttonStyle(.bordered)
                            .fontWeight(.medium)
                        }
                        .padding(.top, 5)
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        if let change = changeDue, change >= 0 {
                            HStack { Text("Change Due:"); Spacer(); Text(formattedPrice(change)).font(.headline).foregroundColor(.green) }
                        } else if amountTendered != nil && amountTendered! < finalTotal {
                            Text("Amount tendered is less than total.").foregroundColor(.red).font(.caption).frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
                
                Section {
                    Button("Finalize & Pay") {
                        hapticFeedback.impactOccurred()
                        Task {
                            await ordersViewModel.finalizeOrder(
                                order: order,
                                paymentMethod: selectedPaymentMethod,
                                amountPaid: selectedPaymentMethod == AppConfig.PaymentMethods.cash ? (amountTendered ?? finalTotal) : finalTotal,
                                discountPercentage: currentDiscountPercentage
                            )
                            if ordersViewModel.errorMessage == nil {
                                let finalOrderState = order
                                finalOrderState.paymentMethod = selectedPaymentMethod
                                finalOrderState.amountPaid = selectedPaymentMethod == AppConfig.PaymentMethods.cash ? (amountTendered ?? finalTotal) : finalTotal
                                finalOrderState.discountPercentage = currentDiscountPercentage
                                
                                await ordersViewModel.printCustomerReceipt(order: finalOrderState, isOfficialReceipt: true)
                                dismiss()
                            }
                        }
                    }
                    .disabled(!canFinalize || ordersViewModel.isLoadingActiveOrders || ordersViewModel.isPrinting)
                    .frame(maxWidth: .infinity)
                }
                
                if ordersViewModel.isLoadingActiveOrders || ordersViewModel.isPrinting {
                    ProgressView().frame(maxWidth: .infinity)
                }
                if let error = ordersViewModel.errorMessage {
                    Text(error).foregroundColor(.red).frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Complete Payment")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                discountPercentString = String(format: "%.0f", order.discountPercentage)
            }
        }
    }
    
    private func formattedPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "¥\(Int(price))"
    }
}


