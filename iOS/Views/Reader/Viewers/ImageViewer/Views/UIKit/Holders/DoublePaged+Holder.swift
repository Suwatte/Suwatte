//
//  DoublePaged+Holder.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-09.
//

import UIKit
import Combine
import Nuke

class DoublePagedDisplayHolder: UIView {
    weak var delegate: DoublePageResolverDelegate?
    var panel: PanelPage!
    
    
    var firstPage: ReaderPage {
        panel.page
    }
    
    var secondPage: ReaderPage {
        panel.secondaryPage!
    }
    
    let imageView = UIImageView()
    private weak var nukeTask: AsyncImageTask?
    private var imageTask: Task<Void, Never>?
    private let subscriptions : Set<AnyCancellable> = []
    init() {
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: widthAnchor),
            imageView.heightAnchor.constraint(equalTo: heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    

    func load() {
        
        let firstPage = firstPage
        let secondPage = secondPage
        imageTask = Task {
            await PanelActor.run {
                do {
                    let images = try await withThrowingTaskGroup(of: (ReaderPage, UIImage).self) { group in
                        
                        for page in [firstPage, secondPage] {
                            group.addTask { [weak self] in
                                try Task.checkCancellation()
                                let image = try await self?.loadImage(for: page)
                                
                                guard let image else {
                                    throw CancellationError()
                                }
                                return (page, image)
                            }
                        }
                        
                        var first: UIImage? = nil
                        var second: UIImage? = nil
                        for try await result in group {
                            if result.0 == firstPage {
                                first = result.1
                            } else {
                                second = result.1
                            }
                        }
                        return (first!, second!)
                    }
                    
                    await didLoadImages(first: images.0, second: images.1)
                } catch {
                    
                }

            }
        }
    }
    
    
    func loadImage(for page: ReaderPage) async throws -> UIImage {
        let request = try await PanelActor.shared.loadPage(for: .init(data: .init(page: page), size: frame.size, fitToWidth: true, isPad: true))

        let image = try await request.image
        return image

    }
    
    func didLoadImages(first: UIImage, second: UIImage) {
        
        // If either page is wide, show only first
        if first.size.ratio > 1 {
            delegate?.primaryIsWide(for: panel)
            Task { @MainActor in
                imageView.image = first
            }
        } else if second.size.ratio > 1 {
            delegate?.secondaryIsWide(for: panel)
            Task { @MainActor in
                imageView.image = first
            }
        } else {
            let shouldInvert = Preferences.standard.currentReadingMode.isInverted
            let image = shouldInvert ? first.sideBySide(with: second) : second.sideBySide(with: first)
            Task { @MainActor in
                imageView.image = image
            }
            // Join Images and display
            
        }
        Task { @MainActor in
            imageView.contentMode = .scaleAspectFit
        }
    }
    
}

extension DoublePagedDisplayHolder {
    func subscribe() {
        // WhiteSpace
        // Downsampling
        // Scale
        // Interactions
    }
    
    func subToCropWhiteSpacePublisher() {
        
    }
    
}


