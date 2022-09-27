//
//  DRV+Auth.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-11.
//

import RealmSwift
import SwiftUI

extension DaisukeContentSourceView {
    struct AuthSection: View {
        var authMethod: DSKCommon.AuthMethod
        var canSync: Bool
        @State var loadable = Loadable<DSKCommon.User?>.idle
        @EnvironmentObject var source: DaisukeEngine.ContentSource
        @State var presentBasicAuthSheet = false
        @State var shouldRefresh = false
        var body: some View {
            LoadableView(loadable: loadable) {
                ProgressView()
                    .task {
                        await load()
                    }
            } _: {
                ProgressView()
            } _: { error in
                HStack {
                    Spacer()
                    ErrorView(error: error) {
                        Task {
                            await load()
                        }
                    }
                    Spacer()
                }

            } _: { value in
                if let user = value {
                    LoadedUserView(user: user)
                } else {
                    LoadedNoUserView()
                }
            }
            .sheet(isPresented: $presentBasicAuthSheet, onDismiss: { shouldRefresh.toggle() }) {
                NavigationView {
                    SignInSheet(usesEmail: authMethod == .email_pw)
                        .navigationTitle("Sign In")
                        .closeButton()
                }
            }
            .animation(.default, value: loadable)
            .onChange(of: shouldRefresh) { _ in
                if shouldRefresh {
                    loadable = .idle
                }
            }
        }

        func load() async {
            shouldRefresh = false
            await MainActor.run(body: {
                loadable = .loading
            })
            do {
                let data = try await source.getAuthenticatedUser()
                await MainActor.run(body: {
                    loadable = .loaded(data)
                })
            } catch {
                await MainActor.run(body: {
                    loadable = .failed(error)
                })
            }
        }

        @ViewBuilder
        func LoadedUserView(user: DSKCommon.User) -> some View {
            AuthenticatedUserView(shouldRefresh: $shouldRefresh, canSync: canSync, user: user)
        }

        func LoadedNoUserView() -> some View {
            Section {
                Button {
                    switch authMethod {
                    case .email_pw, .username_pw:
                        presentBasicAuthSheet.toggle()
                    case .oauth:
                        break
                    case .web: break
                    }
                } label: {
                    Label("Sign In", systemImage: "person.fill.viewfinder")
                }
                .buttonStyle(.plain)
            } header: {
                Text("Authentication")
            }
        }
    }
}

extension DaisukeContentSourceView {
    struct SignInSheet: View {
        var usesEmail: Bool
        @State var username: String = ""
        @State var password: String = ""
        @State var loginStatus: Loadable<Bool> = .idle
        @Environment(\.presentationMode) var presentationMode
        @EnvironmentObject var source: DaisukeEngine.ContentSource

        var body: some View {
            VStack {
                Image("stt_icon")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 75, alignment: .center)
                    .clipShape(Circle())
                    .padding()
                Text("Sign In to \(source.name)")
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
                    try await source.handleBasicAuth(id: username, password: password)
                    presentationMode.wrappedValue.dismiss()
                } catch {
                    self.loginStatus = .failed(error)
                }
            }
        }
    }
}

extension DaisukeContentSourceView {
    struct AuthenticatedUserView: View {
        @EnvironmentObject var source: DaisukeEngine.ContentSource
        @Binding var shouldRefresh: Bool
        var canSync: Bool
        var user: DSKCommon.User
        @State var presentShouldSync = false
        var body: some View {
            HStack(alignment: .center) {
                BaseImageView(url: URL(string: user.avatar ?? ""))
                    .background(.gray)
                    .clipShape(Circle())
                    .frame(width: 75, height: 75)
                    .padding(.all, 7)

                Text(user.username)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            if let info = user.info {
                Section {
                    InteractiveTagView(info) { tag in
                        Text(tag)
                            .modifier(ProfileTagStyle())
                    }
                } header: {
                    Text("Info")
                }
            }
            Section {
                Button {
                    presentShouldSync.toggle()
                } label: {
                    Label("Sync Library", systemImage: "tray.and.arrow.down.fill")
                }
                .buttonStyle(.plain)
            } header: {
                Text("Sync")
            }
            .alert("Sync Library", isPresented: $presentShouldSync, actions: {
                Button("Cancel", role: .cancel) {}
                Button("Proceed") {
                    Task {
                        do {
                            try await handleContentSync()
                        } catch {
                            await MainActor.run(body: {
                                ToastManager.shared.setError(error: error)
                            })
                        }
                    }
                }
            }, message: {
                Text("Are you sure you want to sync your \(source.name) library?")
            })

            Section {
                Button("Sign Out", role: .destructive) {
                    Task {
                        do {
                            try await source.handleUserSignOut()
                        } catch {
                            ToastManager.shared.setError(error: error)
                        }
                        await MainActor.run(body: {
                            shouldRefresh.toggle()
                        })
                    }
                }
            }
        }

        func handleContentSync() async throws {
            // Set Loading
            await MainActor.run(body: {
                ToastManager.shared.setLoading()
            })

            // Get Sync Object
            let library = try await source.getUserLibrary()

            // Add Synced Objects
            let realm = try Realm(queue: nil)
            try! realm.safeWrite {
                for entry in library {
                    let target = realm.objects(LibraryEntry.self).where { $0.content.contentId == entry.id && $0.content.sourceId == source.id }.first

                    if let target = target {
                        target.flag = entry.readingFlag
                    } else {
                        var currentStored = realm.objects(StoredContent.self).where { $0.contentId == entry.id && $0.sourceId == source.id }.first
                        if currentStored == nil {
                            currentStored = StoredContent()
                            currentStored?._id = "\(source.id)||\(entry.id)"
                            currentStored?.contentId = entry.id
                            currentStored?.sourceId = source.id
                            currentStored?.title = entry.title
//                            currentStored?.cover = entry
                        }
                        guard let currentStored = currentStored else {
                            return
                        }

                        realm.add(currentStored, update: .modified)
                        let libraryObject = LibraryEntry()
                        libraryObject.content = currentStored
                        libraryObject.flag = entry.readingFlag
                        realm.add(libraryObject)
                    }
                }
            }

            await MainActor.run(body: {
                ToastManager.shared.setComplete(title: "Synced")
            })
        }
    }
}
