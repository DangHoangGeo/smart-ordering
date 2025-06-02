import SwiftUI

struct EmptyStateView: View {
    let searchText: String
    let section: String?
    let iconName: String
    let message: String?
    
    init(searchText: String = "", section: String? = nil, iconName: String = "magnifyingglass", message: String? = nil) {
        self.searchText = searchText
        self.section = section
        self.iconName = iconName
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 40))
                .foregroundColor(AppConfig.Colors.secondaryText)
            
            if !searchText.isEmpty {
                Text("No items match '\(searchText)'")
                    .font(.headline)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .foregroundColor(AppConfig.Colors.text)
                if let section = section {
                    Text("in \(section)")
                        .foregroundColor(AppConfig.Colors.secondaryText)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                }
            } else if let section = section {
                Text("No items in \(section)")
                    .font(.headline)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .foregroundColor(AppConfig.Colors.text)
            } else if let message = message {
                Text(message)
                    .font(.headline)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .foregroundColor(AppConfig.Colors.text)
            } else {
                Text("No items available")
                    .font(.headline)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .foregroundColor(AppConfig.Colors.text)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CategoryPill: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AppConfig.Colors.primary : AppConfig.Colors.secondaryBackground)
                .foregroundColor(isSelected ? .white : AppConfig.Colors.text)
                .cornerRadius(16)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Selected category" : "Double tap to select category")
    }
}

struct MenuItemRow: View {
    let item: MenuItem
    let quantity: Int?
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Item Image or Icon
                Group {
                    if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            case .failure:
                                Image(systemName: "fork.knife.circle.fill")
                                    .foregroundColor(.secondary)
                                    .imageScale(.large)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Image(systemName: "fork.knife.circle.fill")
                            .foregroundColor(.secondary)
                            .imageScale(.large)
                    }
                }
                .frame(width: 60, height: 60)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    if let nameJP = item.nameJP {
                        Text(nameJP)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    }
                    Text("¥\(Int(item.price))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                }
                
                Spacer()
                
                if let qty = quantity {
                    HStack(spacing: 4) {
                        Text("\(qty)×")
                            .font(.system(.headline, design: .rounded))
                            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .imageScale(.large)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: quantity != nil ? .blue.opacity(0.2) : .black.opacity(0.05),
                           radius: quantity != nil ? 4 : 2,
                           y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(quantity != nil ? Color.blue.opacity(0.3) : Color.clear,
                           lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}