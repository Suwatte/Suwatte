//
//  OPDS+HomeView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-14.
//

import RealmSwift
import SwiftUI

struct OPDSView: View {
    @State private var presentAddNewServer = false
    @State private var presentRenameAlert = false
    @State private var server: StoredOPDSServer? = nil
    @State private var servers: [StoredOPDSServer] = []
    @State private var token: NotificationToken?
    var body: some View {
        List {
            ForEach(servers) { server in
                NavigationLink(server.alias) {
                    LoadableFeedView(url: server.host)
                        .environmentObject(server.toClient())
                }
                .swipeActions {
                    Button(role: .destructive) {
                        Task {
                            let actor = await RealmActor.shared()
                            await actor.removeOPDServer(id: server.id)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                    Button("Rename") {
                        renamePrompt(server: server)
                    }
                    .tint(.blue)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { presentAddNewServer.toggle() } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $presentAddNewServer, content: {
            SmartNavigationView {
                AddNewServerSheet()
                    .closeButton()
            }

        })
        .navigationTitle("OPDS")
        .animation(.default, value: servers)
        .task {
            await observe()
        }
        .onDisappear(perform: cancel)
    }

    @MainActor
    func renamePrompt(server: StoredOPDSServer) {
        let ac = UIAlertController(title: "Rename \(server.alias)", message: nil, preferredStyle: .alert)
        ac.addTextField()

        let submitAction = UIAlertAction(title: "Rename", style: .default) { [unowned ac] _ in
            let text = ac.textFields![0].text

            guard let text else { return }

            Task {
                let actor = await RealmActor.shared()
                await actor.renameOPDSServer(id: server.id, name: text)
            }
        }
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        ac.addAction(submitAction)
        getKeyWindow()?.rootViewController?.present(ac, animated: true)
    }
}

extension OPDSView {
    func cancel() {
        token?.invalidate()
        token = nil
    }

    func observe() async {
        let actor = await RealmActor.shared()
        token = await actor.observeOPDSServers { value in
            Task { @MainActor in
                servers = value
            }
        }
    }
}
