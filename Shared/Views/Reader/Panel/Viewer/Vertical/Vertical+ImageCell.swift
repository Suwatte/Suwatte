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
    var imageTask: ImageTask?
    var currentKey: String?

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
        currentKey = nil
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
        addSubview(progressView)

        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        activateConstraints()
        subscribe()
        
        currentKey = page.CELL_KEY
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
        imageTask?.cancel()
        downloadTask?.cancel()
        imageView.kf.cancelDownloadTask()
    }

    func setImage() {
        guard currentKey == page.CELL_KEY, imageView.image == nil, let source = page.toKFSource() else {
            return
        }

        Task { @MainActor in
            cancelTasks()
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

            downloadTask = KingfisherManager.shared.retrieveImage(with: source,
                                                                  options: kfOptions,
                                                                  progressBlock: { [weak self] in self?.handleProgressBlock($0, $1) },
                                                                  completionHandler: { [weak self] in self?.onImageProvided($0) })
        }
    }

    func onImageProvided(_ result: Result<RetrieveImageResult, KingfisherError>) {
        switch result {
        case let .success(imageResult):

            // Hide Progress
            if progressModel.progress != 1 {
                progressModel.setProgress(1)
            }
            DispatchQueue.main.async {
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

    func handleProgressBlock(_ recieved: Int64, _ total: Int64) {
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
