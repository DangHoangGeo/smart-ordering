import SwiftUI

enum ToastType {
    case info, success, error
}

struct ToastView: View {
    let message: String
    let type: ToastType
    @Binding var isShowing: Bool

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: iconName)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(radius: 5)
            .padding(.bottom, 20) // Consistent padding from the bottom
            .padding(.horizontal)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear(perform: setupAutoDismiss)
        }
    }

    private var backgroundColor: Color {
        switch type {
        case .info:
            return Color.blue.opacity(0.9)
        case .success:
            return Color.green.opacity(0.9)
        case .error:
            return Color.red.opacity(0.9)
        }
    }

    private var iconName: String {
        switch type {
        case .info:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }

    private func setupAutoDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { // Auto-dismiss after 3 seconds
            withAnimation {
                isShowing = false
            }
        }
    }
}

struct ToastView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            ToastView(message: "This is a success message!", type: .success, isShowing: .constant(true))
            ToastView(message: "Something went wrong.", type: .error, isShowing: .constant(true))
            ToastView(message: "Just some info.", type: .info, isShowing: .constant(true))
        }
    }
}
