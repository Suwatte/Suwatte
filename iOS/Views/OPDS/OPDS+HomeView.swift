//
//  OPDSView.swift
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
    @ObservedResults(StoredOPDSServer.self, where: { $0.isDeleted == false }, sortDescriptor: .init(keyPath: "alias", ascending: true)) var servers
    var body: some View {
        List {
            ForEach(servers) { server in
                NavigationLink(server.alias) {
                    LoadableFeedView(url: server.host)
                        .environmentObject(server.toClient())
                }
                .swipeActions {
                    Button("Delete") {
                        DataManager.shared.removeOPDServer(id: server.id)
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
            NavigationView {
                AddNewServerSheet()
                    .closeButton()
            }

        })
        .navigationTitle("OPDS")
        .animation(.default, value: servers)
    }

    func renamePrompt(server: StoredOPDSServer) {
        let ac = UIAlertController(title: "Rename \(server.alias)", message: nil, preferredStyle: .alert)
        ac.addTextField()

        let submitAction = UIAlertAction(title: "Rename", style: .default) { [unowned ac] _ in
            let text = ac.textFields![0].text

            guard let text else { return }

            DataManager.shared.renameOPDSServer(id: server.id, name: text)
        }
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        ac.addAction(submitAction)
        KEY_WINDOW?.rootViewController?.present(ac, animated: true)
    }
}
