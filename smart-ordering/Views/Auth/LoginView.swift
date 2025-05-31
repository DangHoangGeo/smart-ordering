// Views/Auth/LoginView.swift
import SwiftUI
import GoogleSignInSwift

struct LoginView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @EnvironmentObject var appSettings: AppSettings // Get from environment

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSigningUp = false
    @State private var showForgotPasswordSheet = false

    // Define colors for easy reuse and theming
    let primaryColor = Color.blue
    let accentColor = Color.green // Or your app's accent
    let backgroundColor = Color(UIColor.systemGroupedBackground) // Adapts to light/dark
    let textFieldBackgroundColor = Color(UIColor.systemBackground)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background (optional, could be a subtle gradient or image)
                // For simplicity, using system grouped background
                backgroundColor.edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(spacing: 0) { // Reduced spacing for tighter grouping
                        
                        // Logo and App Name
                        VStack {
                            Image("app_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: .gray.opacity(0.4), radius: 5, y: 5)
                                .padding(.top, geometry.safeAreaInsets.top + 20) // Adjust top padding

                            Text("Smart Ordering")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(primaryColor)
                                .padding(.top, 10)
                            
                            Text(isSigningUp ? "Create your account" : "Welcome back!")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 30)
                        }

                        // Form Fields
                        VStack(spacing: 15) {
                            CustomTextField(placeholder: "Email", text: $email, systemImageName: "envelope.fill")
                                .keyboardType(.emailAddress)
                            
                            CustomSecureField(placeholder: "Password", text: $password, systemImageName: "lock.fill")
                            
                            if isSigningUp {
                                CustomSecureField(placeholder: "Confirm Password", text: $confirmPassword, systemImageName: "lock.fill")
                            }
                        }
                        .padding(.horizontal, 30)

                        // Error/Success Message Display
                        messageDisplayArea
                            .padding(.horizontal, 30)
                            .padding(.top, 10)

                        // Action Buttons
                        VStack(spacing: 15) {
                            if userViewModel.isLoadingAuthState {
                                ProgressView()
                                    .padding(.vertical)
                            } else {
                                primaryActionButton
                                
                                if !isSigningUp {
                                    forgotPasswordButton
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 25)

                        // "OR" Separator
                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.vertical, 20)

                        // Google Sign-In Button
                        googleSignInButton
                            .padding(.horizontal, 30)
                        
                        // Demo Mode Toggle (Consider moving to a settings screen for production)
                        if AppConfig.shared.environment == .debug || appSettings.isDemoMode { // Show only in debug or if demo is already on
                             Toggle("Demo Mode", isOn: $appSettings.isDemoMode)
                                 .padding(.horizontal, 30)
                                 .padding(.top, 20)
                                 .tint(accentColor)
                        }


                        Spacer(minLength: 20) // Ensure some space at the bottom
                        
                        // Toggle Sign Up/Login
                        toggleAuthModeButton
                            .padding(.bottom, geometry.safeAreaInsets.bottom + 20) // Adjust bottom padding

                    }
                    .frame(minHeight: geometry.size.height) // Ensure content can fill screen
                }
            }
            .onTapGesture { hideKeyboard() }
            .sheet(isPresented: $showForgotPasswordSheet) {
                ForgotPasswordSheet(emailInitial: email) // Pass initial email
                    .environmentObject(userViewModel) // Ensure VM is passed
            }
        }
    }

    // MARK: - Subviews
    
    private var messageDisplayArea: some View {
        Group {
            if let errorMessage = userViewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 30) // Reserve space
            } else if let successMessage = userViewModel.successMessage {
                Text(successMessage)
                    .font(.footnote)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 30) // Reserve space
            } else {
                Spacer().frame(minHeight: 30) // Reserve space if no message
            }
        }
    }

    private var primaryActionButton: some View {
        Button(action: {
            hideKeyboard()
            userViewModel.errorMessage = nil // Clear previous errors
            userViewModel.successMessage = nil
            Task {
                if isSigningUp {
                    guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
                        userViewModel.errorMessage = "All fields are required for sign up."
                        return
                    }
                    guard password == confirmPassword else {
                        userViewModel.errorMessage = "Passwords do not match."
                        return
                    }
                    await userViewModel.signUpWithEmail(email: email, password: password)
                } else {
                     guard !email.isEmpty, !password.isEmpty else {
                        userViewModel.errorMessage = "Email and password are required."
                        return
                    }
                    await userViewModel.signInWithEmail(email: email, password: password)
                }
            }
        }) {
            Text(isSigningUp ? "Sign Up" : "Log In")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.white)
                .background(primaryColor)
                .cornerRadius(12)
                .shadow(color: primaryColor.opacity(0.3), radius: 5, y: 3)
        }
    }
    
    private var forgotPasswordButton: some View {
        Button("Forgot Password?") {
            hideKeyboard()
            showForgotPasswordSheet = true
        }
        .font(.footnote)
        .foregroundColor(primaryColor)
    }

    private var googleSignInButton: some View {
        GoogleSignInButton(scheme: .light, style: .standard, state: .normal) {
            hideKeyboard()
            userViewModel.errorMessage = nil
            userViewModel.successMessage = nil
            Task {
                guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {
                    userViewModel.errorMessage = "Could not find presenting view controller for Google Sign-In."
                    return
                }
                await userViewModel.signInWithGoogle(presentingViewController: presentingViewController)
            }
        }
        .frame(height: 48)
        .shadow(color: .gray.opacity(0.3), radius: 3, y: 2)
    }

    private var toggleAuthModeButton: some View {
        Button(action: {
            isSigningUp.toggle()
            userViewModel.errorMessage = nil
            userViewModel.successMessage = nil
            // Consider clearing email/password fields or not, based on UX preference
            // email = ""
            // password = ""
            confirmPassword = ""
        }) {
            HStack(spacing: 4) {
                Text(isSigningUp ? "Already have an account?" : "Don't have an account?")
                Text(isSigningUp ? "Log In" : "Sign Up")
                    .fontWeight(.semibold)
                    .foregroundColor(primaryColor)
            }
            .font(.footnote)
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


// MARK: - Custom Text Field Components

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    let systemImageName: String?
    var isSecure: Bool = false

    var body: some View {
        HStack {
            if let systemImageName = systemImageName {
                Image(systemName: systemImageName)
                    .foregroundColor(.gray)
                    .frame(width: 20) // Consistent icon width
            }
            TextField(placeholder, text: $text)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground)) // More subtle background
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 2, y: 1) // Subtle shadow
    }
}

struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String
    let systemImageName: String?

    var body: some View {
        HStack {
            if let systemImageName = systemImageName {
                Image(systemName: systemImageName)
                    .foregroundColor(.gray)
                    .frame(width: 20)
            }
            SecureField(placeholder, text: $text)
                .textContentType(.newPassword) // Helps with password managers
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 2, y: 1)
    }
}

// MARK: - Forgot Password Sheet

struct ForgotPasswordSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userViewModel: UserViewModel
    @State var emailInitial: String // Passed from LoginView

    @State private var emailForReset: String = ""
    
    init(emailInitial: String) {
        _emailInitial = State(initialValue: emailInitial)
        _emailForReset = State(initialValue: emailInitial) // Initialize with potentially passed email
    }


    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Reset Password")
                    .font(.largeTitle.bold())
                    .padding(.top)

                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                CustomTextField(placeholder: "Email", text: $emailForReset, systemImageName: "envelope.fill")
                    .keyboardType(.emailAddress)

                if userViewModel.isLoadingAuthState {
                    ProgressView()
                } else {
                    Button("Send Reset Link") {
                        hideKeyboard()
                        guard !emailForReset.isEmpty else {
                            userViewModel.errorMessage = "Please enter your email."
                            return
                        }
                        Task {
                            await userViewModel.sendPasswordReset(email: emailForReset)
                            // Optionally dismiss after a short delay if successful
                            // if userViewModel.errorMessage == nil {
                            //    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
                            // }
                        }
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                if let errorMessage = userViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                if let successMessage = userViewModel.successMessage {
                    Text(successMessage)
                        .font(.footnote)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                }


                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .onAppear {
                 // Clear messages when sheet appears
                 userViewModel.errorMessage = nil
                 userViewModel.successMessage = nil
            }
            .onTapGesture { hideKeyboard() }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


// MARK: - Preview

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(UserViewModel())
            .environmentObject(AppSettings()) // Provide AppSettings for preview
    }
}
