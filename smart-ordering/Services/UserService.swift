//
//  UserService.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class UserService {
    static let shared = UserService()
    private let db = Firestore.firestore()

    private func usersCollectionRef() -> CollectionReference {
        return db.collection(FirestorePaths.usersCollection)
    }

    private func userDocumentRef(userId: String) -> DocumentReference {
        return db.collection(FirestorePaths.usersCollection).document(userId)
    }

    func fetchAppUser(userId: String) async throws -> AppUser? {
        do {
            let document = try await userDocumentRef(userId: userId).getDocument()
            return try document.data(as: AppUser.self)
        } catch {
            // If document doesn't exist, it's not an error in the sense of "no user profile yet"
            if (error as NSError).code == FirestoreErrorCode.notFound.rawValue {
                return nil
            }
            throw AuthError.userDataFetchError(error)
        }
    }

    func createAppUser(firebaseUser: User, role: UserRole = .unassigned, restaurantId: String? = AppConfig.shared.defaultRestaurantId) async throws -> AppUser {
        let newAppUser = AppUser(
            id: firebaseUser.uid, // Ensure ID is set correctly
            email: firebaseUser.email ?? "Unknown Email",
            displayName: firebaseUser.displayName ?? "New User",
            photoURL: firebaseUser.photoURL?.absoluteString,
            role: role,
            restaurantId: restaurantId,
            lastLogin: Date(),
            createdAt: Date()
        )
        
        do {
            try userDocumentRef(userId: firebaseUser.uid).setData(from: newAppUser, merge: false) // merge: false to ensure it's a new doc
            return newAppUser
        } catch {
            throw AuthError.userDataSaveError(error)
        }
    }

    func updateAppUser(user: AppUser) async throws {
        guard let userId = user.id else {
            throw AuthError.userDataSaveError(NSError(domain: "UserService", code: 0, userInfo: [NSLocalizedDescriptionKey: "User ID is missing"]))
        }
        do {
            try userDocumentRef(userId: userId).setData(from: user, merge: true)
        } catch {
            throw AuthError.userDataSaveError(error)
        }
    }
    
    func updateUserLastLogin(userId: String) async {
        do {
            try await userDocumentRef(userId: userId).updateData(["lastLogin": Timestamp(date: Date())])
        } catch {
            print("Error updating last login: \(error.localizedDescription)")
        }
    }
}
