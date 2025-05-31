//
//  smart_orderingApp.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/26.
//

import SwiftUI
import Firebase

@main
struct smart_orderingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject var userViewModel = UserViewModel() // Handles auth state and user data
    @StateObject var appSettings = AppSettings() // For demo mode or other global settings

    var body: some Scene {
        WindowGroup {
            ContentView() // This will be your main navigation view
                .environmentObject(userViewModel)
                .environmentObject(appSettings)
                .onAppear {
                    // Check initial authentication state
                    userViewModel.checkAuthenticationState()
                }
        }
    }
}

// A simple global settings class (can be expanded)
class AppSettings: ObservableObject {
    @Published var isDemoMode: Bool {
        didSet {
            UserDefaults.standard.set(isDemoMode, forKey: "isDemoMode")
            // Refresh any configurations that depend on demo mode
            AppConfig.shared.refreshMode()
        }
    }

    init() {
        self.isDemoMode = UserDefaults.standard.bool(forKey: "isDemoMode")
    }
}

struct ContentView: View {
    @EnvironmentObject var userViewModel: UserViewModel

    var body: some View {
        if userViewModel.isLoadingAuthState {
            LoadingView(text: "Authenticating...")
        } else if userViewModel.currentUser != nil && userViewModel.appUser != nil {
            // User is logged in and appUser profile is loaded
            MainTabView() // Your main app interface after login
        } else {
            // User is not logged in or appUser profile not yet loaded
            LoginView()
        }
    }
}

// Placeholder LoadingView
struct LoadingView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    var text: String = "Loading..."
    var body: some View {
        VStack {
            ProgressView()
            Text(text)
                .padding(.top)
            if let error = userViewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }
}
