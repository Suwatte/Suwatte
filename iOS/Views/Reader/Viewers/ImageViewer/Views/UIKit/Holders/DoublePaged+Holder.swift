//
//  DoublePaged+Holder.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-09.
//

import UIKit
import SwiftUI
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
    
    private let scrollView = ZoomingScrollView()
    private let stackView = UIStackView()
    private let progressView = CircularProgressView()
    private var errorView: UIView? = nil
    
    private weak var nukeTask: AsyncImageTask?
    private var imageTask: Task<Void, Never>?
    
    // Image Constraints
    private var heightContraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?
    
    // State
    private var subscriptions = Set<AnyCancellable>()
    
    // Vision
    private var visionInteraction: UIInteraction?
    
    init() {
        super.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        // Hide All Views Initially
        progressView.isHidden = true
        // AutoLayout Enabled
        progressView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        // Add Core Wrapper & Progress View
        addSubview(progressView)
        addSubview(scrollView)
        
        // Setup ScrollView
        scrollView.setup() // Set Up Internal Scroll Wrapper
        scrollView.target = stackView // Set the Scroll Wrapper's Target
        
        // Setup Stack View
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.spacing = .zero
        
        // Make BG Colors Clear
        progressView.backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.wrapper.backgroundColor = .clear
        stackView.backgroundColor = .clear
        backgroundColor = .clear
        
        // Activate Required 4 Corner Pin Constraints
        NSLayoutConstraint.activate([
            // Scroll
            scrollView.widthAnchor.constraint(equalTo: widthAnchor),
            scrollView.heightAnchor.constraint(equalTo: heightAnchor),
            scrollView.centerXAnchor.constraint(equalTo: centerXAnchor),
            scrollView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            // Progress
            progressView.widthAnchor.constraint(equalTo: widthAnchor),
            progressView.heightAnchor.constraint(equalTo: heightAnchor),
            progressView.centerXAnchor.constraint(equalTo: centerXAnchor),
            progressView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    
    
    func load() {
        
        let firstPage = firstPage
        let secondPage = secondPage
        print(UIScreen.main.bounds.size, "BASE")
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
                addImageToStack(image: first, isSingle: true)
            }
        } else if second.size.ratio > 1 {
            delegate?.secondaryIsWide(for: panel)
            Task { @MainActor in
                addImageToStack(image: first, isSingle: true)
            }
        } else {
            let shouldInvert = Preferences.standard.currentReadingMode.isInverted
            if shouldInvert {
                addImageToStack(image: first)
                addImageToStack(image: second)
            } else {
                addImageToStack(image: second)
                addImageToStack(image: first)
            }
        }
        let multiplier = frame.size.ratio
        let width = bounds.height * multiplier
        heightContraint = stackView.heightAnchor.constraint(equalTo: heightAnchor)
        widthConstraint = stackView.widthAnchor.constraint(equalTo: stackView.heightAnchor, multiplier: multiplier)
        scrollView.didUpdateSize(size: .init(width: width, height: bounds.height))
        // Activate
        heightContraint?.isActive = true
        widthConstraint?.isActive = true

        // Set Priority
        heightContraint?.priority = .required
        widthConstraint?.priority = .required

//        scrollView.setZoomPosition()
        setProgress(1)
        setVisible(.set)
    }
    
    func addImageToStack(image: UIImage, isSingle: Bool = false) {
        Task { @MainActor in
            let imageView = UIImageViewAligned()
            imageView.image = image
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.isUserInteractionEnabled = true

            if isSingle {
                imageView.alignment = .center
            } else if stackView.arrangedSubviews.isEmpty {
                imageView.alignment = .right
            } else {
                imageView.alignment = .left
            }
            
            stackView.addArrangedSubview(imageView)
        }
    }
    
    
}

extension DoublePagedDisplayHolder {
    func setProgress(_ value: Double) {
        progressView.setProgress(to: value, withAnimation: false)
    }

    func setProgress(for page: ReaderPage, value: Double) {
//        if page === firstImageTask {
//            progress.0 = value
//        } else {
//            progress.1 = value
//        }
//
//        var total = 1 + 0.5
//        if progress.1 != nil {
//            total += 1
//        }
//
//        let current = progress.0 + (progress.1 ?? 0)
//
//        setProgress(current / total)
    }

    func setError(_ error: Error) {
        errorView?.removeFromSuperview()
        errorView = nil

//        let display = ErrorView(error: error, runnerID: firstPage.page.sourceId, action: reload)
//        errorView = UIHostingController(rootView: display).view
//
//        guard let errorView else { return }
//        addSubview(errorView)
//        errorView.translatesAutoresizingMaskIntoConstraints = false
//        // Pin
//        NSLayoutConstraint.activate([
//            errorView.topAnchor.constraint(equalTo: topAnchor),
//            errorView.bottomAnchor.constraint(equalTo: bottomAnchor),
//            errorView.trailingAnchor.constraint(equalTo: trailingAnchor),
//            errorView.leadingAnchor.constraint(equalTo: leadingAnchor),
//        ])
//
//        // Display
//        setVisible(.error)
    }

    func setVisible(_ s: PageState) {
        DispatchQueue.main.async {
            UIView.transition(with: self, duration: 0.25, options: [.transitionCrossDissolve, .allowUserInteraction]) { [unowned self] in
                switch s {
                case .loading:
                    scrollView.alpha = 0
                    errorView?.alpha = 0
                    errorView?.removeFromSuperview()
                    errorView = nil
                    progressView.alpha = 1
                case .error:
                    errorView?.alpha = 1
                    scrollView.alpha = 0
                    progressView.alpha = 0

                case .set:
                    scrollView.alpha = 1
                    errorView?.alpha = 0
                    errorView?.removeFromSuperview()
                    errorView = nil
                    progressView.alpha = 0
                }
            }
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
