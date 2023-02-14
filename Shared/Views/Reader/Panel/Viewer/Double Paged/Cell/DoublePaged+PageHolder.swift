//
//  DoublePaged+PageHolder.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-13.
//

import Combine
import Kingfisher
import SwiftUI
import UIKit

class DoublePagedDisplayHolder: UIView {
    // Core Properties
    weak var delegate: DoublePagedViewer.Controller?
    var page: ReaderPage!
    var secondPage: ReaderPage?

    // Views
    let stackView = UIStackView()
    let scrollView = ZoomingScrollView()
    let progressView = CircularProgressBar()
    var errorView: UIView?
    var progress: (Double, Double?) = (0, nil)
    var working = false

    // State
    var subscriptions = Set<AnyCancellable>()

    var tasks = Set<AnyCancellable>()

    var pageImage: UIImage?
    var secondPageImage: UIImage?
    // Init
    init() {
        super.init(frame: UIScreen.main.bounds)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension DoublePagedDisplayHolder {
    func reset() {
        cancel()

        stackView.removeFromSuperview()
        errorView?.removeFromSuperview()
        errorView = nil

        scrollView.reset()

        pageImage = nil
        secondPageImage = nil

        delegate = nil
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        print("Cancelled")
    }

    func reload() {
        load(page: page)
    }
}

extension DoublePagedDisplayHolder {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        // Hide All Views Initially
        progressView.alpha = 0
        scrollView.alpha = 0
        // AutoLayout Enabled
        progressView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // Add Core Wrapper & Progress View
        addSubview(progressView)
        addSubview(scrollView)

        // Misc Set Up
        scrollView.setup() // Set Up Internal Scroll Wrapper
        scrollView.target = stackView // Set the Scroll Wrapper's Target to our ImageView (This Also Adds it to the View Heirachy)
        scrollView.didUpdateSize(size: UIScreen.main.bounds.size)
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center

        // Make BG Colors Clear
        progressView.backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.wrapper.backgroundColor = .clear
        stackView.backgroundColor = .clear

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

        scrollView.standardSize()
    }
}

extension DoublePagedDisplayHolder {
    func load() {
        load(page: page)
        if let secondPage {
            load(page: secondPage)
        }
    }

    func load(page: ReaderPage) {
        guard !working else {
            return
        }
        if progressView.alpha == 0 {
            setVisible(.loading)
        }
        // Load First Image
        let providerTask = Task {
            try await STTImageLoader.shared.load(page: page.page)
        }
        tasks.insert(AnyCancellable(providerTask.cancel))

        let downloadTask = Task {
            do {
                let source = try await providerTask.value
                guard let source else { throw DSK.Errors.NamedError(name: "E001", message: "Source Not Found") }
                let options = getKFOptions()
                let kfTask = KingfisherManager
                    .shared
                    .retrieveImage(
                        with: source,
                        options: options,
                        progressBlock: { [weak self] current, total in self?.setProgress(for: page, value: Double(current) / Double(total)) },
                        completionHandler: { [weak self] in self?.handleLoadEvent($0, page: page) }
                    )
                if let kfTask {
                    tasks.insert(.init(kfTask.cancel))
                }
            } catch {
                setError(error)
            }
        }

        tasks.insert(.init(downloadTask.cancel))
    }
}

extension DoublePagedDisplayHolder {
    func handleLoadEvent(_ result: Result<RetrieveImageResult, KingfisherError>, page: ReaderPage) {
        switch result {
        case let .success(success):
            onPageLoadSuccess(result: success, target: page)
        case let .failure(failure):
            onPageLoadFailire(error: failure)
        }
    }

    func onPageLoadSuccess(result: RetrieveImageResult, target: ReaderPage) {
        let isWide = result.image.size.ratio > 1
        target.widePage = isWide

        // Target Is Wide and Is the Second Page, Mark the Primary Page as Isolated
        if target.widePage && target === secondPage {
            page.isolatedPage = true
        }

        // Target Is Wide And This is the Primary Page, Cancel Other Ongoing tasks
        if target.widePage && target === page {
            tasks.forEach { $0.cancel() }
            tasks.removeAll()
        }

        // Set Images
        if target === page {
            pageImage = result.image
        } else {
            secondPageImage = result.image
        }
        if target.isFullPage {
            delegate?.didIsolatePage(maintain: page, note: secondPage)
        }

        didLoadImage()
    }

    func didLoadImage() {
        // Loaded Primary Page, Marked As Full.
        if !stackView.arrangedSubviews.isEmpty {
            return
        }

        // Page Is Full Page
        if let pageImage, page.widePage || page.isolatedPage {
            addImageToStack(image: pageImage)
            scrollView.addGestures()
            setProgress(1)
            setVisible(.set)
            working = false
            return
        }

        // Double Paged
        if let pageImage, let secondPageImage {
            if Preferences.standard.readingLeftToRight {
                addImageToStack(image: pageImage)
                addImageToStack(image: secondPageImage)
            } else {
                addImageToStack(image: secondPageImage)
                addImageToStack(image: pageImage)
            }
            setProgress(1)
            scrollView.addGestures()
            setVisible(.set)
            working = false
            return
        }

        // Single Page, No Second, Not Marked as Isolated
        // This is caused by the stack generation logic, Might be worth exploring setting it to isolated when regenerating stack
        if let pageImage, secondPage == nil {
            addImageToStack(image: pageImage)
            scrollView.addGestures()
            setProgress(1)
            setVisible(.set)
            working = false
            return
        }
    }

    func addImageToStack(image: UIImage) {
        let imageView = UIImageView()
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true
        stackView.addArrangedSubview(imageView)
        let multiplier = 1 / image.size.ratio

        let t = imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: multiplier)
        t.priority = .required
        t.isActive = true

        if let delegate, Preferences.standard.imageInteractions {
            imageView.addInteraction(UIContextMenuInteraction(delegate: delegate))
        }
    }

    func onPageLoadFailire(error: Error) {
        setError(error)
    }

    func didSetImage() {
        scrollView.addGestures()
    }
}

extension DoublePagedDisplayHolder {
    func setProgress(_ value: Double) {
        progressView.setProgress(to: value, withAnimation: false)
    }

    func setProgress(for page: ReaderPage, value: Double) {
        if page === self.page {
            progress.0 = value
        } else {
            progress.1 = value
        }

        var total = 1 + 0.5
        if progress.1 != nil {
            total += 1
        }

        let current = progress.0 + (progress.1 ?? 0)

        setProgress(current / total)
    }

    func setError(_ error: Error) {
        errorView?.removeFromSuperview()
        errorView = nil

        let display = ErrorView(error: error, sourceID: page.page.sourceId, action: reload)
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
            UIView.transition(with: self, duration: 0.2, options: [.transitionCrossDissolve, .allowUserInteraction]) { [unowned self] in
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
    func getKFOptions() -> [KingfisherOptionsInfoItem] {
        var base: [KingfisherOptionsInfoItem] = [
            .scaleFactor(UIScreen.main.scale),
            .retryStrategy(DelayRetryStrategy(maxRetryCount: 3, retryInterval: .seconds(1))),
            .backgroundDecode,
            .requestModifier(AsyncImageModifier(sourceId: page.page.sourceId)),
        ]

        let isLocal = page.page.isLocal
        let cropWhiteSpaces = Preferences.standard.cropWhiteSpaces
        let downSampleImage = Preferences.standard.downsampleImages

        // Local Page, Cache to memory only
        if isLocal {
            base += [.cacheMemoryOnly]
        }
        // Has Processor & Not Local, Cache Original Image to disk
        if (cropWhiteSpaces || downSampleImage) && !isLocal {
            base += [.cacheOriginalImage]
        }

        // Declare Processor
        var processor: ImageProcessor = DefaultImageProcessor()

        // Initialize Resize Processor
//        if cropWhiteSpaces || downSampleImage || isLocal {
//            processor = ResizingImageProcessor(referenceSize: UIScreen.main.bounds.size, mode: .aspectFill)
//        }

        // Append WhiteSpace Processor
        if cropWhiteSpaces {
            processor = processor.append(another: WhiteSpaceProcessor())
        }

        // Append Downsample Processor
        if downSampleImage {
            processor = processor.append(another: STTDownsamplerProcessor())
        }

        // Append Processor to options
        if cropWhiteSpaces || downSampleImage || isLocal {
            base += [.processor(processor)]
        }

        return base
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
                self?.cancel()
                self?.load()
            }
            .store(in: &subscriptions)
    }
}

extension DoublePagedDisplayHolder {
    func cancel() {
        tasks.forEach { $0.cancel() }
    }
}

extension DoublePagedDisplayHolder {
    class StandardImageView: UIView {
        let imageView = UIImageView()
        var heightContraint: NSLayoutConstraint?
        var widthConstraint: NSLayoutConstraint?

        init() {
            super.init(frame: .zero)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(imageView)

            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: topAnchor),
                imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
                imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func setImage(image: UIImage) {
            imageView.image = image
            activateConstraints()
        }

        func activateConstraints() {
            guard let image = imageView.image else { fatalError("Image Not Set") }
            let size = image.size

            NSLayoutConstraint.activate([
                imageView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor),
                imageView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor),
                imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])

            heightContraint?.isActive = false
            widthConstraint?.isActive = false

            let height = (1 / size.ratio) * bounds.width
            if height > bounds.height || UIScreen.main.bounds.width > UIScreen.main.bounds.height {
                let multiplier = size.ratio
                widthConstraint = imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: multiplier)
                heightContraint = imageView.heightAnchor.constraint(equalTo: heightAnchor)
            } else {
                let multiplier = 1 / size.ratio
                widthConstraint = imageView.widthAnchor.constraint(equalTo: widthAnchor)
                heightContraint = imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: multiplier)
            }

            widthConstraint?.isActive = true
            heightContraint?.isActive = true
        }
    }
}
