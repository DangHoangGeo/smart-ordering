//
//  MenuService.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/26.
//

// Services/MenuService.swift
import Foundation
import FirebaseFirestore
import FirebaseStorage

enum MenuServiceError: Error, LocalizedError {
    case firestoreError(Error)
    case storageError(Error)
    case decodingError(Error)
    case missingMenuItemID
    case missingCategoryID
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .firestoreError(let err): return "Firestore error: \(err.localizedDescription)"
        case .storageError(let err): return "Storage error: \(err.localizedDescription)"
        case .decodingError(let err): return "Decoding error: \(err.localizedDescription)"
        case .missingMenuItemID: return "Menu item ID is missing."
        case .missingCategoryID: return "Menu category ID is missing."
        case .invalidImageData: return "Invalid image data provided."
        }
    }
}

class MenuService {
    static let shared = MenuService()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    // MARK: - Categories
    private func categoriesCollectionRef(restaurantId: String) -> CollectionReference {
        db.collection(FirestorePaths.menuCategoriesCollection(restaurantId: restaurantId))
    }

    private func categoryDocumentRef(restaurantId: String, categoryId: String) -> DocumentReference {
        categoriesCollectionRef(restaurantId: restaurantId).document(categoryId)
    }

    func fetchCategories(restaurantId: String) async throws -> [MenuCategory] {
        do {
            let snapshot = try await categoriesCollectionRef(restaurantId: restaurantId)
                                    .order(by: "displayOrder")
                                    .getDocuments()
            return try snapshot.documents.compactMap { try $0.data(as: MenuCategory.self) }
        } catch {
            throw MenuServiceError.firestoreError(error)
        }
    }
    
    func addCategory(_ category: MenuCategory, restaurantId: String) async throws -> String {
        var mutableCategory = category
        mutableCategory.restaurantId = restaurantId // Ensure restaurantId is set
        mutableCategory.createdAt = Timestamp(date: Date())
        mutableCategory.updatedAt = Timestamp(date: Date())
        do {
            let ref = try categoriesCollectionRef(restaurantId: restaurantId).addDocument(from: mutableCategory)
            return ref.documentID
        } catch {
            throw MenuServiceError.firestoreError(error)
        }
    }

    func updateCategory(_ category: MenuCategory, restaurantId: String) async throws {
        guard let categoryId = category.id else { throw MenuServiceError.missingCategoryID }
        var mutableCategory = category
        mutableCategory.updatedAt = Timestamp(date: Date())
        do {
            try categoryDocumentRef(restaurantId: restaurantId, categoryId: categoryId).setData(from: mutableCategory, merge: true)
        } catch {
            throw MenuServiceError.firestoreError(error)
        }
    }
    
    func deleteCategory(restaurantId: String, categoryId: String) async throws {
        // Consider implications: what happens to menu items in this category?
        // Option 1: Delete them (cascade delete - complex to implement client-side securely)
        // Option 2: Mark them as uncategorized or move to a default category
        // Option 3: Prevent deletion if items exist (simplest for now)
        
        let itemsInCateogry = try await fetchMenuItems(restaurantId: restaurantId, categoryId: categoryId)
        guard itemsInCateogry.isEmpty else {
            throw MenuServiceError.firestoreError(NSError(domain: "MenuService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot delete category with existing menu items."]))
        }
        
        do {
            try await categoryDocumentRef(restaurantId: restaurantId, categoryId: categoryId).delete()
        } catch {
            throw MenuServiceError.firestoreError(error)
        }
    }


    // MARK: - Menu Items
    private func menuItemsCollectionRef(restaurantId: String) -> CollectionReference {
        db.collection(FirestorePaths.menuItemsCollection(restaurantId))
    }

    private func menuItemDocumentRef(restaurantId: String, itemId: String) -> DocumentReference {
        menuItemsCollectionRef(restaurantId: restaurantId).document(itemId)
    }

    // Fetch all menu items for a restaurant
    func fetchAllMenuItems(restaurantId: String) async throws -> [MenuItem] {
        do {
            let snapshot = try await menuItemsCollectionRef(restaurantId: restaurantId)
                                    .order(by: "categoryId")
                                    .order(by: "displayOrder")
                                    .getDocuments()
            return try snapshot.documents.compactMap { try $0.data(as: MenuItem.self) }
        } catch {
            throw MenuServiceError.firestoreError(error)
        }
    }

    // Fetch menu items by specific category
    func fetchMenuItems(restaurantId: String, categoryId: String) async throws -> [MenuItem] {
        do {
            let snapshot = try await menuItemsCollectionRef(restaurantId: restaurantId)
                                    .whereField("categoryId", isEqualTo: categoryId)
                                    .order(by: "displayOrder")
                                    .getDocuments()
            return try snapshot.documents.compactMap { try $0.data(as: MenuItem.self) }
        } catch {
            throw MenuServiceError.firestoreError(error)
        }
    }
    
    // Add or Update Menu Item (handles image upload if localImage data is present)
    func saveMenuItem(_ menuItem: MenuItem, restaurantId: String, imageData: Data? = nil) async throws -> String {
        var itemToSave = menuItem
        itemToSave.restaurantId = restaurantId // Ensure restaurantId is set
        itemToSave.updatedAt = Timestamp(date: Date())

        // Handle image upload
        if let imageData = imageData {
            let imageName = "\(UUID().uuidString).jpg" // Unique name for the image
            let imageRefPath = "restaurants/\(restaurantId)/menuItems/\(imageName)"
            
            do {
                let uploadedImageUrl = try await uploadImage(imageData: imageData, path: imageRefPath)
                itemToSave.imageUrl = uploadedImageUrl
                 // If there was an old image and this is an update, consider deleting the old one.
                 // This requires storing the old image path or fetching the item before saving.
                 // For simplicity now, we're not deleting old images on update.
            } catch {
                throw MenuServiceError.storageError(error)
            }
        } else if itemToSave.imageUrl == nil && menuItem.id != nil {
            // If imageData is nil AND imageUrl is nil during an update, it means remove existing image.
            // However, we need the old image path to delete it from storage.
            // This logic is more complex; for now, if imageData is nil, we just don't update imageUrl.
            // To truly remove an image, you'd set imageUrl to nil and handle deletion.
        }


        if let itemId = itemToSave.id, !itemId.isEmpty { // Update existing item
            do {
                try menuItemDocumentRef(restaurantId: restaurantId, itemId: itemId).setData(from: itemToSave, merge: true)
                return itemId
            } catch {
                throw MenuServiceError.firestoreError(error)
            }
        } else { // Add new item
            itemToSave.createdAt = Timestamp(date: Date())
            do {
                let ref = try menuItemsCollectionRef(restaurantId: restaurantId).addDocument(from: itemToSave)
                return ref.documentID
            } catch {
                throw MenuServiceError.firestoreError(error)
            }
        }
    }

    func deleteMenuItem(restaurantId: String, itemId: String, imageUrl: String?) async throws {
        do {
            try await menuItemDocumentRef(restaurantId: restaurantId, itemId: itemId).delete()
            // If there's an associated image, delete it from Storage
            if let imageUrlString = imageUrl, let imagePath = getPathFromStorageUrl(urlString: imageUrlString) {
                try await deleteImage(path: imagePath)
            }
        } catch {
            throw MenuServiceError.firestoreError(error) // Or a combined error
        }
    }

    // MARK: - Image Storage
    private func storageRef(path: String) -> StorageReference {
        storage.reference().child(path)
    }

    func uploadImage(imageData: Data, path: String) async throws -> String {
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg" // Assuming JPEG

        do {
            _ = try await storageRef(path: path).putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await storageRef(path: path).downloadURL()
            return downloadURL.absoluteString
        } catch {
            throw MenuServiceError.storageError(error)
        }
    }

    func deleteImage(path: String) async throws {
        do {
            try await storageRef(path: path).delete()
        } catch {
            // It's often okay if deletion fails (e.g., file already deleted),
            // but log it or handle as needed.
            print("Warning: Could not delete image at path \(path): \(error.localizedDescription)")
            // Re-throw if critical: throw MenuServiceError.storageError(error)
        }
    }
    
    // Helper to get storage path from full HTTPS URL
    // This is a simplified version and might need adjustment based on your URL structure
    private func getPathFromStorageUrl(urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        // Example Firebase Storage URL: https://firebasestorage.googleapis.com/v0/b/your-project-id.appspot.com/o/restaurants%2F...%2Fimage.jpg?alt=media&token=...
        // We need the path after "/o/" and before "?alt=media"
        let pathComponents = url.pathComponents
        if let objectPathComponentIndex = pathComponents.firstIndex(of: "o") {
            if objectPathComponentIndex + 1 < pathComponents.count {
                let objectPath = pathComponents.suffix(from: objectPathComponentIndex + 1).joined(separator: "/")
                return objectPath.removingPercentEncoding // Decode URL-encoded parts
            }
        }
        return nil
    }
}
