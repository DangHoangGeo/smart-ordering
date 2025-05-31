//
//  TableTileView.swift
//  smart-ordering
//
//  Created by Dang Hoang on 2025/05/31.
//

import SwiftUI

struct TableTileView: View {
    let table: Table

    var body: some View {
        VStack(alignment: .center) {
            Text(table.code)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.bottom, 5)

            if table.capacity > 0 {
                Text("Capacity: \(table.capacity)")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
        }
        .frame(width: 150, height: 100) // Fixed size for tiles
        .background(table.status.backgroundColor)
        .cornerRadius(15)
        .shadow(radius: 5)
        .padding(5) // Spacing between tiles
    }
}

struct TableTileView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TableTileView(table: Table(restaurantId: "rest1", code: "T01", capacity: 4, status: .available))
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Available Table")

            TableTileView(table: Table(restaurantId: "rest1", code: "T02", capacity: 2, status: .occupied))
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Occupied Table")

            TableTileView(table: Table(restaurantId: "rest1", code: "T03", capacity: 6, status: .reserved))
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Reserved Table")

            TableTileView(table: Table(restaurantId: "rest1", code: "T04", capacity: 4, status: .needsCleaning))
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Needs Cleaning Table")

            TableTileView(table: Table(restaurantId: "rest1", code: "T05", capacity: 0, status: .outOfService))
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Out of Service Table (No Capacity)")
        }
    }
}
