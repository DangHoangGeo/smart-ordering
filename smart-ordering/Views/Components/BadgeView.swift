import SwiftUI

struct BadgeView: View {
    let count: Int
    var backgroundColor: Color = .red
    var textColor: Color = .white

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption.bold()) // Ensure good font size
                .accessibilityLabel("\(count) new items")
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(backgroundColor)
                .foregroundColor(textColor) // Ensure good color contrast
                .clipShape(Capsule())
        } else {
            EmptyView()
        }
    }
}

struct BadgeView_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            BadgeView(count: 5)
            BadgeView(count: 0)
            BadgeView(count: 12, backgroundColor: .blue, textColor: .yellow)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
