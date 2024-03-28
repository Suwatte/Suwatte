//
//  RunnerListInfoView.swift
//  Suwatte
//
//  Created by Mantton on 2023-12-18.
//

import SwiftUI

struct RunnerListInfoView : View {
    let list: RunnerList
    let url: String
    @State private var query = ""
    
    var body: some View {
        List {
            
            Section {
                ForEach(sources) { runner in
                   RunnerInfoView(runner: runner, list: (list, url))
                }
            } header: {
                Text("Sources")
            }
            
            
            Section {
                ForEach(trackers) { runner in
                    RunnerInfoView(runner: runner, list: (list, url))
                }
            } header: {
                Text("Trackers")
            }
        }
    }
}



extension RunnerListInfoView {
    private var sources : [Runner] {
        list.runners.filter { $0.environment == .source }
    }
    
    private var trackers : [Runner] {
        list.runners.filter { $0.environment == .tracker }
    }
}


enum RunnerInstallationState {
    case installed, outdated, sourceOutdated, notInstalled, appOutDated

    var description: String {
        switch self {
        case .installed:
            return "REFRESH"
        case .outdated:
            return "UPDATE"
        case .sourceOutdated:
            return "OUTDATED"
        case .notInstalled:
            return "GET"
        case .appOutDated:
            return "UPDATE APP"
        }
    }

    var noInstall: Bool {
        self == .appOutDated || self == .sourceOutdated
    }
}
