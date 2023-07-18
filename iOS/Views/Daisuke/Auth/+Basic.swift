//
//  +Basic.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-07.
//

import SwiftUI

extension DSKAuthView {
    struct BasicAuthView: View {
        @State var presentSheet = false
        @EnvironmentObject var model: DSKAuthView.ViewModel

        var body: some View {
            Button {
                presentSheet.toggle()
            } label: {
                Label("Sign In", systemImage: "person.fill.viewfinder")
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $presentSheet, onDismiss: model.load) {
                SignInSheet()
            }
        }
    }
}


extension DSKAuthView.BasicAuthView {
    struct SignInSheet: View {
        
        @State var username: String = ""
        @State var password: String = ""
        @State var loginStatus: Loadable<Bool> = .idle
        @Environment(\.presentationMode) var presentationMode
        @EnvironmentObject var model: DSKAuthView.ViewModel
        @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault
        @Preference(\.accentColor) var color

        var usesEmail: Bool {
            model.runner.intents.basicAuthLabel == .EMAIL
        }
        
        var ThumbnailView : some View {
            Group {
                if let url = model.runner.thumbnailURL {
                    BaseImageView(url: url)

                } else {
                    Image("stt")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(color)
                        .padding(.all, 3)
                }
            }
            .frame(height: 75, alignment: .center)
            .clipShape(Circle())
            .padding()
        }
        var body: some View {
            NavigationView {
                VStack {
                    ThumbnailView
                    Text("Sign In to \(model.runner.name)")
                        .font(.title)
                        .fontWeight(.semibold)
                        .kerning(1.5)
                        .padding()
                    
                    EmailField
                    PasswordField
                    
                    if loginStatus.error != nil {
                        AuthFailed
                            .padding(.horizontal)
                    }
                    LoginButton
                    Spacer()
                }
                .frame(maxWidth: UIScreen.main.bounds.width)
                .padding()
                .navigationTitle("Sign In")
                .closeButton()
                .tint(accentColor)
                .accentColor(accentColor)
            }
        }
        
        // MARK: Views
        
        var EmailField: some View {
            HStack(spacing: 10) {
                Image(systemName: "person")
                    .font(.title2)
                    .foregroundColor(.primary.opacity(0.4))
                    .frame(width: 15, alignment: .center)
                TextField(usesEmail ? "Email" : "Username", text: $username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.emailAddress)
            }
            .padding()
            .background(Color.primary.opacity(0.12))
            .cornerRadius(15)
            .padding(.horizontal)
        }
        
        var PasswordField: some View {
            HStack(spacing: 10) {
                Image(systemName: "lock")
                    .font(.title2)
                    .foregroundColor(.primary.opacity(0.4))
                    .frame(width: 15, alignment: .center)
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
            .padding()
            .background(Color.primary.opacity(0.12))
            .cornerRadius(15)
            .padding(.horizontal)
            .padding(.top)
        }
        
        var LoginButton: some View {
            Button {
                signIn()
            } label: {
                ZStack {
                    if loginStatus == .loading {
                        ProgressView()
                    } else {
                        Text("Sign In")
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                    }
                }
                
                .padding(.vertical)
                .frame(width: 250)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
            .disabled(!isValidInput || loginStatus == .loading)
            .padding(.top)
        }
        
        var AuthFailed: some View {
            HStack {
                Image(systemName: "exclamationmark.circle")
                Text("Failed to Sign In")
            }
            .foregroundColor(.red)
        }
        
        // MARK: Functions
        
        func validatePassword() -> Bool {
            return true
        }
        
        var isValidInput: Bool {
            if !username.isEmpty && !password.isEmpty && validatePassword() { return true }
            return false
        }
        
        func signIn() {
            loginStatus = .loading
            Task { @MainActor in
                do {
                    try await model.runner.handleBasicAuthentication(id: username, password: password)
                    presentationMode.wrappedValue.dismiss()
                } catch {
                    self.loginStatus = .failed(error)
                    Logger.shared.error("\(error)")
                    ToastManager.shared.error("Failed to Sign In: \(error.localizedDescription)")
                }
            }
        }
    }

}
