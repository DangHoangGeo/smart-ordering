# UI/UX Improvement Tasks

## Introduction
This document outlines specific, actionable tasks aimed at enhancing the user interface (UI) and user experience (UX) of the Smart Ordering iOS application. These tasks are derived from a comprehensive code review and are organized into phased improvements and cross-cutting concerns to guide development efforts.

## Phased Improvements

### Phase 1: Core Ordering Flow Enhancements
    - **Task:** Enhance visual distinction between 'New Web Orders' and 'Active Orders' sections in `OrdersListView`.
        - **File(s):** `OrdersListView.swift`
        - **Change:** Apply a subtle background tint (e.g., `AppConfig.Colors.secondaryBackground.opacity(0.5)`) to one of the sections or add distinct, theme-appropriate icons (e.g., `Image(systemName: "globe.americas.fill")` for Web Orders, `Image(systemName: "flame.fill")` for Active Orders) to their headers. Ensure the distinction improves scannability without being overly distracting.

    - **Task:** Implement a pull-to-refresh gesture for the `List` in `OrdersListView` containing both new and active orders.
        - **File(s):** `OrdersListView.swift`
        - **Change:** Add the `.refreshable { await ordersViewModel.refreshAllData() }` modifier to the `List` to allow users to manually trigger a refresh of order data.

    - **Task:** Standardize the placement, appearance, and auto-dismiss behavior of toast messages in `OrdersListView`.
        - **File(s):** `OrdersListView.swift` (and later, the new `ToastView.swift`)
        - **Change:** Ensure toast messages (for success/error) appear consistently (e.g., bottom of the screen), use standard styling (defined in `ToastView`), and auto-dismiss after a consistent duration (e.g., 3 seconds).

    - **Task:** Ensure the `BadgeView` count for new orders in `OrdersListView` is clearly visible and updates reliably in real-time as new orders arrive via the listener.
        - **File(s):** `OrdersListView.swift`, `BadgeView.swift`
        - **Change:** Verify listener updates correctly trigger view updates for the badge. Check font size, color contrast of the badge.

    - **Task:** In `OrderRow`, introduce distinct icons next to the order status text for quicker visual identification.
        - **File(s):** `OrderRow.swift`
        - **Change:** In the `StatusBadge` view or directly in `OrderRow`, add an `Image(systemName: ...)` before the status text. Example icons: 'Pending' - `hourglass`, 'Preparing' - `flame` or `chef.hat`, 'Printed' - `printer.fill`, 'Ready for Delivery' - `bell.fill`, 'Delivered' - `checkmark.circle.fill`, 'Cancelled' - `xmark.circle.fill`.

    - **Task:** Increase the tap target size for the entire `OrderRow` to make navigating to `OrderDetailView` easier.
        - **File(s):** `OrderRow.swift`
        - **Change:** Ensure the `HStack` containing the row content has sufficient padding and that the `NavigationLink` or `.onTapGesture` covers the entire visible area of the row.

    - **Task:** In `CreateManualOrderView`, for the 'Order Notes' `TextEditor`, add placeholder text.
        - **File(s):** `CreateManualOrderView.swift`
        - **Change:** Use a `ZStack` with a `Text("Customer requests, allergies, etc.")` overlaid on the `TextEditor` when `orderNotes` is empty, similar to the `TextEditorWithPlaceholder` used in `MenuItemEditView`.

    - **Task:** In `CreateManualOrderView`, if multiple tables are selected, display a concise, scrollable summary of selected table codes directly below the "Select Tables" button.
        - **File(s):** `CreateManualOrderView.swift`
        - **Change:** Add a `ScrollView(.horizontal)` or a simple `Text` view that joins the codes of `selectedTables`, visible when `!selectedTables.isEmpty`.

    - **Task:** Ensure validation messages in `CreateManualOrderView` (e.g., "Please select at least one table") are prominently displayed near the action button or relevant field.
        - **File(s):** `CreateManualOrderView.swift`
        - **Change:** Use a clearly styled `Text` view for `errorMessage` that is easily noticeable.

    - **Task:** For `OrderDetailView` on iPad landscape (or wider views), ensure the two-column layout effectively uses space. The action bar (Print/Pay/Cancel buttons) should be persistently visible, possibly fixed to the bottom of the right-hand (items) column.
        - **File(s):** `OrderDetailView.swift`
        - **Change:** Review the `GeometryReader` logic. For the landscape layout, ensure the `ScrollView` containing items doesn't push the action bar out of view. Consider embedding the action bar outside the items `ScrollView` within its column or using `.safeAreaInset(edge: .bottom)`.

    - **Task:** Standardize the presentation style (e.g., modal sheet vs. navigation) and transition animations for item editing sheets (`EditOrderItemQuantitySheet`, `ItemNoteEditSheetView`) launched from `OrderDetailView`.
        - **File(s):** `OrderDetailView.swift`
        - **Change:** Decide on a consistent presentation (e.g., all as sheets) and ensure they use default system transitions or a consistent custom transition if applicable.

    - **Task:** When an item's status is changed via the segmented picker in `OrderItemRow` (within `OrderDetailView`), provide immediate visual feedback.
        - **File(s):** `OrderItemRow.swift`
        - **Change:** After a successful status update, briefly highlight the background of the `OrderItemRow` or the picker itself (e.g., with a quick fade-in/out color effect).

    - **Task:** In `OrderItemRow`, make the quantity display more prominent and its tap target for editing clearer and larger.
        - **File(s):** `OrderItemRow.swift`
        - **Change:** Increase the font size for the quantity text (e.g., `Text("\(item.quantity)×").font(.title3.bold())`). Ensure the `.onTapGesture` area for `onEditQuantity()` is sufficiently large around the quantity.

    - **Task:** For swipe actions in `OrderItemRow`, consider adding a subtle visual cue on first appearance or a help section if platform design guidelines allow, to improve discoverability.
        - **File(s):** `OrderItemRow.swift`
        - **Change:** This is more of a design consideration. If implemented, it might involve a brief animation or an onboarding tip for new users.

    - **Task:** If consolidating `AddItemsSheet.swift` and `AddItemsToOrderSheet.swift` into `ItemSelectionSheetView.swift`, ensure the view's title or a header clearly indicates the context.
        - **File(s):** New `ItemSelectionSheetView.swift` (after consolidation from `AddItemsSheet.swift`, `AddItemsToOrderSheet.swift`)
        - **Change:** Pass a context parameter (e.g., an enum `SelectionContext { case newOrder, existingOrder(Order) }`) to the sheet and adjust the `.navigationTitle()` or an internal header `Text` view accordingly.

    - **Task:** In the 'Selected Items Summary' section of `AddItemsToOrderSheet` (or `ItemSelectionSheetView`), make the remove buttons (`xmark.circle.fill`) for individual selected items larger and more visually distinct.
        - **File(s):** `AddItemsSheet.swift`, `AddItemsToOrderSheet.swift` (or consolidated `ItemSelectionSheetView.swift`)
        - **Change:** Increase the `font()` size or `padding()` of the remove button within the summary pill/tag for easier tapping.

    - **Task:** In `AddItemsToOrderSheet` (or `ItemSelectionSheetView`), add a 'Clear All Selections' button if users frequently select multiple items and might need to reset their choices quickly.
        - **File(s):** `AddItemsSheet.swift`, `AddItemsToOrderSheet.swift` (or consolidated `ItemSelectionSheetView.swift`)
        - **Change:** Add a `Button("Clear All")` in the summary section or toolbar that clears the `selectedItems` dictionary.

    - **Task:** When an item is selected in `AddItemsToOrderSheet` (or `ItemSelectionSheetView`), provide more obvious visual feedback on the `MenuItemRow` itself.
        - **File(s):** `AddItemsSheet.swift`, `AddItemsToOrderSheet.swift` (or consolidated `ItemSelectionSheetView.swift`), `MenuItemRow.swift`
        - **Change:** Modify `MenuItemRow` to visually indicate selection (e.g., a checkmark overlay, background color change, more prominent border) when `quantity > 0`.

    - **Task:** In `PaymentSheetView`, improve the layout of denomination buttons (e.g., ¥1000, ¥2000) for 'Amount Tendered'.
        - **File(s):** `PaymentSheetView.swift`
        - **Change:** Use a `LazyVGrid` or a more adaptive `HStack` that wraps if many denominations are present, ensuring buttons are well-spaced and easy to tap.

    - **Task:** In `PaymentSheetView`, when the "Finalize & Pay" button is disabled, provide more explicit visual feedback.
        - **File(s):** `PaymentSheetView.swift`
        - **Change:** Significantly dim the button using `.opacity(0.5)` when disabled. Optionally, add a small `Text` view below the button explaining why it's disabled (e.g., "Amount tendered is less than total.") if `!canFinalize`.

    - **Task:** In `PaymentSheetView`, ensure the "Change Due" calculation is prominently displayed and updates instantly as the amount tendered is modified.
        - **File(s):** `PaymentSheetView.swift`
        - **Change:** Use a larger font or bold weight for the "Change Due" amount. Ensure the `amountTenderedString` binding updates `changeDue` calculation promptly.

### Phase 2: Menu Management Flow
    - **Task:** In `MenuListView`, if the `EditButton()` in the toolbar is to be used for list editing actions (e.g., reordering categories, batch deleting items), implement this functionality. If not planned, remove the button.
        - **File(s):** `MenuListView.swift`
        - **Change:** Wire the `EditButton()` to enable SwiftUI's list editing mode (e.g., `.environment(\.editMode, .constant(self.isEditing ? .active : .inactive))`) and implement `onDelete` or `onMove` for the `ForEach` loops.

    - **Task:** Improve the visual separation or affordance of context menu actions (Make Unavailable/Available, Delete) on menu items in `MenuListView`.
        - **File(s):** `MenuListView.swift`
        - **Change:** Add `Label`s with icons to the context menu `Button`s if not already present (current code shows it's there). Ensure sufficient spacing if many actions.

    - **Task:** When a search in `MenuListView` yields no results, enhance the `emptyStateView` to be more engaging.
        - **File(s):** `MenuListView.swift`
        - **Change:** Modify the `emptyStateView` text when `!menuViewModel.searchText.isEmpty` to something like: "No items match '\(menuViewModel.searchText)'. Try a different search, or add this item if it's new!"

    - **Task:** Ensure the `CategoryFilterView` in `MenuListView` clearly indicates the currently selected filter, especially if using a `SegmentedPickerStyle` with many categories (text might truncate).
        - **File(s):** `MenuListView.swift` (specifically `CategoryFilterView`)
        - **Change:** If using `SegmentedPickerStyle`, test with many categories. If truncation is an issue, consider changing to a `.menu` style picker for the filter on smaller width devices or if category names are long.

    - **Task:** In `MenuItemEditView` (once refactored), make the 'Image Selection' section more intuitive.
        - **File(s):** `MenuItemEditView.swift` (after refactoring)
        - **Change:** Increase the tap area for adding/changing images. Use a more prominent button style for "Change Image" / "Add Image". Clearly indicate when an image is loaded vs. placeholder.

    - **Task:** In `MenuItemEditView` (once refactored), if no categories exist when a user tries to add a new menu item, prominently display a message and optionally provide a button/link to navigate to category creation.
        - **File(s):** `MenuItemEditView.swift` (after refactoring)
        - **Change:** Below the category `Picker`, if `viewModel.categories.isEmpty`, show `Text("No categories available. Please add a category first from the menu management screen.") .foregroundColor(.orange)`. Consider adding a `Button("Create Category")` that could trigger a sheet or navigation.

    - **Task:** In `MenuItemEditView` (once refactored), ensure consistent styling and placement for form validation error messages (e.g., for invalid price, empty name).
        - **File(s):** `MenuItemEditView.swift` (after refactoring)
        - **Change:** Display `viewModel.errorMessage` in a consistent location (e.g., at the top of the form or below the save button) with clear error styling (red text, icon).

    - **Task:** In `MenuItemEditView` (once refactored), review form field spacing, alignment, and overall visual hierarchy within the `Form` for a clean and easy-to-use interface.
        - **File(s):** `MenuItemEditView.swift` (after refactoring)
        - **Change:** Adjust `Spacer`s, `padding`, and section grouping to ensure logical flow and visual balance.

### Phase 3: Table Management Flow
    - **Task:** In `TablesListView`, if the number of tables is expected to be large, consider adding filtering options (e.g., by section like "Patio", "Main Dining", or by status like "Available", "Occupied").
        - **File(s):** `TablesListView.swift`
        - **Change:** Add `Picker`s or a filter bar above the `LazyVGrid` to allow users to select a section or status to filter the displayed tables. Update `tablesViewModel` to support this filtering.

    - **Task:** In `TablesListView`, implement quick actions on `TableTileView` tap or long-press.
        - **File(s):** `TablesListView.swift`, `TableTileView.swift`
        - **Change:** Change the `.onTapGesture` on `TableTileView` within `TablesListView` to navigate to a table detail view (if planned) or present a `contextMenu` with actions like "Change Status," "View Current Order," "Assign Order."

    - **Task:** In `TablesListView`, when the list is empty, ensure the message "No tables found. Tap the '+' button to add a new table." is centered and clearly visible.
        - **File(s):** `TablesListView.swift`
        - **Change:** Use a `VStack` with `Spacer`s or `.frame(maxWidth: .infinity, maxHeight: .infinity)` for the `Text` view to ensure it's centered in the available space.

    - **Task:** In `TableTileView`, enhance visual cues for the `isSelected` state (used in `TableSelectionSheet`).
        - **File(s):** `TableTileView.swift`
        - **Change:** Make the border color/thickness for selected state (currently `AppConfig.Colors.primary` with width 2) more prominent or add a subtle background tint change to the tile itself.

    - **Task:** In `TableTileView`, verify that status icons and text have excellent contrast against their respective backgrounds for all table statuses.
        - **File(s):** `TableTileView.swift`, `AppConfig.swift` (for `AppConfig.Colors.tableStatusColor`)
        - **Change:** Test each status. For example, `AppConfig.Colors.tableStatusColor(table.status.rawValue)` (text color) against `AppConfig.Colors.tableStatusColor(table.status.rawValue, opacity: 0.2)` (background). Adjust opacity or base colors if contrast is insufficient.

    - **Task:** In `AddTableView`, for the 'Table Code' `TextField`, provide placeholder text with a clear example (e.g., "T1, A12, BAR5"). For 'Display Order', clarify its purpose via placeholder or caption text (e.g., "Numerical order in list").
        - **File(s):** `AddTableView.swift`
        - **Change:** Modify the `TextField` initializers: `TextField("Table Code (e.g., T1, BAR5)", text: $tableCode)`, `TextField("Display Order (e.g., 1, 2)", text: $displayOrder)`.

    - **Task:** Ensure validation alert messages (`alertMessage`) in `AddTableView` are specific to the field causing the error.
        - **File(s):** `AddTableView.swift`
        - **Change:** The current implementation already does this by setting `alertMessage` based on which validation fails. Maintain this specificity.

    - **Task:** In `TableSelectionSheet`, when a table tile is tapped and its selection state changes, provide immediate and prominent visual feedback on the tile itself.
        - **File(s):** `TableSelectionSheet.swift`, `TableTileView.swift`
        - **Change:** This is handled by `TableTileView`'s `isSelected` state. Ensure this state change is visually distinct enough (see related `TableTileView` task).

    - **Task:** In `TableSelectionSheet`, check the layout of the search bar and horizontal section filter pills for usability on smaller devices or with many/long section names.
        - **File(s):** `TableSelectionSheet.swift`
        - **Change:** Test on various device sizes. If filter pills overflow or truncate badly, consider alternative UI like a dropdown menu for sections if space is very constrained.

### Phase 4: Authentication & Settings
    - **Task:** In `LoginView`, add a 'Show/Hide Password' toggle button (e.g., an eye icon) next to the `CustomSecureField` for password and confirm password fields.
        - **File(s):** `LoginView.swift` (specifically `CustomSecureField`)
        - **Change:** Modify `CustomSecureField` to optionally show its content as plain text. Add an `Image` or `Button` within its `HStack` to toggle a `@State var isSecureTextEntry: Bool` property that controls `SecureField` vs. `TextField`.

    - **Task:** In `LoginView`, ensure error messages from `userViewModel.errorMessage` are specific and guide the user.
        - **File(s):** `LoginView.swift`, `UserViewModel.swift` (for generating messages)
        - **Change:** `UserViewModel` should set more specific error messages (e.g., "Incorrect password," "User not found," "Email already in use") based on errors from `AuthService`. `LoginView` will then display these.

    - **Task:** In `LoginView`, if the 'Demo Mode' toggle is a critical feature for app demonstration or testing, make it more visually distinct or provide a brief explanation tooltip/popover of what demo mode entails.
        - **File(s):** `LoginView.swift`
        - **Change:** Style the `Toggle` more prominently or add a small `Image(systemName: "info.circle")` next to it that, when tapped, shows an `Alert` or `Popover` explaining Demo Mode.

    - **Task:** Ensure the "Forgot Password?" button and the "Sign Up"/"Log In" toggle button in `LoginView` have clear accessibility labels and hints.
        - **File(s):** `LoginView.swift`
        - **Change:** Add `.accessibilityHint("Navigates to the password reset screen.")` for "Forgot Password?". For the toggle: `Text(isSigningUp ? "Switch to Log In" : "Switch to Sign Up")`.

    - **Task:** In `SettingsView` (once refactored and populated), design a clear and organized layout using `List` sections for grouping related settings.
        - **File(s):** `SettingsView.swift`
        - **Change:** Use `Section(header: Text("..."))` for "Account," "Application," "Printer Configuration" (if added), and "About."

    - **Task:** In `SettingsView`, for the 'Sign Out' button, implement a confirmation dialog (`.alert`) to prevent accidental logout.
        - **File(s):** `SettingsView.swift`
        - **Change:** Add a `@State private var showingSignOutConfirm = false`. Set it to `true` when "Sign Out" is tapped. Present an `.alert("Confirm Sign Out", isPresented: $showingSignOutConfirm) { Button("Sign Out", role: .destructive) { userViewModel.signOut() }; Button("Cancel", role: .cancel) {} } message: { Text("Are you sure you want to sign out?") }`.

    - **Task:** If printer settings (IP, Port) are made configurable (as per Configuration review tasks), add a dedicated "Printer Settings" section in `SettingsView`.
        - **File(s):** `SettingsView.swift`, corresponding `AppSettings` or configuration model.
        - **Change:** Add `Section("Printer Configuration")` with `TextField`s for IP address and port. Include a "Save Printer Settings" button. Values should be loaded from and saved to `AppSettings` / `UserDefaults` or a Firestore-backed settings store.

## Cross-Cutting Concerns

### 1. Accessibility (A11y)
    - **Task (Global - VoiceOver Labels & Hints):** Audit all View files for comprehensive VoiceOver support.
        - **File(s):** All View files.
        - **Change:** Ensure every interactive element (buttons, sliders, pickers, text fields, toggles, context menu items, swipe actions, list rows that navigate) has a clear, concise, and informative `accessibilityLabel` that describes its purpose or action (e.g., `Button("Save") { ... }.accessibilityLabel("Save changes")`). Add descriptive `accessibilityHint`s where the action or result of an interaction is not immediately obvious from the label alone (e.g., for a complex custom control or a row: `.accessibilityHint("Double tap to open order details.")`).

    - **Task (Global - VoiceOver Traits):** Assign appropriate accessibility traits to elements across all View files.
        - **File(s):** All View files.
        - **Change:** Examples: `.isButton` for `Text` or `HStack` views that have an `.onTapGesture` making them act like buttons; `.isHeader` for `Text` views serving as section headers; `.isSelected` for currently selected filter pills or tabs; `.playsSound` if an action triggers a sound. Ensure custom controls like `CategoryPill` and `TableTileView` correctly convey their interactive nature and state.

    - **Task (Global - VoiceOver Navigation):** Verify that the VoiceOver navigation order is logical and follows the visual flow of the screen in all View files.
        - **File(s):** All View files.
        - **Change:** Use `.accessibilitySortPriority` to influence reading order if necessary. For complex custom views, use `.accessibilityElement(children: .contain)` to group elements or `.accessibilityElement(children: .ignore)` on purely decorative sub-elements if their content is covered by the parent's label.

    - **Task (Global - Dynamic Type):** Verify and enhance dynamic type support across all View files.
        - **File(s):** All View files.
        - **Change:** Test all text elements (labels, text fields, text editors, buttons with text) with various dynamic type sizes, including larger accessibility sizes. Ensure text scales appropriately using `.font()` modifiers correctly (e.g., `.font(.headline)`) and remains legible without truncation. Verify that layouts adapt gracefully (e.g., using `ScrollView`, `ViewThatFits`, or adaptive `HStack`/`VStack` spacing). Ensure custom views with text (`CategoryPill`, `TableTileView`, `OrderRow`) correctly handle font scaling.

    - **Task (Global - Color Contrast):** Conduct a color contrast audit for all text elements, interactive icons, and meaningful graphical elements against their backgrounds.
        - **File(s):** `AppConfig.swift` (for `AppConfig.Colors`), all View files.
        - **Change:** Use accessibility inspector tools to measure contrast ratios. Ensure they meet WCAG 2.1 AA guidelines (4.5:1 for normal text, 3:1 for large text and graphics). Adjust colors in `AppConfig.Colors` or local view styles. Pay special attention to status indicators (e.g., `OrderRow.StatusBadge`, `TableTileView` status colors) and error/success messages.

    - **Task (Specific - `TableTileView.swift` Contrast):** Specifically review and adjust the contrast of the status text and its associated icon against the tile's background color for each table status.
        - **File(s):** `TableTileView.swift`, `AppConfig.swift`.
        - **Change:** For instance, for 'Needs Cleaning' status, ensure `AppConfig.Colors.tableStatusColor("needs_cleaning")` (text/icon color) has sufficient contrast against `AppConfig.Colors.tableStatusColor("needs_cleaning", opacity: 0.15)` (background color). Adjust opacity or base colors in `AppConfig.Colors.tableStatusColor` if needed.

### 2. User Feedback Standardization
    - **Task (Global - Toast Messages):** Design and implement a standardized system for displaying toast messages (success, error, info).
        - **File(s):** Create new `Views/Components/ToastView.swift`. Update `OrdersListView.swift`, `OrderDetailView.swift`. Plan integration into other views.
        - **Change:** `ToastView.swift` should be configurable for message, type (affecting color/icon: green/checkmark for success, red/xmark for error, blue/info for info), and duration. Define standard appearance (font, padding, corner radius, shadow), bottom-screen positioning, and slide/fade animation. Implement auto-dismissal (e.g., 3s for success/info, 5s for error). Refactor existing toasts in `OrdersListView` and `OrderDetailView` to use this new component.

    - **Task (Global - Loading Indicators):** Ensure all `ProgressView` instances are consistently styled and placed. Provide context for non-obvious loading operations.
        - **File(s):** All View files using `ProgressView`.
        - **Change:** For full-screen/section loading, center `ProgressView`. For inline loading (e.g., button busy state), size and align appropriately. Accompany with text if needed (e.g., `ProgressView("Saving item...")`).

    - **Task (Global - Inline Form Feedback):** Standardize the display of inline error/success messages within forms.
        - **File(s):** `LoginView.swift`, `MenuItemEditView` (in `MenuListView.swift` or refactored), `AddTableView.swift`, `PaymentSheetView.swift`.
        - **Change:** Messages should appear near the relevant input or action button. Use consistent styling: clear color (red for errors, green for success from `AppConfig.Colors`), optional icon (`Image(systemName: "exclamationmark.circle.fill")`), and legible font. Ensure messages are constructive.

### 3. Visual Consistency
    - **Task (Global - Color Palette):** Review all View files to ensure consistent use of the color palette defined in `AppConfig.Colors`.
        - **File(s):** All View files.
        - **Change:** Replace hardcoded `Color` values (e.g., `Color.blue`, `Color.red`, `Color(.systemBackground)`) with appropriate references from `AppConfig.Colors` (e.g., `AppConfig.Colors.primary`, `AppConfig.Colors.error`, `AppConfig.Colors.background`). This applies to text, backgrounds, icons, borders.

    - **Task (Global - Typography):** Establish and enforce a consistent typographic scale (font faces, weights, sizes for text roles like `.largeTitle`, `.title`, `.headline`, `.body`, `.subheadline`, `.caption`).
        - **File(s):** All View files. Potentially a new style guide document or additions to `AppConfig`.
        - **Change:** Review all `Text` elements and ensure they use semantic font styles (e.g., `.font(.headline)`) rather than fixed sizes where appropriate, to support Dynamic Type and maintain hierarchy. Define and use custom fonts through `AppConfig` if needed.

    - **Task (Global - Spacing & Padding):** Review and enforce consistent spacing and padding rules using a base unit (e.g., 4pt or 8pt multiples) within and between UI elements.
        - **File(s):** All View files.
        - **Change:** Standardize `.padding()` values, `Spacer(minLength: ...)` usage, and spacing in `HStack`/`VStack`/`LazyVGrid` to create a harmonious visual rhythm.

    - **Task (Global - Interactive Element Styling):** Ensure interactive elements (buttons, pickers, toggles, text fields) have a consistent visual style (e.g., corner radius, border style, shadow usage) and minimum touch target size (44x44 points).
        - **File(s):** All View files with interactive elements.
        - **Change:** Apply consistent `.buttonStyle()`, `.cornerRadius()`, `.shadow()`, `.frame(minWidth: 44, minHeight: 44)` where appropriate. Standardize the look of primary vs. secondary buttons.

### 4. Navigation & Interaction
    - **Task (Global - Navigation Bar Consistency):** Review navigation bar titles and button placements (leading/trailing `ToolbarItem`) for consistency across all navigated views within `MainTabView`.
        - **File(s):** `MainTabView.swift` (for host view titles), `MenuListView.swift`, `OrdersListView.swift`, `OrderDetailView.swift`, `TablesListView.swift`, `SettingsView.swift`.
        - **Change:** Titles should be clear and accurately reflect view content. Common actions (Add, Edit, Refresh, Cancel, Done) should have consistent placement (e.g., "Done" usually trailing, "Cancel" usually leading) and iconography/text.

    - **Task (Global - Sheet & Popover Consistency):** Ensure all sheets and popovers have clear and consistent dismissal controls and presentation styles.
        - **File(s):** All views presenting sheets or popovers (e.g., `LoginView.swift`, `MenuListView.swift`, `OrdersListView.swift`, `OrderDetailView.swift`, `TablesListView.swift`).
        - **Change:** Modal views presented as sheets should typically include a "Cancel" button (often leading) and/or a "Done"/"Save" button (often trailing) in their navigation bar, especially if they contain a `NavigationView`. Ensure interactive dismissal (swipe down) is appropriate for the context or disabled if actions must be taken.

## Conclusion
Addressing these UI/UX tasks will significantly improve the Smart Ordering application's usability, accessibility, and visual appeal. This will lead to a more intuitive, efficient, and enjoyable experience for all users, from staff managing orders and inventory to administrators configuring the system. A consistent and polished interface builds user trust and reduces cognitive load.

File created successfully.
