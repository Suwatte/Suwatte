//
//  Vertical+ImageCell.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-19.
//

import Combine
import Kingfisher
import Nuke
import NukeExtensions
import SwiftUI
import UIKit

protocol ResizeDelegate: NSObjectProtocol {
    func didLoadImage(at path: IndexPath, with size: CGSize)
}

class VerticalImageCell: UICollectionViewCell {
    static var identifier: String = "VerticalImageCell"
    
    weak var zoomDelegate: ZoomHandlerDelegate?
    weak var resizeDelegate: ResizeDelegate?
    let imageView = UIImageView()
    var downloadTask: DownloadTask?
    var page: ReaderView.Page!
    var indexPath: IndexPath!
    var progressView: UIView!
    var progressModel = ReaderView.ProgressObject()
    var subscriptions = Set<AnyCancellable>()
    var working: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        cancelTasks()
        imageView.image = nil
        imageView.removeFromSuperview()
        imageView.interactions.removeAll()
        imageView.isUserInteractionEnabled = false
        imageView.gestureRecognizers?.removeAll()
        subscriptions.removeAll()
        page = nil
        indexPath = nil
        zoomDelegate = nil
        resizeDelegate = nil
        working = false
        imageView.removeGestureRecognizer(zoomingTap)
    }
    
    lazy var zoomingTap: UITapGestureRecognizer = {
        let zoomingTap = UITapGestureRecognizer(target: self, action: #selector(handleZoomingTap(_:)))
        zoomingTap.numberOfTapsRequired = 2
        
        return zoomingTap
    }()
    
    @objc func handleZoomingTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: sender.view)
        zoomDelegate?.cellTappedAt(point: location, frame: sender.view!.frame, path: indexPath)
    }
    
    func setupViews() {
        // Panel Delegate
        progressView = UIHostingController(rootView: ReaderView.PageProgressView(model: progressModel)).view!
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.backgroundColor = .clear
        addSubview(progressView)
        
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = .clear
        addSubview(imageView)
        activateConstraints()
        subscribe()
    }
    
    func subscribe() {
        Preferences
            .standard
            .preferencesChangedSubject
            .filter { changedKeyPath in
                changedKeyPath == \Preferences.downsampleImages ||
                changedKeyPath == \Preferences.cropWhiteSpaces ||
                changedKeyPath == \Preferences.addImagePadding
            }.sink { [weak self] _ in
                self?.imageView.image = nil
                self?.setImage()
            }.store(in: &subscriptions)
    }
    
    func activateConstraints() {
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressView.topAnchor.constraint(equalTo: topAnchor),
            progressView.bottomAnchor.constraint(equalTo: bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
        ])
        imageView.backgroundColor = .clear
    }
    
    func reload() {
        setImage()
    }
    
    func cancelTasks() {
        downloadTask?.cancel()
        imageView.kf.cancelDownloadTask()
    }
    
    func setImage() {
        guard !working, imageView.image == nil, let source = page.toKFSource(), downloadTask == nil else {
            return
        }
        
        Task { @MainActor in
            cancelTasks()
            working = true

            // KF Options
            var kfOptions: [KingfisherOptionsInfoItem] = [
                .scaleFactor(UIScreen.main.scale),
                .retryStrategy(DelayRetryStrategy(maxRetryCount: 3, retryInterval: .seconds(1))),
                .requestModifier(AsyncImageModifier(sourceId: page.sourceId)),
                .backgroundDecode,
            ]
            
            var processor: ImageProcessor?
            
            if downSampleImage {
                processor = STTDownsamplerProcessor()
            }
            
            if page.isLocal {
                kfOptions.append(.cacheMemoryOnly)
                kfOptions += [.cacheMemoryOnly]
            }
            
            if downSampleImage, !page.isLocal {
                kfOptions.append(.cacheOriginalImage)
            }
            
            if let processor = processor {
                kfOptions.append(.processor(processor))
            }
            
            if Task.isCancelled {
                working = false
                return
            }
            downloadTask = KingfisherManager.shared.retrieveImage(with: source,
                                                                  options: kfOptions,
                                                                  progressBlock: { [weak self] in self?.handleProgressBlock($0, $1, source) },
                                                                  completionHandler: { [weak self] in self?.onImageProvided($0) })
            
        }
        
    }
    
    func onImageProvided(_ result: Result<RetrieveImageResult, KingfisherError>) {
        switch result {
            case let .success(imageResult):
                if page.CELL_KEY != imageResult.source.cacheKey {
                    working = false
                    return
                }
                // Hide Progress
                if progressModel.progress != 1 {
                    progressModel.setProgress(1)
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else {
                        return
                    }
                    self.resizeDelegate?.didLoadImage(at: self.indexPath, with: imageResult.image.size)
                    UIView.transition(with: self.imageView,
                                      duration: 0.33,
                                      options: [.transitionCrossDissolve, .allowUserInteraction],
                                      animations: {
                        self.progressView.isHidden = true
                        self.imageView.image = imageResult.image
                        
                    }) { _ in
                        self.imageView.addGestureRecognizer(self.zoomingTap)
                        self.imageView.isUserInteractionEnabled = true
                        self.working = false
                    }
                }
                
                //
            case let .failure(error):
                
                if error.isNotCurrentTask || error.isTaskCancelled {
                    return
                }
                
                handleImageFailure(error)
        }
    }
    
    func handleProgressBlock(_ recieved: Int64, _ total: Int64, _ source: Kingfisher.Source) {
        if source.cacheKey != page.CELL_KEY {
            downloadTask?.cancel()
            return
        }
        progressModel.setProgress(CGFloat(recieved) / CGFloat(total))
    }
    
    func handleImageFailure(_ error: Error) {
        progressModel.setError(error, reload)
        progressView.isHidden = false
    }
}

extension VerticalImageCell {
    var downSampleImage: Bool {
        UserDefaults.standard.bool(forKey: STTKeys.DownsampleImages)
    }
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        return layoutAttributes
    }
}
