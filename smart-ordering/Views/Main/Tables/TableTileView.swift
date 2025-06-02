import SwiftUI

// Assuming Table and TableStatus are defined elsewhere (e.g., in Models)
// For TableTileView to be self-contained in terms of styling for this exercise,
// we ensure TableStatus properties are accessible.

// TableStatus Color/Display Extension
// This should ideally be in a global scope or part of the TableStatus model definition.
// Making it public for broader accessibility if models are in a different module.
extension TableStatus {
    var color: Color { // Text color for status
        switch self {
        case .available: return .green
        case .occupied: return .red
        case .reserved: return .orange
        // Using systemOrange for better visibility of text compared to systemYellow
        case .needsCleaning: return Color(UIColor.systemOrange)
        case .outOfService: return .gray
        }
    }

    var backgroundColor: Color { // Background for the tile itself
        switch self {
        case .available: return Color.green.opacity(0.15)
        case .occupied: return Color.red.opacity(0.15)
        case .reserved: return Color.orange.opacity(0.15)
        case .needsCleaning: return Color(UIColor.systemOrange).opacity(0.15)
        case .outOfService: return Color.gray.opacity(0.15)
        }
    }

    var displayName: String { // User-friendly status name
        switch self {
        case .available: return "Available"
        case .occupied: return "Occupied"
        case .reserved: return "Reserved"
        case .needsCleaning: return "Cleaning" // Shorter for tile
        case .outOfService: return "Out of Service"
        }
    }
}


struct TableTileView: View {
    let table: Table
    let isSelected: Bool
    let onTap: () -> Void
    @State private var hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    private var statusIcon: String {
        switch table.status {
        case TableStatus.available:
            return "checkmark.circle.fill"
        case TableStatus.occupied:
            return "person.2.fill"
        case TableStatus.reserved:
            return "calendar.badge.clock"
        case TableStatus.needsCleaning:
            return "sparkles"
        case TableStatus.outOfService:
            return "xmark.circle.fill"
        }
    }
    
    private var statusText: String {
        switch table.status {
        case TableStatus.available:
            return "Available"
        case TableStatus.occupied:
            return "Occupied"
        case TableStatus.reserved:
            return "Reserved"
        case TableStatus.needsCleaning:
            return "Needs Cleaning"
        case TableStatus.outOfService:
            return "Out of Service"
        }
    }
    
    var body: some View {
        Button(action: {
            hapticFeedback.impactOccurred()
            onTap()
        }) {
            VStack(spacing: 12) {
                // Status Icon
                ZStack {
                    Circle()
                        .fill(AppConfig.Colors.tableStatusColor(table.status.rawValue, opacity: 0.2))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: statusIcon)
                        .font(.system(size: 24))
                        .foregroundColor(AppConfig.Colors.tableStatusColor(table.status.rawValue))
                }
                
                VStack(spacing: 4) {
                    Text(table.code)
                        .font(.headline)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                        .foregroundColor(AppConfig.Colors.text)
                    
                    Text("\(table.capacity) guests")
                        .font(.subheadline)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .foregroundColor(AppConfig.Colors.secondaryText)
                    
                    Text(statusText)
                        .font(.caption)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .foregroundColor(AppConfig.Colors.tableStatusColor(table.status.rawValue))
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppConfig.Colors.background)
                    .shadow(
                        color: isSelected ? 
                            AppConfig.Colors.primary.opacity(0.3) : 
                            AppConfig.Colors.text.opacity(0.05),
                        radius: isSelected ? 6 : 3,
                        y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? AppConfig.Colors.primary : Color.clear,
                        lineWidth: isSelected ? 2 : 0
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(table.status == TableStatus.outOfService)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(buildAccessibilityLabel())
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(table.status == TableStatus.outOfService ? 
            "Table is out of service" : 
            "Double tap to \(isSelected ? "deselect" : "select") table")
    }
    
    private func buildAccessibilityLabel() -> String {
        var components = [
            "Table \(table.code)",
            "\(table.capacity) guests",
            statusText
        ]
        
        if isSelected {
            components.append("Selected")
        }
        
        return components.joined(separator: ", ")
    }
}

// Example Table struct for previewing TableTileView,
// if not available globally or for isolated testing.
/*
#if DEBUG
struct Table: Identifiable, Codable, Hashable, Equatable, Comparable {
    public static func < (lhs: Table, rhs: Table) -> Bool {
        lhs.code < rhs.code
    }

    var id: String? = UUID().uuidString
    var code: String
    var capacity: Int
    var status: TableStatus = .available
    var restaurantId: String?
    var currentOrderId: String?
    var lastUpdatedAt: Date?
    var createdAt: Date?
    var section: String? // e.g., "Main Dining", "Patio"
    var displayOrder: Int? // For ordering within a section
}

enum TableStatus: String, CaseIterable, Codable, Hashable, Identifiable {
    case available, occupied, reserved, needsCleaning, outOfService
    var id: String { self.rawValue }
}

struct TableTileView_Previews: PreviewProvider {
    static var previews: some View {
        let tables = [
            Table(id: "1", code: "T1", capacity: 4, status: .available, restaurantId: "previewResto"),
            Table(id: "2", code: "T200", capacity: 2, status: .occupied, restaurantId: "previewResto"),
            Table(id: "3", code: "Bar 5", capacity: 6, status: .reserved, restaurantId: "previewResto"),
            Table(id: "4", code: "P1A", capacity: 4, status: .needsCleaning, restaurantId: "previewResto"),
            Table(id: "5", code: "XXL", capacity: 12, status: .outOfService, restaurantId: "previewResto")
        ]

        return ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                ForEach(tables) { table in
                    TableTileView(
                        table: table,
                        isSelected: false,
                        onTap: { }
                    )
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}
#endif
*/
