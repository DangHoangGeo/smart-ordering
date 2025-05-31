//
//  AuthService.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/26.
//

import Foundation
import FirebaseAuth
import GoogleSignIn
import Combine
import FirebaseCore

enum AuthError: Error, LocalizedError {
    case noCurrentUser
    case noIDToken
    case credentialError(Error)
    case signInError(Error)
    case signOutError(Error)
    case userDataFetchError(Error)
    case userDataSaveError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .noCurrentUser: return "No current user found."
        case .noIDToken: return "Could not retrieve ID token for Google Sign-In."
        case .credentialError(let err): return "Credential error: \(err.localizedDescription)"
        case .signInError(let err): return "Sign-in error: \(err.localizedDescription)"
        case .signOutError(let err): return "Sign-out error: \(err.localizedDescription)"
        case .userDataFetchError(let err): return "Failed to fetch user data: \(err.localizedDescription)"
        case .userDataSaveError(let err): return "Failed to save user data: \(err.localizedDescription)"
        case .unknown: return "An unknown authentication error occurred."
        }
    }
}

class AuthService {
    static let shared = AuthService()

    private var authStateDidChangeListenerHandle: AuthStateDidChangeListenerHandle?
    private let auth = Auth.auth()

    private let authStateSubject = PassthroughSubject<User?, Never>()
    var authStatePublisher: AnyPublisher<User?, Never> {
        authStateSubject.eraseToAnyPublisher()
    }
    
    var currentFirebaseUser: User? {
        auth.currentUser
    }

    private init() {
        addAuthStateListener()
    }

    deinit {
        if let handle = authStateDidChangeListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    private func addAuthStateListener() {
        authStateDidChangeListenerHandle = auth.addStateDidChangeListener { [weak self] (_, user) in
            self?.authStateSubject.send(user)
        }
    }

    func signInWithGoogle(presentingViewController: UIViewController) async throws -> AuthDataResult {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.noIDToken // Or a more specific config error
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        do {
            let gidUser = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            
            guard let idToken = gidUser.user.idToken?.tokenString else {
                throw AuthError.noIDToken
            }
            
            let accessToken = gidUser.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            let authResult = try await auth.signIn(with: credential)
            return authResult
        } catch let error as NSError where error.code == GIDSignInError.canceled.rawValue {
            // Handle cancellation specifically if needed, or rethrow as generic error
            throw AuthError.signInError(error)
        } catch {
            throw AuthError.signInError(error)
        }
    }

    func signInWithEmail(email: String, password: String) async throws -> AuthDataResult {
        do {
            let authResult = try await auth.signIn(withEmail: email, password: password)
            return authResult
        } catch {
            throw AuthError.signInError(error)
        }
    }
    
    func signUpWithEmail(email: String, password: String) async throws -> AuthDataResult {
        do {
            let authResult = try await auth.createUser(withEmail: email, password: password)
            return authResult
        } catch {
            throw AuthError.signInError(error) // Or a specific signUpError
        }
    }

    func signOut() throws {
        do {
            if GIDSignIn.sharedInstance.currentUser != nil {
                GIDSignIn.sharedInstance.signOut()
            }
            try auth.signOut()
        } catch {
            throw AuthError.signOutError(error)
        }
    }
    
    func sendPasswordReset(toEmail email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch {
            throw AuthError.signInError(error) // Or a specific passwordResetError
        }
    }
}
