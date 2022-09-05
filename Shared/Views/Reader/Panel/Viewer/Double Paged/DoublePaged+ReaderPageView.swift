//
//  DoublePaged+ReaderPageView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-04.
//

import Combine
import Foundation
import Kingfisher
import SwiftUI
import UIKit

extension DoublePagedViewer {
    class DImageView: UIView {
        let imageView = UIImageView()
        var page: ReaderView.Page!
        var indexPath: IndexPath!

        var progressView: UIView!
        var progressModel = ReaderView.ProgressObject()
        var downloadTask: DownloadTask?
        var subscriptions = Set<AnyCancellable>()
        weak var lm: DoublePagedLayoutManager?

        init() {
            super.init(frame: UIScreen.main.bounds)
            setupViews()
            subscribe()
        }

        func cancelTasks() {
            downloadTask?.cancel()
            imageView.kf.cancelDownloadTask()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func setupViews() {
            // Panel Delegate
            progressView = UIHostingController(rootView: ReaderView.PageProgressView(model: progressModel)).view!
            progressView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(progressView)

            imageView.frame = UIScreen.main.bounds
            imageView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(imageView)

            imageView.contentMode = .scaleAspectFit
            activateConstraints()
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
                    self?.cancelTasks()
                    self?.setImage()
                }.store(in: &subscriptions)
        }

        func activateConstraints() {
            heightContraint = imageView.heightAnchor.constraint(equalToConstant: 0)
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
                imageView.widthAnchor.constraint(equalTo: widthAnchor),

                progressView.widthAnchor.constraint(equalTo: widthAnchor),
                progressView.heightAnchor.constraint(equalTo: heightAnchor),
                progressView.centerXAnchor.constraint(equalTo: centerXAnchor),
                progressView.centerYAnchor.constraint(equalTo: centerYAnchor),

            ])
        }

//        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
//            print("Image Event")
//            return super.point(inside: point, with: event)
//
//        }

        var heightContraint: NSLayoutConstraint?
        func updateHeightConstraint(size: CGSize) {
            print(frame.size)
            let ratio = size.width / size.height
            var height = size.height / size.width * frame.width
            height = min(height, frame.height)
            heightContraint?.constant = height
            heightContraint?.isActive = false
            heightContraint = nil
            heightContraint = imageView.heightAnchor.constraint(equalToConstant: height)
            heightContraint?.priority = .required
            heightContraint?.isActive = true

            if ratio >= 1 {
                // Call Delegate
                lm?.resizeToSingle(page: page)
            }
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
                .requestModifier(AsyncImageModifier()),
                .backgroundDecode,
            ]

            // Local Page, Cache to memory only
            if page.isLocal {
                kfOptions += [.cacheMemoryOnly]
            }

            // Has Processor & Not Local, Cache Original Image to disk
            if cropWhiteSpaces || downSampleImage, !page.isLocal {
                kfOptions += [.cacheOriginalImage]
            }

            // Declare Processor
            var processor: ImageProcessor? = ResizingImageProcessor(referenceSize: frame.size, mode: .aspectFit)

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
                        self.imageView.isUserInteractionEnabled = true
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
}

extension DoublePagedViewer.DImageView {
    var downSampleImage: Bool {
        UserDefaults.standard.bool(forKey: STTKeys.DownsampleImages)
    }

    var cropWhiteSpaces: Bool {
        UserDefaults.standard.bool(forKey: STTKeys.CropWhiteSpaces)
    }
}

protocol DoublePagedLayoutManager: NSObject {
    func resizeToSingle(page: ReaderView.Page)
}
