//
//  RunnerInfoView.swift
//  Suwatte
//
//  Created by Mantton on 2023-12-18.
//

import SwiftUI


struct RunnerInfoView : View {
    let runner: Runner
    let list: (info: RunnerList, url: String)
    let state: RunnerInstallationState = .notInstalled
    @State private var isLoading = false

    var body: some View {
        HStack {
            CoreBody
            Spacer()
            Button {
                install()
            } label: {
                ZStack {
                    if !isLoading {
                        Text(state.description)
                    } else {
                        ProgressView()
                    }
                }
                .font(.footnote.weight(.bold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(state.noInstall)
        }
    }
}


extension RunnerInfoView {

    var CoreBody: some View {
        HStack(spacing: 7) {
            STTThumbView(url: thumbnail)
                .frame(width: 44, height: 44, alignment: .center)
                .cornerRadius(7)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .bottom, spacing: 3.5) {
                    Text(runner.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("v\(runner.version.description)")
                        .font(.subheadline)
                        .fontWeight(.thin)
                }
                HStack {
                    if runner.rating == .NSFW {
                        Text("NSFW")
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .background(Color.red.opacity(0.3))
                            .cornerRadius(5)
                    }

                    if runner.rating == .MIXED {
                        Text("Suggestive")
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .background(Color.yellow.opacity(0.3))
                            .cornerRadius(5)
                    }
                }
                .font(.footnote.weight(.light))
            }
        }
        .frame(height: 60, alignment: .center)
    }
}


extension RunnerInfoView {
    
    var thumbnail: URL? {
        runner.thumbnail.flatMap {
            URL(string: list.url)?
            .appendingPathComponent("assets")
            .appendingPathComponent($0)
        }
    }
    
    
    func install() {
        isLoading = true
        Task { @MainActor in
            defer {
                isLoading = false
            }
            
            let base = URL(string: list.url)
            guard let base else { return }

            do {
                try await DSK.shared.importRunner(from: base, with: runner.id)
                ToastManager.shared.info("\(runner.name) Saved!")
            } catch {
                ToastManager.shared.display(.error(error))
            }
        }
    }
}
