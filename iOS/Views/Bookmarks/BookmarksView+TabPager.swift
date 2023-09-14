//
//  BookmarksView+TabPager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-22.
//

import NukeUI
import SwiftUI

extension BookmarksView {
    struct PagerView: View {
        @Binding var pages: [UpdatedBookmark]
        @State var selection: String = ""
        @Environment(\.presentationMode) var presentationMode
        var body: some View {
            SmartNavigationView {
                ZStack(alignment: .bottomTrailing) {
                    TabView(selection: $selection) {
                        ForEach(pages) { page in
                            PagerCell(page: page, presentationMode: presentationMode)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .padding(.all, 7)
                        }
                    }
                    .tabViewStyle(.page)
                }
                .navigationTitle("Panels")
                .navigationBarTitleDisplayMode(.inline)
                .closeButton()
            }
        }

        struct PagerCell: View {
            let page: UpdatedBookmark
            @Binding var presentationMode: PresentationMode
            @StateObject private var loader = FetchImage()

            var body: some View {
                GeometryReader { proxy in
                    ZStack(alignment: .center) {
                        ImageView()
                            .task {
                                load(proxy.size)
                            }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }

            @ViewBuilder
            func ImageView() -> some View {
                if let image = loader.image {
                    image
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(3)
                        .contextMenu {
                            Button {
                                guard let image = try? loader.result?.get().image else {
                                    Logger.shared.warn("No Image")
                                    return
                                }
                                STTPhotoAlbum.shared.save(image)
                                ToastManager.shared.info("Saved Panel!")
                            } label: {
                                Label("Save To Photos", systemImage: "square.and.arrow.down")
                            }

                            Divider()

                            Button {
                                presentationMode.dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    StateManager.shared.open(bookmark: page)
                                }

                            } label: {
                                Label("Continue Reading", systemImage: "play")
                            }
                        }
                } else {
                    Color.clear
                }
            }

            func load(_ size: CGSize) {
                if loader.image != nil { return }
                loader.priority = .normal
                loader.transaction = .init(animation: .easeInOut(duration: 0.25))
                loader.processors = [NukeDownsampleProcessor(size: size)]

                guard let imageData = page.asset?.storedData() else { return }
                let request = ImageRequest(id: "bookmark::\(page.id)") {
                    imageData
                }
                loader.load(request)
            }
        }
    }
}
