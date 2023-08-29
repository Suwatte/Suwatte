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
                        TextField("Host", text: $entry.host, prompt: Text("https://"))
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
            .toast()
            .font(.subheadline.weight(.light))
            .navigationTitle("Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        guard serverURL != nil else {
                            return
                        }

                        ToastManager.shared.loading = true

                        let auth = hasAuthentication ? (entry.userName, entry.password) : nil
                        let client = OPDSClient(id: "", base: entry.host, auth: auth) // client only used to test if server works
                        // Test
                        Task {
                            do {
                                let _ = try await client.getFeed(url: entry.host)

                                // Save
                                let actor = await RealmActor.shared()
                                await actor.saveNewOPDSServer(entry: entry)
                                // Dismiss
                                presentationMode.wrappedValue.dismiss()

                            } catch {
                                ToastManager.shared.error("Server Connection Failed")
                                Logger.shared.error("[OPDS] \(error.localizedDescription)")
                            }
                            ToastManager.shared.loading = false
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
