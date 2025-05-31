import SwiftUI

// Assuming Table and TableStatus are defined elsewhere (e.g., in Models)
// For TableTileView to be self-contained in terms of styling for this exercise,
// we ensure TableStatus properties are accessible.

// TableStatus Color/Display Extension
// This should ideally be in a global scope or part of the TableStatus model definition.
// Making it public for broader accessibility if models are in a different module.
public extension TableStatus {
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
    let table: Table // Assuming Table struct is defined globally

    var body: some View {
        VStack(spacing: 0) { // Reduced spacing to manage elements better
            // Status text at the top
            Text(table.status.displayName.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(table.status.color.opacity(0.25))
                .foregroundColor(table.status.color)
                .cornerRadius(4)
                .padding(.top, 8)

            Spacer()

            Text(table.code)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(table.status.color)
                .minimumScaleFactor(0.7) // Allow shrinking if code is long
                .lineLimit(1)

            Text("Capacity: \(table.capacity)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(table.status.color.opacity(0.8))

            Spacer()
        }
        .frame(width: 150, height: 110) // Standardized height
        .background(table.status.backgroundColor)
        .cornerRadius(12)
        .shadow(color: table.status.color.opacity(0.3), radius: 4, x: 0, y: 2)
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
                    TableTileView(table: table)
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}
#endif
*/
