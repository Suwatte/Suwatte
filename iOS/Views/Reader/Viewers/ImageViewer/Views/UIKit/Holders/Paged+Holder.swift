//
//  Paged+Holder.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Combine
import Nuke
import SwiftUI
import UIKit
import VisionKit

enum PageState {
    case loading, error, set
}

class PagedViewerImageHolder: UIView {
    // Core Properties
    weak var delegate: UIContextMenuInteractionDelegate?
    var page: PanelPage!

    // Views
    let imageView = UIImageView()
    let scrollView = ZoomingScrollView()
    let progressView = CircularProgressView()
    var errorView: UIView?

    // Tasks
    private weak var nukeTask: AsyncImageTask?
    private var imageTask: Task<Void, Never>?

    // Image Constraints
    var heightContraint: NSLayoutConstraint?
    var widthConstraint: NSLayoutConstraint?

    // State
    var subscriptions = Set<AnyCancellable>()

    // Vision
    var visionInteraction: UIInteraction?

    // Init

    lazy var visionPressGesuture: UITapGestureRecognizer = {
        let press = UITapGestureRecognizer(target: self, action: #selector(handleVisionRequest(_:)))
        press.numberOfTapsRequired = 2
        press.numberOfTouchesRequired = 2
        return press
    }()

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(page: PanelPage, frame: CGRect) {
        super.init(frame: frame)
        self.page = page
    }
}

extension PagedViewerImageHolder {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        // Hide All Views Initially
        progressView.isHidden = true
        // AutoLayout Enabled
        progressView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // Add Core Wrapper & Progress View
        addSubview(progressView)
        addSubview(scrollView)

        // Misc Set Up
        scrollView.setup() // Set Up Internal Scroll Wrapper
        scrollView.target = imageView // Set the Scroll Wrapper's Target to our ImageView (This Also Adds it to the View Heirachy)

        // Make BG Colors Clear
        progressView.backgroundColor = .clear
        scrollView.wrapper.backgroundColor = .clear
        imageView.backgroundColor = .clear
        backgroundColor = .clear

        // Activate Required 4 Corner Pin Constraints
        NSLayoutConstraint.activate([
            // Scroll
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),

            // Progress
            progressView.widthAnchor.constraint(equalTo: widthAnchor),
            progressView.heightAnchor.constraint(equalTo: heightAnchor),
            progressView.centerXAnchor.constraint(equalTo: centerXAnchor),
            progressView.centerYAnchor.constraint(equalTo: centerYAnchor),

        ])
    }
}

extension PagedViewerImageHolder {
    func resetConstraints() {
        // Disable Constraints
        heightContraint?.isActive = false
        widthConstraint?.isActive = false

        // Reset
        heightContraint = nil
        widthConstraint = nil
        scrollView.resetConstraints()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        constrain()
    }
}

extension PagedViewerImageHolder {
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
                    self?.imageView.image = nil
                    self?.load()
                }
            }
            .store(in: &subscriptions)

        Preferences
            .standard
            .preferencesChangedSubject
            .filter { $0 == \Preferences.imageScaleType }
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.constrain()
                }
            }
            .store(in: &subscriptions)
    }
}

extension PagedViewerImageHolder {
    func cancel() {
        imageTask?.cancel()
        nukeTask?.cancel()
        imageTask = nil
        nukeTask = nil
        subscriptions.forEach { $0.cancel() }
        subscriptions.removeAll()
    }

    private func resetNukeTasksAsync() async {
        await MainActor.run { [weak self] in
            self?.nukeTask = nil
        }
    }
}

extension PagedViewerImageHolder {
    func load() {
        let locked = imageView.image != nil || nukeTask != nil

        guard !locked else {
            return
        }

        setVisible(.loading)
        let rPage = page.page
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let data: PanelActor.PageData = .init(data: page,
                                              size: frame.size,
                                              fitToWidth: false,
                                              isPad: isPad)

        imageTask = Task { [weak self] in
            await PanelActor.run { [weak self] in
                do {
                    let request = try await PanelActor.shared.loadPage(for: data)

                    guard !Task.isCancelled else {
                        await self?.resetNukeTasksAsync()
                        return
                    }

                    for await progress in request.progress {
                        // Update progress
                        let p = Double(progress.fraction)
                        await MainActor.run { [weak self] in
                            self?.setProgress(p)
                        }
                    }

                    guard !Task.isCancelled else {
                        await self?.resetNukeTasksAsync()
                        return
                    }

                    let image = try await request.image

                    guard !Task.isCancelled else { 
                        await self?.resetNukeTasksAsync()
                        return
                    }

                    await MainActor.run { [weak self] in
                        self?.displayImage(image: image)
                    }

                } catch {
                    Logger.shared.error(error, rPage.chapter.sourceId)
                    if error is CancellationError {
                        await self?.resetNukeTasksAsync()
                        return

                    }
                    await MainActor.run { [weak self] in
                        self?.setError(error)
                    }
                }

                await self?.resetNukeTasksAsync()
            }
        }
    }
}

extension PagedViewerImageHolder {
    func reset() {
        cancel()
        resetConstraints()

        imageView.image = nil
        errorView?.removeFromSuperview()
        errorView = nil

        imageView.interactions.removeAll()

        imageView.image = nil
        imageView.interactions.removeAll()
        imageView.removeFromSuperview()
    }

    func reload() {
        Task { @MainActor [weak self] in
            self?.cancel()
            self?.load()
        }
    }
}

extension PagedViewerImageHolder {
    func displayImage(image: UIImage) {
        setProgress(1)
        constrain(size: image.size)
        addVisionInteraction()
        setVisible(.set)

        Task { @MainActor [weak self] in
            guard let self else { return }
            UIView.transition(with: self.imageView,
                              duration: 0.20,
                              options: [.transitionCrossDissolve, .allowUserInteraction],
                              animations: { [weak self] in self?.setImage(image: image) },
                              completion: { [weak self] _ in self?.didSetImage() })
        }
    }

    func setImage(image: UIImage) {
        imageView.image = image
    }

    func didSetImage() {
        scrollView.addGestures()
        imageTask = nil
        nukeTask = nil
    }
}

extension PagedViewerImageHolder {
    func constrain() {
        guard let size = imageView.image?.size else { return }
        constrain(size: size)
    }

    func constrain(size: CGSize) {
        // Reset Existing Constrains
        resetConstraints()

        // Define Constraints
        switch Preferences.standard.imageScaleType {
        case .screen:
            activateFitScreenConstraint(size)
        case .height:
            activateFitHeightConstraint(size)
        case .width:
            activateFitWidthConstraint(size)
        case .stretch:
            activateStretchConstraint(size)
        }

        // Activate
        heightContraint?.isActive = true
        widthConstraint?.isActive = true

        // Set Priority
        heightContraint?.priority = .required
        widthConstraint?.priority = .required

        scrollView.setZoomPosition()
    }

    func activateFitScreenConstraint(_ size: CGSize) {
        let height = min((size.height / size.width) * frame.width, frame.height)
        let width = min(height * size.ratio, frame.width)
        widthConstraint = imageView.widthAnchor.constraint(equalToConstant: width)
        heightContraint = imageView.heightAnchor.constraint(equalToConstant: height)
        scrollView.didUpdateSize(size: .init(width: width, height: height))
    }

    func activateFitWidthConstraint(_ size: CGSize) {
        let multiplier = size.height / size.width
        let height = bounds.width * multiplier
        widthConstraint = imageView.widthAnchor.constraint(equalTo: widthAnchor)
        heightContraint = imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: multiplier)
        scrollView.didUpdateSize(size: .init(width: bounds.width, height: height))
    }

    func activateFitHeightConstraint(_ size: CGSize) {
        let multiplier = size.width / size.height
        let width = bounds.height * multiplier
        heightContraint = imageView.heightAnchor.constraint(equalTo: heightAnchor)
        widthConstraint = imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: multiplier)
        scrollView.didUpdateSize(size: .init(width: width, height: bounds.height))
    }

    func activateStretchConstraint(_ size: CGSize) {
        let ratio = size.ratio

        if ratio < 1 {
            let multiplier = size.height / size.width
            let height = bounds.width * multiplier
            if height < bounds.height {
                activateFitHeightConstraint(size)
            } else {
                activateFitWidthConstraint(size)
            }
        } else if ratio > 1 {
            activateFitHeightConstraint(size)
        } else {
            activateFitScreenConstraint(size)
        }
    }
}

extension PagedViewerImageHolder {
    func setProgress(_ value: Double) {
        progressView.setProgress(to: value, withAnimation: false)
    }

    func setError(_ error: Error) {
        errorView?.removeFromSuperview()
        errorView = nil

        let display = ErrorView(error: error, runnerID: page.page.chapter.sourceId, action: reload)
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
        switch s {
        case .loading:
            scrollView.isHidden = true
            errorView?.isHidden = true
            errorView?.removeFromSuperview()
            errorView = nil
            progressView.isHidden = false
        case .error:
            errorView?.isHidden = false
            scrollView.isHidden = true
            progressView.isHidden = true

        case .set:
            scrollView.isHidden = false
            errorView?.isHidden = true
            errorView?.removeFromSuperview()
            errorView = nil
            progressView.isHidden = true
        }
    }
}

extension PagedViewerImageHolder {
    func addImageInteraction(_ interaction: UIInteraction) {
        imageView.addInteraction(interaction)
    }
}

extension PagedViewerImageHolder {
    func addVisionInteraction() {
        guard #available(iOS 16, *), ImageAnalyzer.isSupported else { return }
        let interaction = ImageAnalysisInteraction()
        interaction.preferredInteractionTypes = .automatic
        interaction.allowLongPressForDataDetectorsInTextMode = true
        visionInteraction = interaction
        imageView.addInteraction(interaction)
        imageView.addGestureRecognizer(visionPressGesuture)
    }
}

// MARK: VisionKit Gestures

extension PagedViewerImageHolder {
    @objc func handleVisionRequest(_: UITapGestureRecognizer) {
        guard #available(iOS 16, *), ImageAnalyzer.isSupported else { return }

        guard let visionInteraction = visionInteraction as? ImageAnalysisInteraction else { return }
        // Currently Display Live Text
        if visionInteraction.analysis != nil {
            visionInteraction.analysis = nil
            return
        }
        let configuration = ImageAnalyzer.Configuration([.text, .machineReadableCode])
        let analyzer = ImageAnalyzer()
        let image = imageView.image
        guard let image else { return }
        Task {
            let analysis = try? await analyzer.analyze(image, configuration: configuration)
            await MainActor.run {
                visionInteraction.analysis = analysis
            }
        }
    }
}
