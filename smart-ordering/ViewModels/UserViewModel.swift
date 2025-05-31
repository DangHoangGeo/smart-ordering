//
//  UserViewModel.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/26.
//
// ViewModels/UserViewModel.swift
import Foundation
import Combine
import FirebaseAuth // Ensure this is imported
import UIKit

@MainActor
class UserViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var appUser: AppUser?
    @Published var isLoadingAuthState: Bool = true
    @Published var successMessage: String? // For non-error feedback, like "Password reset email sent"
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let authService = AuthService.shared
    private let userService = UserService.shared

    init() {
        subscribeToAuthState()
    }

    private func subscribeToAuthState() {
        authService.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] firebaseUser in
                guard let self = self else { return }
                
                // Clear previous messages when auth state changes significantly
                self.errorMessage = nil
                self.successMessage = nil

                self.currentUser = firebaseUser
                if let fbUser = firebaseUser {
                    // User is potentially logged in, start fetching/creating AppUser
                    // isLoadingAuthState will be set to true here by signIn/signUp methods
                    // or if it's an initial app load with a cached user.
                    if self.isLoadingAuthState == false { // If not already loading (e.g. from a direct signIn call)
                        self.isLoadingAuthState = true
                    }
                    Task {
                        await self.fetchOrCreateAppUser(firebaseUser: fbUser)
                        self.isLoadingAuthState = false // Done processing
                    }
                } else {
                    // User is logged out
                    self.appUser = nil
                    self.isLoadingAuthState = false // Done processing
                }
            }
            .store(in: &cancellables)
    }

    func checkAuthenticationState() {
        // This is called on app launch.
        // If there's a cached Firebase user, the listener will fire.
        // If not, we need to ensure loading stops.
        if authService.currentFirebaseUser == nil {
             isLoadingAuthState = false
        }
        // If authService.currentFirebaseUser is not nil,
        // the listener's sink block will set isLoadingAuthState to true then false.
    }

    private func fetchOrCreateAppUser(firebaseUser: User) async {
        self.errorMessage = nil // Clear previous errors before attempting
        do {
            if let existingAppUser = try await userService.fetchAppUser(userId: firebaseUser.uid) {
                self.appUser = existingAppUser
                await userService.updateUserLastLogin(userId: firebaseUser.uid)
            } else {
                let newAppUser = try await userService.createAppUser(firebaseUser: firebaseUser)
                self.appUser = newAppUser
                print("New AppUser created in Firestore: \(newAppUser.email)")
            }
        } catch {
            let effectiveError = error as? AuthError ?? AuthError.userDataFetchError(error)
            self.errorMessage = effectiveError.localizedDescription
            print("Error in fetchOrCreateAppUser: \(String(describing: self.errorMessage))")
            self.appUser = nil
        }
    }

    func signInWithGoogle(presentingViewController: UIViewController) async {
        self.errorMessage = nil
        self.successMessage = nil
        self.isLoadingAuthState = true
        do {
            _ = try await authService.signInWithGoogle(presentingViewController: presentingViewController)
            // Auth state listener handles the rest. isLoadingAuthState will be set to false by the listener.
        } catch {
            let effectiveError = error as? AuthError ?? AuthError.signInError(error)
            self.errorMessage = effectiveError.localizedDescription
            self.isLoadingAuthState = false
            print("Error during Google Sign-In: \(String(describing: self.errorMessage))")
        }
    }

    func signInWithEmail(email: String, password: String) async {
        self.errorMessage = nil
        self.successMessage = nil
        self.isLoadingAuthState = true
        do {
            _ = try await authService.signInWithEmail(email: email, password: password)
            // Auth state listener handles the rest. isLoadingAuthState will be set to false by the listener.
        } catch {
            let effectiveError = error as? AuthError ?? AuthError.signInError(error)
            self.errorMessage = effectiveError.localizedDescription
            self.isLoadingAuthState = false
            print("Error during Email Sign-In: \(String(describing: self.errorMessage))")
        }
    }
    
    func signUpWithEmail(email: String, password: String) async {
        self.errorMessage = nil
        self.successMessage = nil
        self.isLoadingAuthState = true
        do {
            _ = try await authService.signUpWithEmail(email: email, password: password)
            // Auth state listener handles the rest. isLoadingAuthState will be set to false by the listener.
        } catch {
            let effectiveError = error as? AuthError ?? AuthError.signInError(error)
            self.errorMessage = effectiveError.localizedDescription
            self.isLoadingAuthState = false
            print("Error during Email Sign-Up: \(String(describing: self.errorMessage))")
        }
    }

    func signOut() {
        self.errorMessage = nil
        self.successMessage = nil
        // isLoadingAuthState will be set to true by the listener if needed, then false
        do {
            try authService.signOut()
        } catch {
            let effectiveError = error as? AuthError ?? AuthError.signOutError(error)
            self.errorMessage = effectiveError.localizedDescription
            print("Error during Sign-Out: \(String(describing: self.errorMessage))")
        }
    }
    
    func sendPasswordReset(email: String) async {
        self.errorMessage = nil
        self.successMessage = nil
        self.isLoadingAuthState = true // Indicate activity
        do {
            try await authService.sendPasswordReset(toEmail: email)
            self.successMessage = "Password reset email sent to \(email). Please check your inbox."
        } catch {
            let effectiveError = error as? AuthError ?? AuthError.signInError(error)
            self.errorMessage = effectiveError.localizedDescription
            print("Error sending password reset: \(String(describing: self.errorMessage))")
        }
        self.isLoadingAuthState = false // Reset loading state
    }
}
