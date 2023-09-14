//
//  ImageSearchView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-22.
//

import SafariServices
import SwiftUI

struct ImageSearchView: View {
    @ObservedObject var toastManager = ToastManager.shared
    @State var image: UIImage?
    @State var presentImagePicker = false
    @State var response = Loadable<SauceNao.Response>.idle
    var body: some View {
        ZStack {
            if let image = image {
                IMAGE_SELECTED(image)
            } else {
                IMAGE_NOT_SELECTED
            }
        }
        .animation(.default, value: image)
        .navigationTitle("Image Search")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if image != nil {
                    Button("New Search") {
                        self.image = nil
                    }
                }
            }
        }
        .onChange(of: image) { val in

            if val == nil {
                response = .idle
            }
        }
    }

    var IMAGE_NOT_SELECTED: some View {
        Button("Select Image") {
            presentImagePicker.toggle()
        }
        .sheet(isPresented: $presentImagePicker) {
            ImagePicker(image: $image)
        }
    }

    func IMAGE_SELECTED(_ image: UIImage) -> some View {
        LoadableView({
            await loadResults(image)
        }, $response) { response in
            RESPONSE_LOADED_VIEW(response: response)
        }
    }

    func loadResults(_ image: UIImage) async {
        response = .loading
        let manager = SauceNao.shared
        do {
            let data = try await manager.search(with: image)
            withAnimation {
                response = .loaded(data)
            }

        } catch {
            withAnimation {
                response = .failed(error)
            }
        }
    }

    @ViewBuilder
    func RESPONSE_LOADED_VIEW(response: SauceNao.Response) -> some View {
        if response.results.isEmpty {
            Text("No Results Found.")
        } else {
            ResultView(response.results)
        }
    }

    func ResultView(_ entries: [SauceNao.Entry]) -> some View {
        List {
            ForEach(entries, id: \.header.thumbnail) { entry in
                Section {
                    Tile(entry: entry)
                }
            }
        }
    }
}

extension ImageSearchView {
    struct Tile: View {
        var entry: SauceNao.Entry
        @State var isPresentingLinks = false
        var body: some View {
            HStack {
                BaseImageView(url: URL(string: entry.header.thumbnail))
                    .frame(width: 120, height: 120 * 1.5, alignment: .center)
                    .background(Color.gray)
                    .cornerRadius(5)
                VStack(alignment: .leading) {
                    Text(entry.data.source)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)
                    Text(entry.data.source + entry.data.part)
                        .font(.subheadline)
                        .lineLimit(2)

                    Text(entry.header.similarity + "% Match")
                        .font(.subheadline)
                        .padding(.bottom)
                    Text("Written By " + entry.data.author)
                        .font(.footnote)
                    Text("Art By " + entry.data.artist)
                        .font(.footnote)
                    Spacer()
                }
            }
            .onTapGesture {
                isPresentingLinks.toggle()
            }
            .confirmationDialog("Links", isPresented: $isPresentingLinks) {
                let data = entry.data.ext_urls
                let urls = data.compactMap { URL(string: $0) }
                let array = Array(zip(urls.indices, urls))
                ForEach(array, id: \.0) { _, url in
                    Button(url.host ?? "Unknown Host") {
                        Task { @MainActor in
                            let result = await DSK.shared.handleURL(for: url)
                            if !result {
                                KEY_WINDOW?.rootViewController?.present(SFSafariViewController(url: url), animated: true)
                            }
                        }
                    }
                }
            }
        }
    }
}
