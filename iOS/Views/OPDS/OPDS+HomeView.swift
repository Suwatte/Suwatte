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
    
    @FetchRequest(fetchRequest: CDOServer.orderedFetch(), animation: .default)
    private var servers: FetchedResults<CDOServer>
    
    var body: some View {
        List {
            ForEach(servers) { server in
                NavigationLink(server.alias) {
                    LoadableFeedView(url: server.host)
                        .environmentObject(server.toClient())
                }
                .swipeActions {
                    Button("Delete") {
                        CDOServer.remove(server)
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
        .navigationTitle("OPDS Servers")
    }

    @MainActor
    func renamePrompt(server: CDOServer) {
        let ac = UIAlertController(title: "Rename \(server.alias)", message: nil, preferredStyle: .alert)
        ac.addTextField()

        let submitAction = UIAlertAction(title: "Rename", style: .default) { [unowned ac] _ in
            let text = ac.textFields![0].text

            guard let text else { return }
            CDOServer.rename(server, name: text)
        }
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        ac.addAction(submitAction)
        getKeyWindow()?.rootViewController?.present(ac, animated: true)
    }
}
