//
//  PrintFormatter.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/31.
//

import Foundation

class PrintFormatter {
    private let config = AppConfig.shared
    private let printerCmd = AppConfig.PrinterCommands.self
    private let numberFormatter: NumberFormatter

    init() {
        numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.locale = Locale(identifier: "ja_JP") // Assuming Japanese locale for currency
        numberFormatter.currencySymbol = "¥" // If you want to include it explicitly
        numberFormatter.maximumFractionDigits = 0 // For Yen
    }

    private func stringToShiftJISData(_ string: String) -> Data? {
        return string.data(using: .shiftJIS)
    }

    // MARK: - Kitchen Docket
    func formatOrderForKitchen(order: Order) -> Data? {
        var command = Data()
        command.append(Data(printerCmd.initialize)) // Initialize printer

        // --- Header ---
        command.append(Data(printerCmd.alignCenter))
        command.append(Data(printerCmd.boldOn))
        command.append(Data(printerCmd.fontSize24)) // Large font for table number
        if let tableData = stringToShiftJISData("\nBàn (Table): \(order.tableDisplayString)\n") {
            command.append(tableData)
        }
        if let orderNumData = stringToShiftJISData("Order #: \(order.orderNumber)\n") {
             command.append(Data(printerCmd.fontSize12)) // Smaller for order number
             command.append(orderNumData)
        }
        command.append(Data(printerCmd.resetStyles))
        command.append(Data(printerCmd.alignLeft))
        
        let separator = "----------------------------------------\n" // Adjust width based on printer
        if let sepData = stringToShiftJISData(separator) { command.append(sepData) }

        // --- Items ---
        // Group items by category for kitchen (optional, but good for organization)
        let itemsGrouped = Dictionary(grouping: order.items.filter { $0.status != AppConfig.OrderStatus.cancelled && $0.status != AppConfig.OrderStatus.removed }, by: { $0.categoryId ?? "Uncategorized" })
        
        // You might want to fetch category names here if needed, or rely on `item.name`
        for (_, items) in itemsGrouped {
            // Optional: Print category name
            // if let category = menuViewModel.categories.first(where: {$0.id == categoryId}) {
            //    if let catNameData = stringToShiftJISData("\n[\(category.name)]\n") { command.append(catNameData) }
            // }

            for item in items {
                command.append(Data(printerCmd.boldOn)) // Bold for item name
                let itemName = item.namePrint ?? item.name
                if let nameData = stringToShiftJISData("\(itemName)\n") {
                    command.append(nameData)
                }
                command.append(Data(printerCmd.boldOff))

                var itemLine = "  Qty: \(item.quantity)"
                if let notes = item.notes, !notes.isEmpty {
                    itemLine += " (\(notes))"
                }
                itemLine += "\n"
                if let qtyData = stringToShiftJISData(itemLine) {
                    command.append(qtyData)
                }
            }
            if let sepData = stringToShiftJISData("-\n") { command.append(sepData) } // Small separator between item groups
        }
        
        if let sepData = stringToShiftJISData(separator) { command.append(sepData) }

        // --- Footer ---
        command.append(Data(printerCmd.alignLeft))
        let dateTime = DateFormatter()
        dateTime.dateFormat = config.restaurantDetails.defaultDateTimeFormat
        if let timeData = stringToShiftJISData("Printed: \(dateTime.string(from: Date()))\n") {
            command.append(timeData)
        }
        
        command.append(Data(printerCmd.lineFeed)) // Extra line feeds
        command.append(Data(printerCmd.lineFeed))
        command.append(Data(printerCmd.cutPaperPartial)) // Partial cut

        return command
    }

    // MARK: - Customer Receipt
    func formatOrderForCustomerReceipt(order: Order) -> Data? {
        var command = Data()
        command.append(Data(printerCmd.initialize))

        // --- Restaurant Header ---
        command.append(Data(printerCmd.alignCenter))
        command.append(Data(printerCmd.boldOn))
        command.append(Data(printerCmd.fontSize24))
        if let nameData = stringToShiftJISData("\(config.restaurantDetails.name)\n") { command.append(nameData) }
        command.append(Data(printerCmd.resetStyles))
        if let addressData = stringToShiftJISData("\(config.restaurantDetails.address)\n") { command.append(addressData) }
        if !config.restaurantDetails.phone.isEmpty, let phoneData = stringToShiftJISData("Tel: \(config.restaurantDetails.phone)\n") { command.append(phoneData) }
        
        if is_receipt { // From your old code, assuming `is_receipt` is a parameter or state
            if let receiptTitle = stringToShiftJISData("\n領 収 証\n") { // "Receipt" in Japanese
                 command.append(Data(printerCmd.boldOn))
                 command.append(Data(printerCmd.fontSize12)) // Adjust size
                 command.append(receiptTitle)
                 command.append(Data(printerCmd.resetStyles))
            }
        }

        let separator = "----------------------------------------\n"
        if let sepData = stringToShiftJISData(separator) { command.append(sepData) }

        // --- Order Info ---
        command.append(Data(printerCmd.alignLeft))
        if let orderNumData = stringToShiftJISData("Order #: \(order.orderNumber)\n") { command.append(orderNumData) }
        if let tableData = stringToShiftJISData("Table: \(order.tableDisplayString)\n") { command.append(tableData) }
        let dateTime = DateFormatter()
        dateTime.dateFormat = config.restaurantDetails.defaultDateTimeFormat
        if let timeData = stringToShiftJISData("Date: \(dateTime.string(from: order.orderedAt.dateValue()))\n") { command.append(timeData) }
        
        if let sepData = stringToShiftJISData(separator) { command.append(sepData) }
        if let headerLine = stringToShiftJISData("Item             Qty   Price    Total\n") { command.append(headerLine) }
        if let sepData = stringToShiftJISData(separator) { command.append(sepData) }

        // --- Items ---
        for item in order.items.filter({ $0.status != AppConfig.OrderStatus.cancelled && $0.status != AppConfig.OrderStatus.removed }) {
            let itemName = item.namePrint ?? item.name
            let qtyStr = String(item.quantity)
            let priceStr = numberFormatter.string(from: NSNumber(value: item.unitPrice)) ?? ""
            let totalStr = numberFormatter.string(from: NSNumber(value: item.totalPrice)) ?? ""
            
            // Basic fixed-width attempt. For robust alignment, use printer's column settings or more complex padding.
            var line = itemName.padding(toLength: 18, withPad: " ", startingAt: 0) // Max 18 chars for name
            line += qtyStr.padding(toLength: 4, withPad: " ", startingAt: 0)
            line += priceStr.padding(toLength: 8, withPad: " ", startingAt: 0)
            line += totalStr.padding(toLength: 8, withPad: " ", startingAt: 0)
            line += "\n"
            
            if let itemData = stringToShiftJISData(line) { command.append(itemData) }
        }
        if let sepData = stringToShiftJISData(separator) { command.append(sepData) }

        // --- Totals ---
        command.append(Data(printerCmd.alignRight)) // Align totals to the right
        command.append(Data(printerCmd.boldOn))
        if let subTotalData = stringToShiftJISData("Subtotal: \(numberFormatter.string(from: NSNumber(value: order.subtotalAmount)) ?? "")\n") { command.append(subTotalData) }
        if order.discountAmount > 0 {
            if let discData = stringToShiftJISData("Discount (\(String(format: "%.0f%%", order.discountPercentage))): -\(numberFormatter.string(from: NSNumber(value: order.discountAmount)) ?? "")\n") { command.append(discData) }
        }
        // Add Tax, Service Charge if applicable
        // if order.taxAmount > 0 { ... }
        // if order.serviceChargeAmount > 0 { ... }
        
        command.append(Data(printerCmd.fontSize12)) // Slightly larger for final total
        if let totalData = stringToShiftJISData("Total: \(numberFormatter.string(from: NSNumber(value: order.totalAmount)) ?? "")\n") { command.append(totalData) }
        command.append(Data(printerCmd.resetStyles))

        // --- Payment Details ---
        if order.paymentStatus == .paid || order.paymentStatus == .partiallyPaid {
            if let paymentMethod = order.paymentMethod, !paymentMethod.isEmpty {
                 if let methodData = stringToShiftJISData("Paid by: \(paymentMethod.capitalized)\n") { command.append(methodData) }
            }
            if order.amountPaid > 0 {
                 if let paidData = stringToShiftJISData("Amount Paid: \(numberFormatter.string(from: NSNumber(value: order.amountPaid)) ?? "")\n") { command.append(paidData) }
                let changeDue = order.amountPaid - order.totalAmount
                if changeDue > 0 {
                    if let changeData = stringToShiftJISData("Change: \(numberFormatter.string(from: NSNumber(value: changeDue)) ?? "")\n") { command.append(changeData) }
                }
            }
        }
        if let sepData = stringToShiftJISData(separator) { command.append(sepData) }

        // --- Footer Message ---
        command.append(Data(printerCmd.alignCenter))
        if let thankYou = stringToShiftJISData("Thank you for your visit!\nXin cam on!\n") { command.append(thankYou) }
        if !config.restaurantDetails.website.isEmpty {
             if let webData = stringToShiftJISData("\(config.restaurantDetails.website)\n") { command.append(webData) }
        }
        
        command.append(Data(printerCmd.lineFeed))
        command.append(Data(printerCmd.lineFeed))
        command.append(Data(printerCmd.cutPaperFull))

        return command
    }
    
    // Helper for QR code (from your old code, may need printer-specific adjustments)
    // This is highly dependent on the printer's ESC/POS implementation for QR codes.
    // You might need to consult the printer manual.
    func formatQRCodeForPrinting(dataString: String, size: UInt8 = 8) -> Data? {
        guard let contentData = dataString.data(using: .ascii) else { return nil } // QR content usually ASCII/ISO-8859-1
        let contentLength = UInt16(contentData.count)
        
        var qrCommands = Data()
        qrCommands.append(Data(printerCmd.initialize))
        qrCommands.append(Data(printerCmd.alignCenter))

        // Model: QR Code Model 2 (most common)
        qrCommands.append(contentsOf: [0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00])
        // Size: size parameter (e.g., 1 to 16)
        qrCommands.append(contentsOf: [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, size])
        // Error Correction Level: M (0x31) or L (0x30)
        qrCommands.append(contentsOf: [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31])
        
        // Store Data: pL pH, where pL = (contentLength + 3) % 256 and pH = (contentLength + 3) / 256
        let totalLength = contentLength + 3
        let pL = UInt8(totalLength & 0xFF)
        let pH = UInt8((totalLength >> 8) & 0xFF)
        qrCommands.append(contentsOf: [0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30])
        qrCommands.append(contentData)
        
        // Print QR Code
        qrCommands.append(contentsOf: [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30])
        
        qrCommands.append(Data(printerCmd.lineFeed))
        qrCommands.append(Data(printerCmd.lineFeed))
        qrCommands.append(Data(printerCmd.cutPaperPartial))
        
        return qrCommands
    }
    
    // Added state for is_receipt
    private var is_receipt: Bool = false // This should be passed as a parameter or state
    public func setIsReceipt(isReceipt: Bool) { // Public method to set is_receipt
        self.is_receipt = isReceipt
    }
}
