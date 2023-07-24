//
//  ProfileView+Covers.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import Nuke
import SwiftUI

extension ProfileView {
    struct CoversSheet: View {
        var covers: [String]
        @Environment(\.presentationMode) var presentMode
        @EnvironmentObject var model: ProfileView.ViewModel
        var body: some View {
            NavigationView {
                TabView {
                    ForEach(covers, id: \.self) { cover in
                        BaseImageView(url: .init(string: cover), runnerId: model.source.id)
                            .cornerRadius(5)
                            .contextMenu {
                                Button {
                                    Task {
                                        await handleSaveEvent(for: cover)
                                    }
                                } label: {
                                    Label("Save Image", systemImage: "square.and.arrow.down")
                                }
                            }
                            .padding()
                            .tag(cover)
                    }
                }

                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            presentMode.wrappedValue.dismiss()
                        }
                    }
                }
                .tabViewStyle(.page)
                .navigationTitle("Covers")
                .navigationViewStyle(.stack)
            }
            .toast()
        }

        func handleSaveEvent(for cover: String) async {
            let url = URL(string: cover)

            guard let url, let source = DSK.shared.getSource(id: model.source.id) else {
                return
            }

            var request = URLRequest(url: url)
            if source.intents.imageRequestHandler {
                do {
                    let dskResponse = try await source.willRequestImage(imageURL: url)
                    request = try dskResponse.toURLRequest()
                } catch {
                    Logger.shared.error("\(error)")
                }
            }
            let imageRequest = ImageRequest(urlRequest: request)
            do {
                let image = try await ImagePipeline.shared.image(for: imageRequest)
                STTPhotoAlbum.shared.save(image)

            } catch {
                ToastManager.shared.display(.error(error))
                ToastManager.shared.info("Cover Saved!")
            }
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    var itemsToShare: [Any]
    var servicesToShareItem: [UIActivity]? = nil
    func makeUIViewController(context _: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: itemsToShare, applicationActivities: servicesToShareItem)
        return controller
    }

    func updateUIViewController(_: UIActivityViewController,
                                context _: UIViewControllerRepresentableContext<ActivityViewController>) {}
}
