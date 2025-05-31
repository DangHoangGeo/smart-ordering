//
//  MainTabView.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/26.
//

import SwiftUI

enum TabItem: Int, Identifiable, CaseIterable, Hashable {
    case orders, menu, tables, settings // Added settings for completeness
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .orders: return "Orders"
        case .menu: return "Menu"
        case .tables: return "Tables"
        case .settings: return "Settings"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .orders: return "list.bullet.clipboard"
        case .menu: return "menucard"
        case .tables: return "table.furniture"
        case .settings: return "gear"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var appSettings: AppSettings // For demo mode access
    @State private var selectedTab: TabItem = .orders

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView { OrdersHostView() } // Wrap in NavigationView for titles/bar items
                .tabItem { Label(TabItem.orders.title, systemImage: TabItem.orders.systemImageName) }
                .tag(TabItem.orders)
            
            NavigationView { MenuHostView() }
                .tabItem { Label(TabItem.menu.title, systemImage: TabItem.menu.systemImageName) }
                .tag(TabItem.menu)
            
            NavigationView { TablesHostView() }
                .tabItem { Label(TabItem.tables.title, systemImage: TabItem.tables.systemImageName) }
                .tag(TabItem.tables)
            
            NavigationView { SettingsView() }
                .tabItem { Label(TabItem.settings.title, systemImage: TabItem.settings.systemImageName) }
                .tag(TabItem.settings)
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Recommended for TabView content on iPad
        .onAppear {
             // Example: Set initial tab based on role
             if let role = userViewModel.appUser?.role {
                 switch role {
                 case .chef:
                     selectedTab = .orders // Or .menu
                 case .cashier:
                     selectedTab = .orders
                 default:
                     selectedTab = .orders
                 }
             }
        }
    }
}

// Host views for each tab to manage their own navigation stack if needed
struct OrdersHostView: View {
    var body: some View {
        OrdersListView() // This will be your actual orders list view
            .navigationTitle(TabItem.orders.title)
    }
}

struct MenuHostView: View {
    var body: some View {
        MenuListView() // This will be your actual menu list view
            .navigationTitle(TabItem.menu.title)
    }
}

struct TablesHostView: View {
    var body: some View {
        TablesListView() // This will be your actual tables list view
            .navigationTitle(TabItem.tables.title)
    }
}

// Placeholder for Settings View
struct SettingsView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        List {
            Section("Account") {
                if let appUser = userViewModel.appUser {
                    Text("Logged in as: \(appUser.displayName ?? appUser.email)")
                    Text("Role: \(appUser.role.rawValue)")
                }
                Button("Sign Out", role: .destructive) {
                    userViewModel.signOut()
                }
            }
            
            Section("Application") {
                 Toggle("Demo Mode", isOn: $appSettings.isDemoMode)
            }
            
            Section("About") {
                Text("Smart Ordering App")
                Text("Version 1.0.0") // Ideally, get this from Bundle
            }
        }
        .navigationTitle(TabItem.settings.title)
    }
}


// Views/Main/Tables/TablesListView.swift
struct TablesListView: View {
    var body: some View {
        Text("Tables List - Coming Soon!")
        // TODO: Integrate TablesViewModel and display table layout/status
        // Allow managing tables.
    }
}
