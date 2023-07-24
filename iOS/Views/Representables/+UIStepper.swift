//
//  +UIStepper.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-09.
//

import SwiftUI

struct StepperView: UIViewRepresentable {
    @Binding var value: Double
    var step: Double = 1
    var range: ClosedRange<Int> = 1 ... 10

    func makeUIView(context: Context) -> UIStepper {
        let stepper = UIStepper()
        stepper.minimumValue = Double(range.lowerBound)
        stepper.maximumValue = Double(range.upperBound)
        stepper.stepValue = Double(step)
        stepper.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        return stepper
    }

    func updateUIView(_ stepper: UIStepper, context _: Context) {
        stepper.value = value
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    class Coordinator: NSObject {
        var value: Binding<Double>

        init(value: Binding<Double>) {
            self.value = value
        }

        @objc func valueChanged(_ sender: UIStepper) {
            value.wrappedValue = Double(sender.value)
        }
    }
}
