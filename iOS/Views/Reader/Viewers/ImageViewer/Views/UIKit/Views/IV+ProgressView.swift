//
//  IV+ProgressView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import UIKit

class CircularProgressView: UIView {
    // MARK: awakeFromNib

    override func awakeFromNib() {
        super.awakeFromNib()
        setupView()
    }

    // MARK: Public

    var lineWidth: CGFloat = 5.5 {
        didSet {
            foregroundLayer.lineWidth = lineWidth
            backgroundLayer.lineWidth = lineWidth - (0.20 * lineWidth)
        }
    }

    var safePercent: Int = 100

    func setProgress(to progressConstant: Double, withAnimation: Bool) {
        var progress: Double {
            if progressConstant > 1 { return 1 }
            else if progressConstant < 0 { return 0 }
            else { return progressConstant }
        }

        foregroundLayer.strokeEnd = CGFloat(progress)

        if withAnimation {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = 0
            animation.toValue = progress
            animation.duration = 2
            foregroundLayer.add(animation, forKey: "foregroundAnimation")
        }

        var currentTime: Double = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if currentTime >= 2 {
                timer.invalidate()
            } else {
                currentTime += 0.05
            }
        }
        timer.fire()
    }

    // MARK: Private

    private let foregroundLayer = CAShapeLayer()
    private let backgroundLayer = CAShapeLayer()
    private var radius: CGFloat = 20

    private var pathCenter: CGPoint { return convert(center, from: superview) }
    private func makeBar() {
        layer.sublayers = nil
        drawBackgroundLayer()
        drawForegroundLayer()
    }

    private func drawBackgroundLayer() {
        let path = UIBezierPath(arcCenter: pathCenter, radius: radius, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
        backgroundLayer.path = path.cgPath
        backgroundLayer.strokeColor = UIColor(Preferences.standard.accentColor).cgColor
        backgroundLayer.lineWidth = lineWidth - (lineWidth * 20 / 100)
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.opacity = 0.275
        layer.addSublayer(backgroundLayer)
    }

    private func drawForegroundLayer() {
        let startAngle = (-CGFloat.pi / 2)
        let endAngle = 2 * CGFloat.pi + startAngle

        let path = UIBezierPath(arcCenter: pathCenter, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)

        foregroundLayer.lineCap = CAShapeLayerLineCap.round
        foregroundLayer.path = path.cgPath
        foregroundLayer.lineWidth = lineWidth
        foregroundLayer.fillColor = UIColor.clear.cgColor
        foregroundLayer.strokeColor = UIColor(Preferences.standard.accentColor).cgColor
        foregroundLayer.strokeEnd = 0

        layer.addSublayer(foregroundLayer)
    }

    private func setupView() {
        makeBar()
    }

    // Layout Sublayers
    private var layoutDone = false
    override func layoutSublayers(of _: CALayer) {
        if !layoutDone {
            setupView()
            layoutDone = true
        }
    }
}
