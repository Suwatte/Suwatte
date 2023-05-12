//
//  ProfileView+Covers.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import Kingfisher
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
                        KFImage(URL(string: cover))
                            .placeholder({ _ in
                                Color.gray.opacity(0.25)
                                    .shimmering()
                            })
                            .resizable()
                            .requestModifier(AsyncImageModifier(sourceId: model.source.id))
                            .scaledToFit()
                            .cornerRadius(5)
                            .contextMenu {
                                Button {
                                    handleSaveEvent(for: cover)
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

        func handleSaveEvent(for cover: String) {
            KingfisherManager.shared.retrieveImage(with: URL(string: cover)!) { result in
                switch result {
                case let .failure(error):
                    ToastManager.shared.display(.error(error))
                case let .success(KIR):
                    STTPhotoAlbum.shared.save(KIR.image)
                    ToastManager.shared.info("Cover Saved!")
                }
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
