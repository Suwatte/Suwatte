//
//  LCV+Download.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-07.
//

import SwiftUI

struct LCV_Download: View {
    @StateObject var manager: LocalContentManager = .shared
    var body: some View {
        NavigationView {
            
            
        }
        .closeButton()
        .navigationTitle("Local Downloads")
        .navigationBarTitleDisplayMode(.inline)
        
    }
}

