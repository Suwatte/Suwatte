//
//  DoublePaged+Holder.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-09.
//

import Combine
import Nuke
import SwiftUI
import UIKit
import VisionKit

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
    private var errorView: UIView?

    private weak var nukeTask: AsyncImageTask?
    private var imageTask: Task<Void, Never>?
    private var pageProgress: (Double, Double) = (0, 0)

    // State
    private var subscriptions = Set<AnyCancellable>()

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
        setVisible(.loading)
        let firstPage = firstPage
        let secondPage = secondPage
        imageTask = Task {
            await PanelActor.run { [weak self] in
                do {
                    let images = try await withThrowingTaskGroup(of: (ReaderPage, UIImage).self) { [weak self] group in
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

                        try Task.checkCancellation()
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
                    if Task.isCancelled { return }
                    await self?.didLoadImages(first: images.0, second: images.1)
                } catch {
                    Logger.shared.error(error)
                    await self?.setError(error)
                }
            }
        }
    }

    func loadImage(for page: ReaderPage) async throws -> UIImage {
        let request = try await PanelActor
            .shared
            .loadPage(for: .init(data: .init(page: page),
                                 size: .init(width: frame.size.width / 2,
                                             height: frame.size.height),
                                 fitToWidth: true,
                                 isPad: true))

        for await progress in request.progress {
            // Update progress
            let p = Double(progress.fraction)
            await MainActor.run { [weak self] in
                self?.setProgress(for: page, value: p)
            }
        }
        let image = try await request.image
        return image
    }

    func didLoadImages(first: UIImage, second: UIImage) {
        // If either page is wide, show only first
        if first.size.ratio > 1 {
            delegate?.primaryIsWide(for: panel)
            Task { @MainActor [weak self] in
                self?.addImageToStack(image: first, isSingle: true)
            }
        } else if second.size.ratio > 1 {
            delegate?.secondaryIsWide(for: panel)
            Task { @MainActor [weak self] in
                self?.addImageToStack(image: first, isSingle: true)
            }
        } else {
            let shouldInvert = Preferences.standard.currentReadingMode.isInverted
            if !shouldInvert {
                addImageToStack(image: first)
                addImageToStack(image: second)
            } else {
                addImageToStack(image: second)
                addImageToStack(image: first)
            }
        }
        NSLayoutConstraint.activate([
            stackView.heightAnchor.constraint(equalTo: heightAnchor),
            stackView.widthAnchor.constraint(equalTo: widthAnchor),
        ])

        scrollView.didUpdateSize(size: frame.size)
        scrollView.setZoomPosition()
        scrollView.addGestures()
        setProgress(1)
        setVisible(.set)
        subscribe()
    }

    func addImageToStack(image: UIImage, isSingle: Bool = false) {
        let imageView = UIImageViewAligned()
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true

        if isSingle {
            imageView.alignment = .center
        } else if stackView.arrangedSubviews.isEmpty {
            imageView.alignment = .centerRight
        } else {
            imageView.alignment = .centerLeft
        }

        stackView.addArrangedSubview(imageView)
        addContextInteraction(for: imageView)
    }
}

extension DoublePagedDisplayHolder {
    func setProgress(_ value: Double) {
        progressView.setProgress(to: value, withAnimation: false)
    }

    func setProgress(for page: ReaderPage, value: Double) {
        if page == firstPage {
            pageProgress.0 = value
        } else {
            pageProgress.1 = value
        }
        setProgress(pageProgress.0 + pageProgress.1 / 2)
    }

    func setError(_ error: Error) {
        errorView?.removeFromSuperview()
        errorView = nil

        let display = ErrorView(error: error, runnerID: panel.page.chapter.sourceId, action: load)
        errorView = UIHostingController(rootView: display).view

        guard let errorView else { return }
        addSubview(errorView)
        errorView.translatesAutoresizingMaskIntoConstraints = false
        // Pin
        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: topAnchor),
            errorView.bottomAnchor.constraint(equalTo: bottomAnchor),
            errorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            errorView.leadingAnchor.constraint(equalTo: leadingAnchor),
        ])

        // Display
        setVisible(.error)
    }

    func setVisible(_ s: PageState) {
        DispatchQueue.main.async {
            UIView.transition(with: self, duration: 0.33, options: [.transitionCrossDissolve, .allowUserInteraction]) { [unowned self] in
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
                    pageProgress = (0, 0)

                case .set:
                    scrollView.alpha = 1
                    errorView?.alpha = 0
                    errorView?.removeFromSuperview()
                    errorView = nil
                    progressView.alpha = 0
                    pageProgress = (0, 0)
                }
            }
        }
    }
}

extension DoublePagedDisplayHolder {
    func cancel() {
        imageTask?.cancel()
        nukeTask?.cancel()
        imageTask = nil
        nukeTask = nil
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
    }

    func resetStackView() {
        for view in stackView.subviews {
            view.removeFromSuperview()
        }
    }

    func reset() {
        cancel()

        stackView.removeFromSuperview()
        errorView?.removeFromSuperview()
        errorView = nil

        scrollView.reset()

        delegate = nil
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }
}

extension DoublePagedDisplayHolder {
    func subscribe() {
        Preferences
            .standard
            .preferencesChangedSubject
            .filter { changedKeyPath in
                changedKeyPath == \Preferences.downsampleImages ||
                    changedKeyPath == \Preferences.cropWhiteSpaces
            }
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.cancel()
                    self?.resetStackView()
                    self?.load()
                }
            }
            .store(in: &subscriptions)
    }
}

extension DoublePagedDisplayHolder {
    func addContextInteraction(for view: UIView) {
        guard Preferences.standard.imageInteractions, let delegate else { return }
        view.addInteraction(UIContextMenuInteraction(delegate: delegate))
    }
}
