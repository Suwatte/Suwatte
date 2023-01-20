//
//  Paged+Holder.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-14.
//

import UIKit
import Kingfisher
import SwiftUI
import Combine
import VisionKit

protocol PagerDelegate: NSObject, UIContextMenuInteractionDelegate {
    var model: ReaderView.ViewModel! { get set }
}

enum PageState {
    case loading, error, set
}

extension CGSize {
    var ratio: CGFloat {
        width / height
    }
}


enum ImageScaleOption: Int, CaseIterable, UserDefaultsSerializable {
    case screen, height, width, stretch
    
    
    var description: String {
        switch self {
            case .screen:
                return "Fit Screen"
            case .height:
                return "Fit Height"
            case .width:
                return "Fit Width"
            case .stretch:
                return "Stretch"
        }
    }
}


class PagedDisplayHolder : UIView {
    
    // Core Properties
    weak var delegate: PagerDelegate?
    var page: ReaderPage!
    
    // Views
    let imageView = UIImageView()
    let scrollView = ZoomingScrollView()
    let progressView = CircularProgressBar()
    var errorView: UIView?
    
    // Tasks
    var providerTask: Task<Kingfisher.Source?, Error>?
    var downloadTask: Task<Void, Never>?
    var kfDownloadTask: Kingfisher.DownloadTask?
    
    // Image Constraints
    var heightContraint: NSLayoutConstraint?
    var widthConstraint: NSLayoutConstraint?
    
    // State
    var subscriptions = Set<AnyCancellable>()
    
    // Vision
    var visionInteraction: UIInteraction?

    // Init
    init() {
        super.init(frame: UIScreen.main.bounds)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var visionPressGesuture: UITapGestureRecognizer = {
        let press = UITapGestureRecognizer(target: self, action: #selector(handleVisionRequest(_:)))
        press.numberOfTapsRequired = 2
        press.numberOfTouchesRequired = 2
        return press
    }()
}


extension PagedDisplayHolder {
    func setup () {
        translatesAutoresizingMaskIntoConstraints = false
        // Hide All Views Initially
        progressView.isHidden = true
        scrollView.isHidden = true
        // AutoLayout Enabled
        progressView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add Core Wrapper & Progress View
        addSubview(progressView)
        addSubview(scrollView)
        
        // Misc Set Up
        scrollView.setup() // Set Up Internal Scroll Wrapper
        imageView.contentMode = .scaleAspectFill // Set ImageView to Aspect Fill
        scrollView.target = imageView // Set the Scroll Wrapper's Target to our ImageView (This Also Adds it to the View Heirachy)
        
        // Make BG Colors Clear
        progressView.backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.wrapper.backgroundColor = .clear
        imageView.backgroundColor = .clear
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
}
extension PagedDisplayHolder {
    func resetConstraints() {
        // Disable Constraints
        heightContraint?.isActive = false
        widthConstraint?.isActive = false
        
        // Reset
        heightContraint = nil
        widthConstraint = nil
        
        
        // Reset Scroll Wrapper Constraints
        NSLayoutConstraint.deactivate(scrollView.postImageSetConstraints)
        scrollView.postImageSetConstraints.removeAll()
    }
}
extension PagedDisplayHolder {
    func subscribe () {
        Preferences
            .standard
            .preferencesChangedSubject
            .filter { changedKeyPath in
                changedKeyPath == \Preferences.downsampleImages ||
                    changedKeyPath == \Preferences.cropWhiteSpaces
            }
            .sink { [weak self] _ in
                self?.cancel()
                self?.imageView.image = nil
                self?.load()
            }
            .store(in: &subscriptions)
        
        Preferences
            .standard
            .preferencesChangedSubject
            .filter({ $0 == \Preferences.imageScaleType })
            .sink { [weak self] _ in
                guard let size = self?.imageView.image?.size else { return }
                self?.constrain(size: size)
            }
            .store(in: &subscriptions)
    }
}

extension PagedDisplayHolder {
    func cancel() {
        providerTask?.cancel()
        downloadTask?.cancel()
        kfDownloadTask?.cancel()
    }
}

extension PagedDisplayHolder {
    func load() {
        guard imageView.image == nil, providerTask == nil, downloadTask == nil, kfDownloadTask == nil else {
            return
        }
        setVisible(.loading)
        providerTask = Task {
            try await STTImageLoader.shared.load(page: page.page)
        }
        
        downloadTask = Task {
            do {
                let source = try await providerTask?.value
                guard let source else { throw DSK.Errors.NamedError(name: "E001", message: "Source Not Found") }
                let options = getKFOptions()
                kfDownloadTask = KingfisherManager
                    .shared
                    .retrieveImage(
                        with: source,
                        options: options,
                        progressBlock: { [weak self] current, total in self?.setProgress(Double(current) / Double(total))  },
                        completionHandler: { [weak self] in self?.handleLoadEvent($0) }
                    )
            } catch {
                setError(error)
            }
        }
    }
}

extension PagedDisplayHolder {
    func reset() {
        cancel()
        resetConstraints()

        imageView.image = nil
        errorView?.removeFromSuperview()
        errorView = nil
        
        imageView.interactions.removeAll()
        scrollView.reset()
        
        imageView.image = nil
        imageView.interactions.removeAll()
        imageView.removeFromSuperview()
        
        delegate = nil
    }
    func reload() {
        load()
    }
}

extension PagedDisplayHolder {
    func handleLoadEvent(_ result: Result<RetrieveImageResult, KingfisherError>) {
        switch result {
            case .success(let success):
                onPageLoadSuccess(result: success)
            case .failure(let failure):
                onPageLoadFailire(error: failure)
        }
    }
    func onPageLoadSuccess(result: RetrieveImageResult) {
        displayImage(image: result.image)
    }
    func onPageLoadFailire(error: Error) {
        setError(error)
    }
    func displayImage(image: UIImage) {
        setProgress(1)
        constrain(size: image.size)
        addVisionInteraction()
        setVisible(.set)

        Task { @MainActor in
            UIView.transition(with:self.imageView,
                              duration: 0.20,
                              options: [.transitionCrossDissolve, .allowUserInteraction],
                              animations: {[weak self] in self?.setImage(image: image)},
                              completion: {[weak self] _ in  self?.didSetImage() }
            )
        }
    }
    
    func setImage(image: UIImage) {
        imageView.image = image
    }
    
    func didSetImage() {
        scrollView.addGestures()
        providerTask = nil
        downloadTask = nil
    }
}
extension PagedDisplayHolder {
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

extension PagedDisplayHolder {
    func setProgress(_ value: Double) {
        progressView.setProgress(to: value, withAnimation: false)
    }
    func setError(_ error: Error) {
        errorView?.removeFromSuperview()
        errorView = nil
        
        let display = ErrorView(error: error,sourceID: page.page.sourceId ,action: reload)
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

extension PagedDisplayHolder {
    func addImageInteraction(_ interaction: UIInteraction) {
        imageView.addInteraction(interaction)
    }
}


extension PagedDisplayHolder {
    func getKFOptions()  -> [KingfisherOptionsInfoItem] {
        var base: [KingfisherOptionsInfoItem] = [
            .scaleFactor(UIScreen.main.scale),
            .retryStrategy(DelayRetryStrategy(maxRetryCount: 3, retryInterval: .seconds(1))),
            .backgroundDecode,
            .requestModifier(AsyncImageModifier(sourceId: page.page.sourceId))
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

extension PagedDisplayHolder {
    
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
extension PagedDisplayHolder {
    
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
class STTImageLoader {
    static let shared = STTImageLoader()
    
    
    func load(page: ReaderView.Page) async throws -> Kingfisher.Source? {
        return page.toKFSource()
    }
}
