# Smart Ordering iOS App Code Review

## Introduction
This code review assesses the current state of the Smart Ordering iOS application codebase. The goal is to identify areas of strength, pinpoint opportunities for improvement, and provide actionable tasks for enhancing functionality, maintainability, security, and user experience. The review covers configuration, data models, services, view models, views, and helper utilities.

## General Recommendations
The codebase demonstrates a solid foundation using SwiftUI and Combine, with a clear separation of concerns in many areas. However, several general improvements can be made:

1.  **Consistency:**
    *   **Timestamp vs. Date:** Standardize on using Firebase `Timestamp` for all date fields persisted to Firestore (e.g., in `AppUser` model).
    *   **Error Handling:** While custom error enums are used, ensure all services and view models adopt a consistent pattern, potentially with shared error types for common scenarios (e.g., network, Firestore access).
    *   **Styling:** Centralize color definitions (like `AppConfig.Colors`) and ensure they are used consistently across all views for easier theming and maintenance.

2.  **Refactoring & Code Organization:**
    *   **`MenuItemEditView.swift`:** The `MenuItemEditView` struct, along with its helpers `TextEditorWithPlaceholder` and `ImagePicker`, is currently defined within `MenuListView.swift`. This should be refactored into its own dedicated file: `smart-ordering/Views/Main/Menu/MenuItemEditView.swift`.
    *   **`SettingsView.swift`:** The content for `SettingsView` is currently a placeholder struct within `MainTabView.swift`. This implementation should be moved to the actual `smart-ordering/Views/Main/SettingsView.swift` file.
    *   **`AddItemsSheet.swift` & `AddItemsToOrderSheet.swift`:** These two views are nearly identical. They should be consolidated into a single, reusable view (e.g., `ItemSelectionSheetView.swift`) that can be configured for different item selection contexts.

3.  **File Cleanup:**
    *   **`Models/Untitled.swift`:** This file is empty and should be deleted from the project.

4.  **Error and User Feedback:**
    *   **Message Auto-Clear:** Implement consistent auto-clearing for success and non-critical error messages displayed to the user (e.g., toasts, text fields in forms) after a short delay to improve UX.
    *   **Loading Indicators:** Ensure loading indicators are consistently used for all asynchronous operations that might take noticeable time.

5.  **Accessibility (A11y):**
    *   While basic labels exist, a thorough pass is needed to ensure all interactive elements are fully accessible with appropriate labels, hints, values, and traits. Dynamic type support should be tested.

## Module-Specific Reviews

### 1. Configuration (`AppConfig.swift`, `FirestorePaths.swift`)
    - **Summary:** `AppConfig.swift` centralizes application settings, environment variables, printer/restaurant hardcoded details, and constants (statuses, colors, printer commands). `FirestorePaths.swift` provides structured generation of Firestore paths using `AppConfig`.
    - **Suggestions & Tasks for AI:**
        - **Configurability:**
            - Task: Make printer IP and port configurable via a settings UI. (Detail: Modify `PrinterService` to read from a new section in `AppSettings` or a dedicated configuration model that can be updated via `SettingsView`. `SettingsView` will need UI elements to input and save these values, likely using `UserDefaults` or a Firestore-backed settings document).
            - Task: Allow restaurant details (name, address, phone, WiFi) to be fetched from Firestore (e.g., from a `restaurants/{restaurantId}/details` document) or configured via an admin UI instead of being hardcoded in `AppConfig`. `AppConfig` could load these at startup.
        - **Security:**
            - Task: Remove hardcoded WiFi password from `AppConfig.swift`. Instruct AI to integrate with the iOS Keychain for secure storage and retrieval of WiFi credentials. Update `SettingsView` or a dedicated setup flow to allow users to input/save these credentials to the Keychain.
            - Task: Advise on secure management of API keys (e.g., for Firebase, Google, or other third-party services) if they were to be added. This typically involves using `.xcconfig` files and not committing actual keys to version control, or using a server-side proxy.
        - **Other:**
            - Task: Enhance `refreshMode` in `AppConfig.swift`. If `firestoreCollectionPrefix` or `webAppBaseURL` change (e.g., due to demo mode toggle), dependent services (like `OrderService`, `MenuService`) and ViewModels should be notified or re-initialized to use the new paths/URLs. This might involve a notification mechanism or making services observe `AppSettings`.

### 2. Models (All model files)
    - **Summary:** Models are generally well-defined with `Codable` conformance for Firestore. `@DocumentID` and `Timestamp` are used appropriately. Relationships are through ID references. `Order` is an `ObservableObject` class, while others are structs.
    - **Suggestions & Tasks for AI:**
        - **`MenuCategory.swift`:**
            - Task: Add `iconUrl: String?` (for an optional category icon) and `isActive: Bool = true` (to allow hiding categories without deletion) fields. Update Firestore persistence in `MenuService`.
            - Task: Implement validation in `MenuService.addCategory` and `MenuService.updateCategory` to ensure `name` and `restaurantId` are non-empty.
        - **`MenuItem.swift`:**
            - Task: Add `estimatedPreparationTime: Int?` (in minutes) to store estimated cooking time.
            - Task: Design and add support for complex item modifiers. This involves:
                1.  Adding `struct MenuItemOptionSet: Codable, Hashable { var name: String; var options: [String]; var minSelections: Int; var maxSelections: Int }` to `MenuItem.swift`.
                2.  Adding `var optionSets: [MenuItemOptionSet]?` to `MenuItem.swift`.
                3.  Update Firestore persistence in `MenuService` for these new fields.
                4.  Update `MenuItemEditView` to allow defining and editing these option sets for a menu item.
        - **`Order.swift`:**
            - Task: Add `orderType: String` using an enum like `enum OrderType: String, Codable { case dineIn = "dine_in", takeout = "takeout", delivery = "delivery" }`. Update `CreateManualOrderView` and related logic in `OrdersViewModel` to set and use this.
            - Task: Consider adding `deliveryDetails: DeliveryInfo?` struct (e.g., `struct DeliveryInfo: Codable { var address: String; var contactName: String; var contactPhone: String; var deliveryNotes: String? }`) if delivery is a planned feature.
        - **`OrderItem.swift`:**
            - Task: Add `selectedModifiers: [OrderItemModifier]?` where `struct OrderItemModifier: Codable, Hashable { var optionSetName: String; var selectedOption: String; var priceChange: Double? }`. This will store the customer's selections based on `MenuItem.optionSets`. Update logic in `AddItemsToOrderSheet` and `OrderDetailView` to handle selection and display of these modifiers.
        - **`Table.swift`:**
            - Task: Add `qrCodeValue: String?` to store a string that can be converted to a QR code for table identification or quick ordering.
            - Task: Refactor `Table.id` vs `Table.code`. If `code` (e.g., "T01") is guaranteed unique per restaurant, suggest making `code` the Firestore document ID. This would involve setting `id` to the `code` value when creating `Table` objects and using this `id` in `TableService` for document paths. If `id` is to remain a separate Firestore auto-ID, ensure `code` is still indexed for queries if needed.
        - **`User.swift` (`AppUser`):**
            - Task: Change `lastLogin: Date?` and `createdAt: Date?` to `FirebaseFirestore.Timestamp?` for consistency with other models. Update `UserService.createAppUser` and `UserService.updateUserLastLogin` to use `Timestamp(date: Date())`.
        - **`Models/Untitled.swift`:**
            - Task: Delete the empty `Models/Untitled.swift` file from the project.

### 3. Services (All service files)
    - **Summary:** Services encapsulate Firestore and other backend interactions (like Firebase Storage, `NWConnection`). They generally use `async/await` and custom error enums. Transactions are used well in `OrderService`.
    - **Suggestions & Tasks for AI:**
        - **`AuthService.swift`:**
            - Task: Add a more specific error case to `AuthError`, such as `.configurationError(String)`, and use it in `signInWithGoogle` when `FirebaseApp.app()?.options.clientID` is nil, e.g., `throw AuthError.configurationError("Firebase ClientID not found")`.
        - **`MenuService.swift`:**
            - Task: In `saveMenuItem`, when updating an item (`itemId` exists) and new `imageData` is provided:
                1.  Fetch the existing `MenuItem` document from Firestore before saving the new data.
                2.  If the existing item has an `imageUrl`, and `imageData` is also provided (meaning image is being replaced), extract the old image path using `getPathFromStorageUrl(urlString: oldImageUrl)`.
                3.  After successfully uploading the new image and before saving the item with the new `imageUrl`, call `deleteImage(path: oldImagePath)` to remove the old image from Firebase Storage. Handle potential errors from `deleteImage` (e.g., log them).
            - Task: For `deleteCategory`: if items exist in the category, instead of throwing `MenuServiceError.firestoreError` with "Cannot delete category with existing menu items.", modify the logic to:
                1.  Fetch all `MenuItem`s belonging to that category.
                2.  Update each of these `MenuItem`s by setting their `categoryId` to a special "uncategorized" ID or `nil`. (This requires careful consideration of how "uncategorized" items are handled elsewhere).
                3.  Alternatively, consider if this operation is better suited for a Firebase Function for atomicity, especially if many items could be affected. For client-side, proceed with item updates in a batch if possible.
        - **`OrderService.swift`:**
            - Task: In `newOrdersListener` and `activeOrdersListener`, when `document.data(as: Order.self)` fails, instead of just printing to console, include the `document.documentID` in the error context and propagate a specific error. Add a case like `.decodingFailed(documentId: String, underlyingError: Error)` to `OrderServiceError` and use `completion(.failure(.decodingFailed(documentId: document.documentID, underlyingError: error)))`.
            - Task: Review the `activeStatuses` array in `fetchActiveOrders`. It currently includes `AppConfig.OrderStatus.pending` and `AppConfig.OrderStatus.delivered`. Confirm if this is the intended definition of "active" orders. Typically, "active" might mean orders that are being processed in the kitchen (e.g., `printed`, `preparing`, `readyForDelivery`). Adjust the list if needed.
            - Task: In `updateOrderStatus`, `updateOrderItemStatus`, `addItemsToOrder`, and `updatePaymentStatus`, ensure that any `NSError` objects created and assigned to `errorPointer` within transactions are replaced by specific `OrderServiceError` cases for consistency (e.g., use `OrderServiceError.orderNotFound` instead of `NSError(domain: "OrderService", code: -1, ...)`).
        - **`PrinterService.swift`:**
            - Task: Investigate and optionally implement a persistent connection mode for `NWConnection`. This would involve:
                1.  Not calling `disconnect()` immediately after `send()`.
                2.  Adding a method to explicitly connect if not already connected, and another to explicitly disconnect.
                3.  Implementing logic in `stateUpdateHandler` to handle connection drops (e.g., `.viabilityUpdate`, `.disconnected`) and attempt reconnection automatically or on next print job.
                4.  Consider keep-alive mechanisms if the printer requires them for long-lived TCP connections.
            - Task: In `send(data:completion:)`, after `connection.send(content:completion:)`, the `NWError?` in the completion handler indicates if the send was enqueued. For more robust error handling, ensure it's not just about enqueuing but also about the data being written to the socket, though `NWConnection` abstracts much of this. If `NWError` is `nil`, it usually means success at that layer.
        - **`TableService.swift`:**
            - Task: Modify the Firestore queries in `fetchTables` and `tablesListener` to include default sorting: `.order(by: "displayOrder").order(by: "code")`. This provides consistent ordering for the client unless overridden.
        - **`UserService.swift`:**
            - Task: Define a specific `UserServiceError` enum (e.g., with cases like `.dataFetchError(Error)`, `.dataSaveError(Error)`, `.missingUserID`). Replace usage of `AuthError` and generic `NSError(domain: "UserService", ...)` with this new enum in `UserService`.
            - Task: In `createAppUser`, ensure `lastLogin` and `createdAt` fields are initialized with `Timestamp(date: Date())` for consistency with the recommended change in the `AppUser` model and other services.

### 4. ViewModels (All ViewModel files)
    - **Summary:** ViewModels use `@Published` properties for state, interact with services, and manage loading/error states. `OrdersViewModel` handles complex order lifecycle and listeners. `UserViewModel` manages auth state.
    - **Suggestions & Tasks for AI:**
        - **`MenuViewModel.swift`:**
            - Task: Instead of calling `fetchAllMenuItems()` after `saveMenuItem` or `deleteCategory`, implement more granular local updates. For `saveMenuItem` (update), find and replace the item in `menuItems` and update `itemsByCategory`. For `saveMenuItem` (add), append to `menuItems` and re-group/re-sort. For `deleteCategory`, filter `menuItems` to remove those belonging to the deleted category and re-group.
            - Task: In `saveMenuItem`, `deleteMenuItem`, `addCategory`, `updateCategory`, and `deleteCategory`, implement auto-clearing for `successMessage` and `errorMessage` after a 3-4 second delay using `DispatchQueue.main.asyncAfter`.
        - **`OrdersViewModel.swift`:**
            - Task: Refactor `updateLocalOrderStatus` and other local array manipulations (`addItemToOrder`, `finalizeOrder`, `cancelOrder`). When an order's status changes significantly (e.g., moves from `newOrders` to `activeOrders`, or is removed from `activeOrders`), fetch the single, updated order data from `OrderService.fetchOrder()` after the service call succeeds. Then, update or remove it from the local arrays using this fresh data. This ensures local state is perfectly aligned with Firestore truth after an operation.
            - Task: In `createManualOrder` and `cancelOrder`, if `tableService.updateMultipleTableStatuses` fails after the primary order operation succeeds, set a specific `errorMessage` that clearly indicates the partial success (e.g., "Order created, but failed to update table status: \(error.localizedDescription)"). The UI should then display this persistent error until the user acknowledges it or attempts a manual fix.
            - Task: Review `updateLocalOrder` and other places where `Order` objects (which are classes) are modified. If an `Order` instance within the `@Published` arrays (`newOrders`, `activeOrders`) has its properties changed, SwiftUI should automatically pick up these changes if those properties within the `Order` class are also `@Published`. The explicit `objectWillChange.send()` in `updateLocalOrder` might be redundant or indicate a need to ensure `Order`'s properties correctly trigger updates. Remove it if redundant.
        - **`TablesViewModel.swift`:**
            - Task: Add a `@Published var successMessage: String?` property. Set this message in `updateTableStatus`, `updateMultipleTableStatuses`, and `addTable` upon successful completion. Implement auto-clear for this message after 3-4 seconds using `DispatchQueue.main.asyncAfter`.
        - **`UserViewModel.swift`:**
            - Task: In `signInWithGoogle`, `signInWithEmail`, and `signUpWithEmail`, ensure `self.isLoadingAuthState = false` is called in all error handling paths *before* any early returns, especially if the error occurs before `authService` methods (which might trigger the `authStatePublisher`) are successfully awaited.

### 5. Views (All View files)
    - **Summary:** Views are built with SwiftUI, generally showing good structure and interaction with ViewModels. Custom components enhance UI. Sheets are used for modal forms. Some accessibility features are present.
    - **Suggestions & Tasks for AI:**
        - **Refactoring:**
            - Task: Create a new Swift file named `MenuItemEditView.swift` under `smart-ordering/Views/Main/Menu/`. Move the `MenuItemEditView` struct definition, along with its helper structs `TextEditorWithPlaceholder` and `ImagePicker` (and its `Coordinator` class), from `MenuListView.swift` into this new `MenuItemEditView.swift` file. Update `MenuListView.swift` to correctly reference the moved view.
            - Task: Move the `SettingsView` struct implementation (currently a placeholder within `MainTabView.swift`) into the `smart-ordering/Views/Main/SettingsView.swift` file, replacing its empty content. Ensure `@EnvironmentObject` dependencies are correctly maintained or passed.
        - **`LoginView.swift`:**
            - Task: Add a visual password strength indicator below the "Confirm Password" field when `isSigningUp` is true. This could be a simple text label that changes color/text based on password complexity (e.g., length, character types).
        - **`MenuListView.swift`:**
            - Task: Implement the functionality for the `EditButton()` in the toolbar. When tapped, it should allow for list editing actions such as reordering categories (if `displayOrder` is manually managed and not just by name) or batch deleting items/categories. Alternatively, if this functionality is not planned, remove the `EditButton()`.
            - Task: In `MenuItemEditView` (after refactoring): if `viewModel.categories` is empty when adding a new item (i.e., `menuItemToEdit` is `nil`), disable the category `Picker`. Display a message like "Please add a category first from the menu management screen." below the picker.
        - **`AddItemsSheet.swift` & `AddItemsToOrderSheet.swift`:**
            - Task: Consolidate `AddItemsSheet.swift` and `AddItemsToOrderSheet.swift` into a single new file named `ItemSelectionSheetView.swift`. This new view should be generic enough to:
                1. Accept a completion handler that returns the selected items and their quantities (e.g., `([MenuItem: Int]) -> Void`).
                2. Be configurable for the context (e.g., a simple selection mode vs. adding directly to an `@ObservedObject var order: Order` passed in).
                3. The existing `AddItemsToOrderSheet`'s direct modification of `order.items.append()` should be replaced by calling the completion handler, and the calling view (`OrderDetailView` or `OrdersListView` for new orders) will be responsible for updating the order via the `OrdersViewModel`.
        - **`OrderDetailView.swift`:**
            - Task: Change `@State var order: Order` to `@ObservedObject var order: Order`. Ensure that when `OrderDetailView` is instantiated, it's passed an `Order` instance that is managed by `OrdersViewModel` (i.e., an element from `ordersViewModel.activeOrders` or `newOrders`). This will ensure that if the order details change due to background updates or actions in other parts of the app reflected in the ViewModel, `OrderDetailView` will correctly update. (Note: `Order` class already conforms to `ObservableObject`).
            - Task: For the bottom action bar (Print, Pay, Cancel buttons), ensure it is always visible and accessible, especially when the keyboard appears or on smaller devices. This might involve adjusting its container or using a different layout approach like a `.safeAreaInset(edge: .bottom)` if the main content is in a `ScrollView`.
        - **`SettingsView.swift` (after refactoring):**
            - Task: Implement a section to display basic, non-editable user profile information from `userViewModel.appUser` (e.g., Display Name, Email, Role).
            - Task: Add UI elements (e.g., `TextFields`, `Pickers`) to allow users to configure printer IP address and port. These settings should be saved (e.g., to `UserDefaults` or a Firestore document for user-specific settings) and used by `PrinterService`.
        - **Accessibility:**
            - Task: Conduct a thorough accessibility review across all views.
                - For `OrderRow`: Ensure the combined `accessibilityLabel` is comprehensive and natural-sounding.
                - For `MenuItemRow`, `TableTileView`: Ensure all visual information is conveyed.
                - For all interactive elements (buttons, pickers, toggles, context menus, swipe actions): Ensure they have clear, descriptive labels and appropriate hints.
                - Verify that dynamic type adjusts layouts gracefully.

### 6. Helpers (`PrintFormatter.swift`)
    - **Summary:** `PrintFormatter` converts `Order` objects to ESC/POS `Data` for kitchen and customer receipts, with support for ShiftJIS encoding and basic QR code generation. It's stateful regarding `is_receipt`.
    - **Suggestions & Tasks for AI:**
        - **Receipt Alignment:**
            - Task: Modify `formatOrderForCustomerReceipt` to use ESC/POS commands for defining columns for the itemized list (name, qty, price, total). Research and implement commands like `ESC D n1...nk NUL` (Set horizontal tab positions) or `GS L` / `GS W` (Set page width / print area width) combined with commands that print at absolute/relative positions. This will replace the current string padding logic for more robust alignment.
        - **State Management:**
            - Task: Refactor `PrintFormatter.swift`. Remove the `is_receipt` member variable and the `setIsReceipt(isReceipt: Bool)` method. Modify `formatOrderForCustomerReceipt(order: Order)` to `formatOrderForCustomerReceipt(order: Order, isOfficialReceipt: Bool)`. Update call sites in `OrdersViewModel.printCustomerReceipt` to pass this boolean.
        - **Error Handling:**
            - Task: Define a `PrintFormatterError` enum (e.g., `enum PrintFormatterError: Error { case stringEncodingFailed(String); case invalidQRCodeData(String) }`). Modify `stringToShiftJISData` to throw `PrintFormatterError.stringEncodingFailed` if `data(using: .shiftJIS)` returns `nil`. Modify `formatQRCodeForPrinting` to throw `PrintFormatterError.invalidQRCodeData` if `dataString.data(using: .ascii)` returns `nil`. Update methods like `formatOrderForKitchen` and `formatOrderForCustomerReceipt` to use `try` for these calls and propagate errors by changing their return type from `Data?` to `throws -> Data`.
        - **Internationalization:**
            - Task: Modify `PrintFormatter`'s `init()` to accept an optional `Locale` parameter (defaulting to `Locale(identifier: "ja_JP")`). Store this locale and use it in the `numberFormatter`.
            - Task: Externalize hardcoded strings like "領 収 証", "Thank you for your visit!", "Xin cam on!", and item list headers ("Item Qty Price Total") by passing them as parameters to the formatting functions, or by using a localization framework.
            - Task: Make ShiftJIS encoding conditional. Add a parameter to `init()` or relevant methods to specify the desired `String.Encoding` (e.g., `.shiftJIS`, `.windowsCP1252`, etc.), or use a printer capability profile to determine the correct encoding.
        - **Kitchen Docket:**
            - Task: Modify `formatOrderForKitchen(order: Order)` to accept an optional dictionary `[String: String]` mapping category IDs to category names (e.g., `categoryNames: [String: String]?`). In `OrdersViewModel.printOrderToKitchen`, fetch category details from `MenuViewModel` (if menu data is available) and pass this dictionary to `formatOrderForKitchen`. Inside `formatOrderForKitchen`, if `categoryNames` are provided, print the category name before listing its items.

## Conclusion
This review provides a roadmap for enhancing the Smart Ordering iOS app. Addressing these suggestions and tasks will improve code quality, maintainability, user experience, and feature completeness. The next steps involve prioritizing these tasks and implementing them iteratively.File created successfully.
