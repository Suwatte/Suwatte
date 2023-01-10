//
//  ReaderImageView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-01.
//

import Combine
import Kingfisher
import SwiftUI
import UIKit
import VisionKit

class ReaderPageView: UIView {
    let imageView = UIImageView()
    var scrollView: ZoomingScrollView!
    var page: ReaderView.Page!
    var indexPath: IndexPath!
    var downloadTask: DownloadTask?

    var progressView: UIView!
    var progressModel = ReaderView.ProgressObject()
    var subscriptions = Set<AnyCancellable>()
    var visionInteraction: UIInteraction?

    init() {
        super.init(frame: UIScreen.main.bounds)
        setupViews()
    }
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

    func setupViews() {
        // Panel Delegate
        progressView = UIHostingController(rootView: ReaderView.PageProgressView(model: progressModel)).view!
        progressView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressView)

        scrollView = ZoomingScrollView(frame: UIScreen.main.bounds)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        imageView.frame = UIScreen.main.bounds
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.target = imageView

        progressView.backgroundColor = .clear
        scrollView.backgroundColor = .clear
        imageView.backgroundColor = .clear

        activateConstraints()
        subscribe()
    }

    func cancelTasks() {
        downloadTask?.cancel()
        imageView.kf.cancelDownloadTask()
    }

    func subscribe() {
        Preferences
            .standard
            .preferencesChangedSubject
            .filter { changedKeyPath in
                changedKeyPath == \Preferences.downsampleImages ||
                    changedKeyPath == \Preferences.cropWhiteSpaces
            }
            .sink { [unowned self] _ in
                imageView.image = nil
                setImage()
            }
            .store(in: &subscriptions)
    }

    func activateConstraints() {
        heightContraint = imageView.heightAnchor.constraint(equalToConstant: 0)
        widthConstraint = imageView.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),

            heightContraint!,
            widthConstraint!,

            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),

            progressView.widthAnchor.constraint(equalTo: widthAnchor),
            progressView.heightAnchor.constraint(equalTo: heightAnchor),
            progressView.centerXAnchor.constraint(equalTo: centerXAnchor),
            progressView.centerYAnchor.constraint(equalTo: centerYAnchor),

        ])
    }

    var heightContraint: NSLayoutConstraint?
    var widthConstraint: NSLayoutConstraint?
    func updateHeightConstraint(size: CGSize) {
        let ratio = size.width / size.height
        var height = (size.height / size.width) * frame.width
        height = min(height, scrollView.bounds.height)
        let width = height * ratio
        heightContraint?.constant = height
        heightContraint?.isActive = false
        heightContraint = nil
        heightContraint = imageView.heightAnchor.constraint(equalToConstant: height)
        heightContraint?.priority = .required
        heightContraint?.isActive = true

        widthConstraint?.constant = width
        widthConstraint?.isActive = false
        widthConstraint = nil
        widthConstraint = imageView.widthAnchor.constraint(equalToConstant: width)
        widthConstraint?.isActive = true
        widthConstraint?.priority = .required

        scrollView.contentSize = imageView.bounds.size
    }

    func reload() {
        setImage()
    }

    func setImage() {
        guard imageView.image == nil, let source = page.toKFSource() else {
            return
        }
        cancelTasks()
        // KF Options
        var kfOptions: [KingfisherOptionsInfoItem] = [
            .scaleFactor(UIScreen.main.scale),
            .retryStrategy(DelayRetryStrategy(maxRetryCount: 3, retryInterval: .seconds(1))),
            .requestModifier(AsyncImageModifier(sourceId: page.sourceId)),
            .backgroundDecode,
        ]

        // Local Page, Cache to memory only
        if page.isLocal {
            kfOptions += [.cacheMemoryOnly]
        }

        // Has Processor & Not Local, Cache Original Image to disk
        if (cropWhiteSpaces || downSampleImage) && !page.isLocal {
            kfOptions += [.cacheOriginalImage]
        }

        // Declare Processor
        var processor: ImageProcessor?

        // Initialize Resize Processor
        if cropWhiteSpaces || downSampleImage || page.isLocal {
            processor = ResizingImageProcessor(referenceSize: UIScreen.main.bounds.size, mode: .aspectFit)
        }

        // Append WhiteSpace Processor
        if cropWhiteSpaces {
            processor = processor?.append(another: WhiteSpaceProcessor())
        }

        // Append Downsample Processor
        if downSampleImage {
            processor = processor?.append(another: STTDownsamplerProcessor())
        }

        // Append Processor to options
        if let processor = processor {
            kfOptions += [.processor(processor)]
        }

        downloadTask = KingfisherManager.shared.retrieveImage(with: source,
                                                              options: kfOptions,
                                                              progressBlock: { [weak self] in self?.progressBlock($0, $1) },
                                                              completionHandler: { [weak self] in self?.onImageProvided($0) })
    }

    func onImageProvided(_ result: Result<RetrieveImageResult, KingfisherError>) {
        switch result {
        case let .success(imageResult):
            // Hide Progress
            if progressModel.progress != 1 {
                progressModel.setProgress(CGFloat(1))
            }

            updateHeightConstraint(size: imageResult.image.size)

            DispatchQueue.main.async {
                self.progressView.isHidden = true
                UIView.transition(with: self.imageView,
                                  duration: 0.20,
                                  options: [.transitionCrossDissolve, .allowUserInteraction],
                                  animations: {
                                      self.imageView.image = imageResult.image
                                  }) { _ in
                    self.scrollView.addGestures()
                                      self.addLiveTextSupport()
                }
            }

        case let .failure(error):
            if error.isNotCurrentTask || error.isTaskCancelled {
                return
            }
            progressModel.setError(error, reload)
            progressView.alpha = 1
        }
    }

    func progressBlock(_ recieved: Int64, _ total: Int64) {
        progressModel.setProgress(CGFloat(recieved) / CGFloat(total))
    }
}

extension ReaderPageView {
    var downSampleImage: Bool {
        UserDefaults.standard.bool(forKey: STTKeys.DownsampleImages)
    }

    var cropWhiteSpaces: Bool {
        UserDefaults.standard.bool(forKey: STTKeys.CropWhiteSpaces)
    }
}

extension ReaderPageView {
    
    func addLiveTextSupport() {
        
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
extension ReaderPageView {
    
    @objc func handleVisionRequest(_ sender: UITapGestureRecognizer) {
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
            DispatchQueue.main.async {
                visionInteraction.analysis = analysis
            }
        }
    }
}

extension CGSize {
    var ratio: CGFloat {
        width / height
    }
}
