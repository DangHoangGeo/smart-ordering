//
//  AppConfig.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/26.
//

import Foundation
import SwiftUI

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

    // MARK: - Order Status Constants
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
    
    // MARK: - Table Status Constants
    struct TableStatus {
        static let available = "available"
        static let occupied = "occupied"
        static let reserved = "reserved"
        static let needsCleaning = "needs_cleaning"
        static let outOfService = "out_of_service"
    }

    // MARK: - Payment Methods
    struct PaymentMethods {
        static let cash = "Cash"
        static let payPay = "PayPay" // Consistent camelCase
        static let creditCard = "Credit Card" // More descriptive
    }
    
    // MARK: - Accessible Color Scheme
    struct Colors {
        // Primary Colors (meet WCAG AA standards)
        static let primary = Color(hex: "007AFF")       // iOS Blue
        static let primaryDark = Color(hex: "0055B3")   // Darker shade for better contrast
        static let primaryLight = Color(hex: "4DA3FF")  // Lighter shade for backgrounds
        
        // Status Colors (all meet WCAG AA for text contrast)
        static let success = Color(hex: "28CD41")       // Green
        static let warning = Color(hex: "FF9500")       // Orange
        static let error = Color(hex: "FF3B30")         // Red
        static let info = Color(hex: "5856D6")          // Purple
        
        // Table Status Colors
        static let tableAvailable = Color(hex: "34C759")    // Green
        static let tableOccupied = Color(hex: "FF3B30")     // Red
        static let tableReserved = Color(hex: "FF9500")     // Orange
        static let tableNeedsCleaning = Color(hex: "FFD60A") // Yellow
        static let tableOutOfService = Color(hex: "8E8E93")  // Gray
        
        // Order Status Colors
        static let orderPending = Color(hex: "8E8E93")      // Gray
        static let orderPrinted = Color(hex: "FF9500")      // Orange
        static let orderPreparing = Color(hex: "5856D6")    // Purple
        static let orderReady = Color(hex: "007AFF")        // Blue
        static let orderDelivered = Color(hex: "34C759")    // Green
        static let orderCancelled = Color(hex: "FF3B30")    // Red
        
        // Background Colors
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let groupedBackground = Color(.systemGroupedBackground)
        static let secondaryGroupedBackground = Color(.secondarySystemGroupedBackground)
        
        // Text Colors
        static let text = Color(.label)
        static let secondaryText = Color(.secondaryLabel)
        static let tertiaryText = Color(.tertiaryLabel)
        static let quaternaryText = Color(.quaternaryLabel)
        
        // Helper function to get status color with proper opacity
        static func statusColor(_ status: String, opacity: Double = 1.0) -> Color {
            switch status {
            case OrderStatus.pending:
                return orderPending.opacity(opacity)
            case OrderStatus.printed:
                return orderPrinted.opacity(opacity)
            case OrderStatus.preparing:
                return orderPreparing.opacity(opacity)
            case OrderStatus.readyForDelivery:
                return orderReady.opacity(opacity)
            case OrderStatus.delivered:
                return orderDelivered.opacity(opacity)
            case OrderStatus.finished:
                return orderDelivered.opacity(opacity)
            case OrderStatus.cancelled, OrderStatus.removed:
                return orderCancelled.opacity(opacity)
            default:
                return text.opacity(opacity)
            }
        }
        
        // Helper function to get table status color with proper opacity
        static func tableStatusColor(_ status: String, opacity: Double = 1.0) -> Color {
            switch status {
            case TableStatus.available:
                return tableAvailable.opacity(opacity)
            case TableStatus.occupied:
                return tableOccupied.opacity(opacity)
            case TableStatus.reserved:
                return tableReserved.opacity(opacity)
            case TableStatus.needsCleaning:
                return tableNeedsCleaning.opacity(opacity)
            case TableStatus.outOfService:
                return tableOutOfService.opacity(opacity)
            default:
                return text.opacity(opacity)
            }
        }
        
        // Helper function to determine if a color needs white or black text for contrast
        static func requiredTextColor(for backgroundColor: Color) -> Color {
            // Convert SwiftUI Color to UIColor for luminance calculation
            let uiColor = UIColor(backgroundColor)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            // Calculate relative luminance using WCAG formula
            let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            
            // Return white for dark backgrounds, black for light backgrounds
            return luminance > 0.5 ? Color.black : Color.white
        }
    }
    
    // MARK: - Printer Commands (ESC/POS Commands)
    struct PrinterCommands {
        static let initialize: [UInt8] = [0x1B, 0x40] // ESC @
        static let lineFeed: [UInt8] = [0x0A] // LF
        static let fontSize12: [UInt8] = [0x1B, 0x21, 0x00] // Normal size
        static let fontSize24: [UInt8] = [0x1B, 0x21, 0x30] // Double height and width
        static let boldOn: [UInt8] = [0x1B, 0x45, 0x01] // ESC E 1
        static let boldOff: [UInt8] = [0x1B, 0x45, 0x00] // ESC E 0
        static let alignLeft: [UInt8] = [0x1B, 0x61, 0x00] // ESC a 0
        static let alignCenter: [UInt8] = [0x1B, 0x61, 0x01] // ESC a 1
        static let alignRight: [UInt8] = [0x1B, 0x61, 0x02] // ESC a 2
        static let resetStyles: [UInt8] = [0x1B, 0x21, 0x00] // Reset text styles
        static let cutPaperFull: [UInt8] = [0x1D, 0x56, 0x00] // Full cut
        static let cutPaperPartial: [UInt8] = [0x1D, 0x56, 0x01] // Partial cut
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
