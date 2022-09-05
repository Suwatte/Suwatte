//
//  OPDS+AddServer.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-14.
//

import SwiftUI

extension OPDSView {
    struct AddNewServerSheet: View {
        @State var entry: NewServer = .init()
        @Environment(\.presentationMode) var presentationMode
        @StateObject var toastManager = ToastManager()
        @FocusState private var isFocused: Bool
        var body: some View {
            List {
                Section {
                    HStack(alignment: .center, spacing: 0) {
                        Text("Alias: ")
                        TextField("Alias", text: $entry.alias, prompt: Text("My Definitely Legal Comic Server"))
                            .autocapitalization(.none)
                    }
                    HStack(alignment: .center, spacing: 0) {
                        Text("Host: ")
                        TextField("Host", text: $entry.host, prompt: Text("https://media.mantton.com/opds"))
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                            .focused($isFocused)
                            .onChange(of: isFocused) { isFocused in
                                if isFocused, entry.host.isEmpty {
                                    entry.host = "https://"
                                }
                            }
                    }
                } header: {
                    Text("Server Info")
                }

                Section {
                    HStack(alignment: .center, spacing: 0) {
                        Text("Username: ")
                        TextField("Username", text: $entry.userName, prompt: Text("JackAppleSeed"))
                            .autocapitalization(.none)
                    }
                    HStack(alignment: .center, spacing: 0) {
                        Text("Password: ")
                        SecureField("Password", text: $entry.password, prompt: Text("JackAppleTree"))
                            .autocapitalization(.none)
                    }

                } header: {
                    Text("Authentication")
                }
            }
            .toast(isPresenting: $toastManager.show, alert: {
                toastManager.toast
            })
            .font(.subheadline.weight(.light))
            .navigationTitle("Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard serverURL != nil else {
                            return
                        }

                        let auth = hasAuthentication ? (entry.userName, entry.password) : nil
                        let client = OPDSClient(base: entry.host, auth: auth)
                        // Test
                        Task { @MainActor in
                            do {
                                let _ = try await client.getFeed(url: entry.host)

                                // Save
                                DataManager.shared.saveNewOPDSServer(entry: entry)
                                // Dismiss
                                presentationMode.wrappedValue.dismiss()

                            } catch {
                                toastManager.setError(msg: "Server Connection Failed")
                                print(error)
                            }
                        }
                    }
                    .disabled(!isValidInput)
                }
            }
        }

        var isValidInput: Bool {
            !entry.alias.isEmpty && !entry.host.isEmpty && serverURL != nil
        }

        var hasAuthentication: Bool {
            !entry.password.isEmpty || !entry.userName.isEmpty
        }

        var serverURL: URL? {
            URL(string: "\(entry.host)")
        }
    }
}

extension OPDSView.AddNewServerSheet {
    struct NewServer {
        var alias: String = ""
        var host: String = ""
        var userName: String = ""
        var password: String = ""
    }
}
