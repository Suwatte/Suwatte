//
//  OPDSView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-14.
//

import RealmSwift
import SwiftUI

struct OPDSView: View {
    @State var presentAddNewServer = false
    @ObservedResults(StoredOPDSServer.self) var servers
    var body: some View {
        List {
            ForEach(servers) { server in
                NavigationLink(server.alias) {
                    LoadableFeedView(url: server.host)
                        .environmentObject(server.toClient())
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
    }
}
