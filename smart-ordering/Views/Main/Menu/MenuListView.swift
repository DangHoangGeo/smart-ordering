//
//  MenuListView.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/26.
//

// Views/Main/Menu/MenuListView.swift
import SwiftUI
import FirebaseCore

struct MenuListView: View {
    @StateObject private var menuViewModel = MenuViewModel() // Initialize here or pass from parent
    @EnvironmentObject var appSettings: AppSettings // For restaurantId if needed
    @EnvironmentObject var userViewModel: UserViewModel // For currentRestaurantId
    @State private var hapticFeedbackLight = UIImpactFeedbackGenerator(style: .light)

    @State private var showingAddItemSheet = false
    @State private var itemToEdit: MenuItem? = nil // Used to trigger edit sheet

    var body: some View {
        VStack {
            if menuViewModel.isLoading && menuViewModel.menuItems.isEmpty {
                ProgressView("Loading Menu...")
                    .padding()
            } else {
                // Search Bar
                SearchBar(text: $menuViewModel.searchText, placeholder: "Search menu items...")
                    .padding(.horizontal)
                    .padding(.top)
                    .accessibilityLabel("Search menu items by name, Japanese name, or code")

                // Category Filter Picker (optional, could be tabs or a dropdown)
                CategoryFilterView(categories: menuViewModel.categories,
                                   selectedCategoryId: $menuViewModel.selectedCategoryIdFilter)
                    .padding(.horizontal)
                    .padding(.bottom, 5)
                    .accessibilityLabel("Filter menu items by category")
                
                // Menu Items List
                List {
                    ForEach(menuViewModel.itemsGroupedForDisplay, id: \.category.id) { section in
                        Section(header: Text(section.category.name).font(.headline)) {
                            if section.items.isEmpty {
                                Text("No items in this category\(menuViewModel.searchText.isEmpty ? "" : " matching your search").")
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(section.items) { item in
                                    MenuItemRow(item: item, onEdit: {
                                        self.itemToEdit = item
                                    }, onToggleAvailability: {
                                        Task { await menuViewModel.toggleItemAvailability(item) }
                                    })
                                }
                                .onDelete { indexSet in
                                     deleteItems(at: indexSet, in: section.category)
                                }
                            }
                        }
                    }
                     if menuViewModel.itemsGroupedForDisplay.isEmpty && !menuViewModel.isLoading {
                         Text(menuViewModel.searchText.isEmpty ? "No menu items found. Add some!" : "No items match your search.")
                             .foregroundColor(.secondary)
                             .padding()
                             .frame(maxWidth: .infinity, maxHeight: .infinity)
                     }
                }
                .listStyle(InsetGroupedListStyle()) // Or PlainListStyle
            }
            
            // Display error/success messages
            if let message = menuViewModel.errorMessage ?? menuViewModel.successMessage {
                 Text(message)
                    .foregroundColor(menuViewModel.errorMessage != nil ? .red : .green)
                    .padding()
                    .transition(.opacity.animation(.easeIn))
                    .onAppear { // Auto-dismiss message
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            if menuViewModel.errorMessage == message { menuViewModel.errorMessage = nil }
                            if menuViewModel.successMessage == message { menuViewModel.successMessage = nil }
                        }
                    }
            }
        }
        .navigationTitle("Menu Management")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    hapticFeedbackLight.impactOccurred()
                    itemToEdit = nil // Ensure it's a new item
                    showingAddItemSheet = true
                } label: {
                    Label("Add Item", systemImage: "plus.circle.fill")
                }
                .accessibilityLabel("Add new menu item")
            }
            ToolbarItem(placement: .navigationBarLeading) {
                if menuViewModel.isLoading {
                    ProgressView()
                } else {
                    EditButton() // For reordering or batch deleting (if implemented)
                }
            }
        }
        .sheet(isPresented: $showingAddItemSheet) {
            // When itemToEdit is nil, it's for adding a new item
            MenuItemEditView(viewModel: menuViewModel, menuItemToEdit: nil)
        }
        .sheet(item: $itemToEdit) { item in
            // When itemToEdit is not nil, it's for editing an existing item
            MenuItemEditView(viewModel: menuViewModel, menuItemToEdit: item)
        }
        .task { // Use .task for async operations on appear
            if menuViewModel.menuItems.isEmpty { // Load only if not already loaded
                // Set the correct restaurantId for the viewModel
                if let currentRestaurantId = userViewModel.appUser?.currentRestaurantId {
                     menuViewModel.restaurantId = currentRestaurantId
                }
                await menuViewModel.loadInitialData()
            }
        }
    }
    
    private func deleteItems(at offsets: IndexSet, in category: MenuCategory) {
        guard let categoryId = category.id else { return }
        let itemsInCategory = menuViewModel.itemsGroupedForDisplay.first(where: { $0.category.id == categoryId })?.items ?? []
        
        offsets.forEach { index in
            let itemToDelete = itemsInCategory[index]
            Task {
                await menuViewModel.deleteMenuItem(itemToDelete)
            }
        }
    }
}

// Simple Search Bar
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField(placeholder, text: $text)
                .accessibilityLabel(placeholder) // Label for the text field itself
                .foregroundColor(.primary)
            if !text.isEmpty {
                Button(action: { self.text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .accessibilityLabel("Clear search text")
            }
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10.0)
    }
}

// Category Filter View (Example with a Picker)
struct CategoryFilterView: View {
    let categories: [MenuCategory]
    @Binding var selectedCategoryId: String?

    var body: some View {
        Picker("Filter menu items by category", selection: $selectedCategoryId) { // More descriptive label
            Text("All Categories").tag(String?.none) // Option for no filter
            ForEach(categories.sorted()) { category in
                Text(category.name).tag(category.id as String?)
            }
        }
        .pickerStyle(SegmentedPickerStyle()) // Or .menu for a dropdown
    }
}


// Placeholder for MenuItemRow - We'll detail this next
struct MenuItemRow: View {
    let item: MenuItem
    var onEdit: () -> Void
    var onToggleAvailability: () -> Void
    @State private var hapticFeedbackLight = UIImpactFeedbackGenerator(style: .light)


    var body: some View {
        HStack {
            if let imageUrlString = item.imageUrl, let url = URL(string: imageUrlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 60, height: 60)
                            .accessibilityLabel("Loading image for \(item.name)")
                    case .success(let image):
                        image.resizable()
                             .aspectRatio(contentMode: .fill)
                             .frame(width: 60, height: 60)
                             .clipShape(RoundedRectangle(cornerRadius: 8))
                             .accessibilityLabel("Image of \(item.name)")
                    case .failure:
                        Image(systemName: "fork.knife.circle.fill") // Placeholder icon
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .foregroundColor(.gray)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityLabel("Image placeholder for \(item.name)")
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image(systemName: "fork.knife.circle.fill") // Placeholder for no image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("No image available for \(item.name)")
            }

            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.headline)
                if let nameJP = item.nameJP, !nameJP.isEmpty {
                    Text(nameJP)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text(String(format: "¥%.0f", item.price)) // Format price
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()

            Image(systemName: item.isAvailable ? "eye.fill" : "eye.slash.fill")
                .foregroundColor(item.isAvailable ? .green : .orange)
                .onTapGesture {
                    hapticFeedbackLight.impactOccurred()
                    onToggleAvailability()
                }
                .accessibilityLabel(item.isAvailable ? "Toggle to set item as unavailable" : "Toggle to set item as available")
        }
        .contentShape(Rectangle()) // Make the whole row tappable for context menu or navigation
        .onTapGesture { // For triggering edit on tap (alternative to swipe or button)
             onEdit()
        }
        .accessibilityHint("Tap to edit \(item.name) or swipe for more actions.")
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                // Trigger delete in ViewModel
                // Task { await viewModel.deleteMenuItem(item) } // If VM is accessible here
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading) {
            Button {
                onToggleAvailability()
            } label: {
                Label(item.isAvailable ? "Hide" : "Show", systemImage: item.isAvailable ? "eye.slash.fill" : "eye.fill")
            }
            .tint(item.isAvailable ? .orange : .green)
        }
    }
}

// Placeholder for MenuItemEditView - We'll detail this next
struct MenuItemEditView: View {
    @ObservedObject var viewModel: MenuViewModel // Pass the main ViewModel
    @State var menuItemToEdit: MenuItem? // If nil, it's a new item

    @Environment(\.dismiss) var dismiss

    // Form state
    @State private var name: String = ""
    @State private var nameJP: String = ""
    @State private var price: String = "" // Use String for TextField, convert to Double
    @State private var categoryId: String = ""
    @State private var descriptionText: String = ""
    @State private var code: String = ""
    @State private var isAvailable: Bool = true
    @State private var displayOrder: String = "0"
    
    @State private var selectedImage: UIImage? // For ImagePicker
    @State private var imageDataForUpload: Data? // Processed image data
    @State private var existingImageUrl: String?

    @State private var showImagePicker = false
    @State private var showingDeleteConfirm = false // For delete confirmation
    @State private var hapticFeedbackMedium = UIImpactFeedbackGenerator(style: .medium)


    var isEditing: Bool { menuItemToEdit != nil }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Image")) { // Section 1: Image
                    imageSelectionSection
                }

                Section(header: Text("Core Details")) { // Section 2: Core Details
                    TextField("Name (e.g., Pho Bo)", text: $name)
                        .accessibilityLabel("Menu item name")
                    TextField("Japanese Name (optional)", text: $nameJP)
                        .accessibilityLabel("Menu item Japanese name")
                    TextField("Price (e.g., 1200)", text: $price)
                        .keyboardType(.numberPad)
                        .accessibilityLabel("Menu item price")
                    Picker("Category", selection: $categoryId) {
                        ForEach(viewModel.categories.sorted()) { category in
                            Text(category.name).tag(category.id ?? "")
                        }
                    }
                    .accessibilityLabel(viewModel.categories.isEmpty ? "No categories available. Please add a category first." : "Select menu item category. Currently selected: \(viewModel.categories.first(where: {$0.id == categoryId})?.name ?? "None")")
                    if viewModel.categories.isEmpty && categoryId.isEmpty {
                        Text("No categories available. Please add a category first.")
                            .foregroundColor(.orange)
                    }
                    TextField("Item Code (optional, e.g., F001)", text: $code)
                        .autocapitalization(.allCharacters)
                        .accessibilityLabel("Menu item code")
                }

                Section(header: Text("Additional Information")) { // Section 3: Additional Info
                    TextEditorWithPlaceholder(text: $descriptionText, placeholder: "Description (e.g., ingredients, allergens)")
                        .frame(minHeight: 100)
                        .accessibilityLabel("Menu item description")
                    TextField("Display Order in Category", text: $displayOrder)
                         .keyboardType(.numberPad)
                         .accessibilityLabel("Menu item display order in category")
                }

                Section(header: Text("Availability")) { // Section 4: Availability
                    Toggle("Available for Ordering", isOn: $isAvailable)
                        .accessibilityLabel("Toggle item availability for ordering")
                }
                
                Section { // Section 5: Actions
                    Button(isEditing ? "Save Changes" : "Add Item") {
                        hapticFeedbackMedium.impactOccurred()
                        saveMenuItem()
                    }
                    .disabled(name.isEmpty || price.isEmpty || categoryId.isEmpty || viewModel.isLoading)
                    .accessibilityLabel(isEditing ? "Save changes to menu item" : "Add new menu item")
                    
                    if isEditing {
                        Button("Delete Item", role: .destructive) {
                            hapticFeedbackLight.impactOccurred()
                            showingDeleteConfirm = true
                        }
                        .disabled(viewModel.isLoading)
                        .accessibilityLabel("Delete menu item")
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView()
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "New Item")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel editing menu item")
                }
            }
            .onAppear(perform: populateFormForEditing)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { _, newImage in
                 guard let uiImage = newImage else {
                     imageDataForUpload = nil
                     return
                 }
                 imageDataForUpload = uiImage.jpegData(compressionQuality: 0.7)
            }
            .alert("Confirm Delete", isPresented: $showingDeleteConfirm) {
                Button("Delete Item", role: .destructive) {
                    hapticFeedbackMedium.impactOccurred()
                    if let item = menuItemToEdit {
                        Task { await viewModel.deleteMenuItem(item) }
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete the item \"\(name)\"? This action cannot be undone.")
            }
        }
    }
    
    private var imageSelectionSection: some View {
        VStack(alignment: .leading) {
            Text("Item Image").font(.headline)
            HStack {
                if let imageData = imageDataForUpload, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable().scaledToFit().frame(height: 100).cornerRadius(8)
                        .accessibilityLabel("Newly selected image preview")
                } else if let imageUrlString = existingImageUrl, let url = URL(string: imageUrlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit().frame(height: 100).cornerRadius(8)
                                .accessibilityLabel("Current item image")
                        } else if phase.error != nil {
                            Image(systemName: "photo.fill").frame(height: 100).foregroundColor(.gray)
                                .accessibilityLabel("Error loading item image")
                        } else {
                            ProgressView().frame(height: 100)
                                .accessibilityLabel("Loading item image")
                        }
                    }
                } else {
                    Image(systemName: "photo.on.rectangle.angled").resizable().scaledToFit().frame(height: 60).foregroundColor(.gray)
                        .accessibilityLabel("No image placeholder")
                }
                Spacer()
                Button(imageDataForUpload != nil || existingImageUrl != nil ? "Change Image" : "Add Image") {
                    showImagePicker = true
                }
                .accessibilityLabel(imageDataForUpload != nil || existingImageUrl != nil ? "Change menu item image" : "Add menu item image")
            }
            if imageDataForUpload != nil || existingImageUrl != nil {
                 Button("Remove Image", role: .destructive) {
                     selectedImage = nil
                     imageDataForUpload = nil
                     existingImageUrl = nil
                 }
                 .font(.caption)
                 .padding(.top, 2)
                 .accessibilityLabel("Remove menu item image")
            }
        }
    }


    private func populateFormForEditing() {
        guard let item = menuItemToEdit else {
            // Set default category if adding new and categories exist
            if categoryId.isEmpty, let firstCategory = viewModel.categories.first?.id {
                categoryId = firstCategory
            }
            return
        }
        name = item.name
        nameJP = item.nameJP ?? ""
        price = String(format: "%.2f", item.price)
        categoryId = item.categoryId
        descriptionText = item.description ?? ""
        code = item.code ?? ""
        isAvailable = item.isAvailable
        displayOrder = String(item.displayOrder)
        existingImageUrl = item.imageUrl
    }

    private func saveMenuItem() {
        guard let priceDouble = Double(price),
              let orderInt = Int(displayOrder) else {
            viewModel.errorMessage = "Invalid price or display order format."
            return
        }
        
        guard !categoryId.isEmpty else {
            viewModel.errorMessage = "Please select a category."
            return
        }

        var itemToSave: MenuItem
        if var existingItem = menuItemToEdit { // Editing
            existingItem.name = name
            existingItem.nameJP = nameJP.isEmpty ? nil : nameJP
            existingItem.price = priceDouble
            existingItem.categoryId = categoryId
            existingItem.description = descriptionText.isEmpty ? nil : descriptionText
            existingItem.code = code.isEmpty ? nil : code
            existingItem.isAvailable = isAvailable
            existingItem.displayOrder = orderInt
            if existingImageUrl == nil && selectedImage == nil { // If user explicitly removed image
                existingItem.imageUrl = nil
            }
            // localImage is not part of MenuItem, imageDataForUpload is passed separately
            itemToSave = existingItem
        } else { // Adding new
            itemToSave = MenuItem(
                restaurantId: viewModel.restaurantId, // Get from viewModel
                name: name,
                nameJP: nameJP.isEmpty ? nil : nameJP,
                description: descriptionText.isEmpty ? nil : descriptionText,
                price: priceDouble,
                categoryId: categoryId,
                code: code.isEmpty ? nil : code,
                isAvailable: isAvailable,
                displayOrder: orderInt,
                createdAt: Timestamp(date: Date()) // Set creation timestamp
            )
        }

        Task {
            await viewModel.saveMenuItem(itemToSave, imageData: imageDataForUpload)
            if viewModel.errorMessage == nil { // Only dismiss if successful
                dismiss()
            }
        }
    }
}

// TextEditor with Placeholder
struct TextEditorWithPlaceholder: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Color(UIColor.placeholderText))
                    .padding(.top, 8)
                    .padding(.leading, 5)
            }
            TextEditor(text: $text)
        }
    }
}

// ImagePicker (Helper from your old code, slightly adapted)
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary // Or .camera
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.selectedImage = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
