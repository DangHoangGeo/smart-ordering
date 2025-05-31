//
//  AppConfig.swift.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/26.
//

import Foundation

enum AppEnvironment {
    case debug
    case production
}

class AppConfig {
    static let shared = AppConfig() // Singleton instance

    private(set) var environment: AppEnvironment
    private(set) var firestoreCollectionPrefix: String
    private(set) var webAppBaseURL: String
    private(set) var defaultRestaurantId: String // For single-restaurant focus initially

    // Printer Configuration
    struct Printer {
        let ipAddress: String
        let port: Int
        let name: String // From old PRINTER.NAME, might be useful for Bluetooth later
    }
    private(set) var kitchenPrinter: Printer

    // Restaurant Details (can be fetched from Firestore later for more dynamic setup)
    struct RestaurantDetails {
        let name: String
        let address: String
        let branchIdentifier: String // e.g., "shin-koi-wa"
        let phone: String
        let website: String
        let wifiName: String?
        let wifiPass: String?
        let defaultDateFormat: String = "yyyy-MM-dd"
        let defaultDateTimeFormat: String = "yyyy-MM-dd HH:mm:ss"
        let takeoutTableCode: String = "takeout" // Special code for takeout orders
    }
    private(set) var restaurantDetails: RestaurantDetails

    private init() {
        #if DEBUG
        self.environment = .debug
        self.firestoreCollectionPrefix = "staging" // Or "dev"
        self.webAppBaseURL = "https://staging.yourwebapp.com" // Replace with your actual staging URL
        #else
        self.environment = .production
        self.firestoreCollectionPrefix = "production" // Or your actual production prefix
        self.webAppBaseURL = "https://yourwebapp.com" // Replace with your actual production URL
        #endif
        
        self.defaultRestaurantId = "shin-koi-wa" // Example ID

        // Default printer settings (can be made configurable later via UI)
        // These are from your old PRINTER struct
        self.kitchenPrinter = Printer(
            ipAddress: "192.168.3.7", // This should ideally be configurable
            port: 9100,
            name: "Printer001"
        )

        // Default restaurant details (from your old RESTAURANT struct)
        self.restaurantDetails = RestaurantDetails(
            name: "THUAN VIET FOOD",
            address: "Shin-Koiwa, Tokyo",
            branchIdentifier: "shin-koi-wa",
            phone: "", // Add actual phone
            website: "thuanviet-food.jp",
            wifiName: "THUAN VIET",
            wifiPass: "thuanviet5625"
        )
        
        // Initialize based on current environment (or UserDefault for demo toggle)
        refreshMode() // Call refreshMode to set initial values based on demo mode if needed
    }

    // Call this if isDemoMode changes in AppSettings
    func refreshMode() {
        let isDemo = UserDefaults.standard.bool(forKey: "isDemoMode") // Or get from AppSettings

        if isDemo {
            self.firestoreCollectionPrefix = "staging" // Or a specific demo prefix
            self.webAppBaseURL = "https://demo.yourwebapp.com" // Replace
        } else {
            #if DEBUG
            self.environment = .debug
            self.firestoreCollectionPrefix = "staging"
            self.webAppBaseURL = "https://staging.yourwebapp.com"
            #else
            self.environment = .production
            self.firestoreCollectionPrefix = "production"
            self.webAppBaseURL = "https://yourwebapp.com"
            #endif
        }
        print("AppConfig refreshed: Prefix = \(self.firestoreCollectionPrefix), WebURL = \(self.webAppBaseURL)")
    }

    // Constants for Order Statuses (from your old ORDER_STATUS)
    struct OrderStatus {
        static let pending = "10_pending"       // New order from web/manual
        static let printed = "09_printed"       // Printed to kitchen
        static let preparing = "08_preparing"     // Chef starts working
        static let readyForDelivery = "06_ready" // Item/Order is ready
        static let delivered = "05_delivered"   // Item/Order served to table
        static let finished = "02_finished"     // Order paid and completed
        static let cancelled = "01_cancelled"   // Order cancelled by staff/customer
        static let removed = "00_removed"       // Item removed by staff (soft delete)
    }
    
    struct PaymentMethods { // These were global in your old code.
        static let cash = "Cash"
        static let payPay = "PayPay" // Consistent camelCase
        static let creditCard = "Credit Card" // More descriptive
    }
    
    // Printer Commands (ESC/POS) - from your old PRINTER_CODE
    // These are highly printer-specific.
    struct PrinterCommands {
        static let initialize: [UInt8] = [0x1B, 0x40] // ESC @
        static let fontSize24: [UInt8] = [27, 33, 16]  // Double W, Double H
        static let fontSize12: [UInt8] = [27, 33, 0]   // Normal size (or specific like [27, 33, 12])
        static let boldOn: [UInt8] = [27, 69, 1]
        static let boldOff: [UInt8] = [27, 69, 0]
        static let resetStyles: [UInt8] = [27, 33, 0]
        static let alignLeft: [UInt8] = [27, 97, 0]
        static let alignCenter: [UInt8] = [27, 97, 1]
        static let alignRight: [UInt8] = [27, 97, 2]
        static let cutPaperFull: [UInt8] = [29, 86, 0] // or [29, 86, 65, 0] for partial
        static let cutPaperPartial: [UInt8] = [29, 86, 1] // or [29, 86, 66, 0]
        static let lineFeed: [UInt8] = [0x0A]
        // QR Code related commands are more complex and often specific to printer models / libraries
        // Example structure (to be verified with printer manual):
        // static func setQRCodeModel(_ model: UInt8 = 2) -> [UInt8] { [0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, model, 0x00] }
        // static func setQRCodeSize(_ size: UInt8) -> [UInt8] { ... }
        // static func setQRCodeErrorCorrection(_ level: UInt8) -> [UInt8] { ... } // e.g., 0x30 (L) to 0x33 (H)
        // static func storeQRCodeData(_ data: Data) -> [UInt8] { ... }
        // static func printQRCode() -> [UInt8] { [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30] }
    }
}
