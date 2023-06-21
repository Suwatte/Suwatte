//
//  DirectoryViewer.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-20.
//

import SwiftUI

import QuickLook
import QuickLookThumbnailing
import NukeUI

struct DirectoryViewer: View {
    @StateObject var model: ViewModel
    var body: some View {
        Group {
            if let folder = model.folder {
                List {
                    Section {
                        ForEach(folder.folders, id: \.id) { subfolder in
                            NavigationLink {
                                DirectoryViewer(model: .init(path: subfolder.url))
                                    .navigationTitle(subfolder.url.lastPathComponent)
                            } label: {
                                
                                VStack(alignment: .leading) {
                                    Text(subfolder.url.lastPathComponent)
                                    Text(subfolder.url.absoluteString)
                                        .font(.caption)
                                        .fontWeight(.light)
                                }
                                .multilineTextAlignment(.leading)

                            }

                        }
                    } header: {
                        Text("Folders")
                    }
                    
                    Section {
                        ForEach(folder.files, id: \.id) { file in
                            HStack {
                                TestThumbnailViewer(file: file)
                                VStack(alignment: .leading) {
                                    Text(file.name)
                                    Text(file.url.relativeString)
                                        .font(.caption)
                                        .fontWeight(.light)
                                }
                                .multilineTextAlignment(.leading)
                            }
                            
                        }
                    } header: {
                        Text("Comics")
                    }
                }
            } else {
                ProgressView()
            }
        }
        .task {
            model.observe()
        }
        .onDisappear(perform: model.stop)
        .navigationTitle("Library")
    }
}

struct TestThumbnailViewer: View {
    @StateObject var loader = FetchImage()
    var file: File
    var body: some View {
        Group {
            if let image = loader.image {
                image.resizable()
            } else {
                Color.gray.opacity(0.75)
                    .shimmering()
            }
        }
        .frame(width: 100, height: 150)
        .task {
            load()
        }
    }
    
    func load() {
        loader.load {
            let thumb = try await  generateThumb(for: file.url)
            return .init(container: .init(image: thumb), request: .init(url: file.url))
        }
        
        loader.onCompletion =  { result in
            
            switch result {
            case .failure( let error) :
                print(error)
            default:
                //
                break
            }
            
        }
    }
    
    func generateThumb(for path: URL) async throws -> UIImage {
        let thumbnailSize = CGSize(width: 100, height: 150)  // Specify the desired thumbnail size
        let request = QLThumbnailGenerator.Request(fileAt: path, size: thumbnailSize, scale: UIScreen.mainScreen.scale , representationTypes: .thumbnail)
        let thumbnailGenerator = QLThumbnailGenerator.shared
        let result = try await thumbnailGenerator.generateBestRepresentation(for: request)
        return result.uiImage
    }
}
