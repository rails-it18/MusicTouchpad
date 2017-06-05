//
//  MusicTouchView.swift
//  MusicThing
//
//  Created by Ethan Jud on 12/10/16.
//  Copyright © 2016 Ethan Jud. All rights reserved.
//

import UIKit

protocol MusicTouchSound {
    func start(withFrequency frequency: Double, amplitude: Double)
    func update(withFrequency frequency: Double, amplitude: Double)
}

protocol MusicTouchSoundSource: class {
    func getSound() -> MusicTouchSound?
    func finished(withSound sound: MusicTouchSound)
}

class MusicTouchView: UIView {

    @IBInspectable var rowCount: Int = 5 {
        didSet {
            setNeedsDisplay()
        }
    }

    @IBInspectable var columnCount: Int = 8 {
        didSet {
            setNeedsDisplay()
        }
    }

    weak var soundSource: MusicTouchSoundSource?

    private var forceTouchAvailable: Bool = false

    private let frequencyConverter = NoteFrequencyConverter(baseNote: .G, baseOctave: 2)

    private let snapDistance: CGFloat = 20.0
    private let rowEdgeOffset: CGFloat = 40.0

    private class SoundCache {
        // To keep track of sounds, we use the address of the UITouch object
        //  as a dictionary key. Unfortunately this means if we don't correctly
        //  respond to touch events, we will leak sound objects.
        // Up to two sounds are needed for each touch to support blending
        //  sounds when transitioning between rows of "keys" on the touchpad.
        // For this, we use oddSound for the odd-numbered row and evenSound
        //  for the even-numbered row
        private typealias SoundMapKey = UnsafeMutableRawPointer
        struct SoundMapValue {
            let oddSound: MusicTouchSound
            let evenSound: MusicTouchSound
        }

        private var soundMap: [SoundMapKey: SoundMapValue] = [:]

        func sounds(forTouch touch: UITouch) -> SoundMapValue? {
            let key = mapKeyForTouch(touch: touch)
            return soundMap[key]
        }

        func setSounds(_ sounds: SoundMapValue, forTouch touch: UITouch) {
            let key = mapKeyForTouch(touch: touch)
            soundMap[key] = sounds
        }

        func removeSounds(forTouch touch: UITouch) -> SoundMapValue? {
            let key = mapKeyForTouch(touch: touch)
            return soundMap.removeValue(forKey: key)
        }

        private func mapKeyForTouch(touch: UITouch) -> SoundMapKey {
            return Unmanaged.passUnretained(touch).toOpaque()
        }
    }

    private let soundCache = SoundCache()

    private var spaceBetweenRowLines: CGFloat {
        let numberOfSpaces = rowCount - 1
        return (self.bounds.size.height - 2.0 * rowEdgeOffset) / CGFloat(numberOfSpaces)
    }

    private var spaceBetweenNoteLines: CGFloat {
        return self.bounds.size.width / CGFloat(columnCount)
    }
    private var noteEdgeOffset: CGFloat {
        return spaceBetweenNoteLines / 2.0
    }

    required override init(frame: CGRect) {
        super.init(frame: frame)
        refreshForceTouchCapability()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        refreshForceTouchCapability()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        //TODO: Test this on a device
        refreshForceTouchCapability()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext()
            else { return }

        UIColor.black.setStroke()

        context.setLineWidth(1.0)

        let crosshairWidth: CGFloat = 5.0
        let crosshairHeight: CGFloat = 5.0

        for row in (0 ..< rowCount) {
            let y = rowEdgeOffset + CGFloat(row) * spaceBetweenRowLines

            for col in (0 ..< columnCount) {
                let x = noteEdgeOffset + CGFloat(col) * spaceBetweenNoteLines

                context.move(to: CGPoint(x: x - 0.5 * crosshairWidth, y: y))
                context.addLine(to: CGPoint(x: x + 0.5 * crosshairWidth, y: y))

                context.move(to: CGPoint(x: x, y: y - 0.5 * crosshairHeight))
                context.addLine(to: CGPoint(x: x, y: y + 0.5 * crosshairHeight))

                context.addRect(CGRect(x: x - snapDistance, y: y - snapDistance, width: 2.0 * snapDistance, height: 2.0 * snapDistance))
            }
        }

        context.drawPath(using: .stroke)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let oddSound = soundSource?.getSound()
                else { continue }

            guard let evenSound = soundSource?.getSound()
                else { continue }

            soundCache.setSounds(SoundCache.SoundMapValue(oddSound: oddSound, evenSound: evenSound), forTouch: touch)

            let params = soundParameters(forTouch: touch)

            oddSound.start(withFrequency: params.odd.frequency, amplitude: params.odd.amplitude)
            evenSound.start(withFrequency: params.even.frequency, amplitude: params.even.amplitude)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let sounds = soundCache.sounds(forTouch: touch)
                else { continue }

            let params = soundParameters(forTouch: touch)
            sounds.oddSound.update(withFrequency: params.odd.frequency, amplitude: params.odd.amplitude)
            sounds.evenSound.update(withFrequency: params.even.frequency, amplitude: params.even.amplitude)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let sounds = soundCache.removeSounds(forTouch: touch) {
                soundSource?.finished(withSound: sounds.oddSound)
                soundSource?.finished(withSound: sounds.evenSound)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let sounds = soundCache.removeSounds(forTouch: touch) {
                soundSource?.finished(withSound: sounds.oddSound)
                soundSource?.finished(withSound: sounds.evenSound)
            }
        }
    }

    //MARK: Private

    private func refreshForceTouchCapability() {
        //TODO: Remove this check. This seems ridiculous, but I'm getting
        //  forceTouchCapability set to available for the iOS Simulator
        if (TARGET_OS_SIMULATOR != 0) {
            forceTouchAvailable = false
        } else {
            forceTouchAvailable = (self.traitCollection.forceTouchCapability == .available)
        }
    }

    private struct SoundParameters {
        struct SingleSoundParam {
            let frequency: Double
            let amplitude: Double
        }

        let odd: SingleSoundParam
        let even: SingleSoundParam
    }
    private func soundParameters(forTouch touch: UITouch) -> SoundParameters {
        let point = touch.location(in: self)

        let rowInfo = rowComputationForOffset(y: point.y)

        let oddNoteOffset = noteOffset(x: point.x, row: rowInfo.odd)
        let evenNoteOffset = noteOffset(x: point.x, row: rowInfo.even)

        let totalAmplitude = amplitudeForTouch(touch: touch)

        let oddParam = SoundParameters.SingleSoundParam(
            frequency: frequencyConverter.frequency(forStepOffset: oddNoteOffset),
            amplitude: totalAmplitude * (1.0 - rowInfo.oddToEvenBlend))
        let evenParam = SoundParameters.SingleSoundParam(
            frequency: frequencyConverter.frequency(forStepOffset: evenNoteOffset),
            amplitude: totalAmplitude * rowInfo.oddToEvenBlend)

        return SoundParameters(odd: oddParam, even: evenParam)
    }

    private func noteOffset(x: CGFloat, row: Int) -> Double {
        let halfStepsForRow = halfStepsAboveRowBaseForOffset(x: x)

        return Double((rowCount - row - 1) * 7) + halfStepsForRow
    }

    private func halfStepsAboveRowBaseForOffset(x: CGFloat) -> Double {
        let halfStepsAboveBase = Double((x - noteEdgeOffset) / spaceBetweenNoteLines)
        let lowerBoundNoteLine = floor(halfStepsAboveBase)
        let lowerBoundNoteLineOffset = noteEdgeOffset + CGFloat(lowerBoundNoteLine) * spaceBetweenNoteLines
        let closerToLower = (x - lowerBoundNoteLineOffset < spaceBetweenNoteLines / 2.0)
        let nearestNoteLine = closerToLower ? lowerBoundNoteLine : (lowerBoundNoteLine + 1)
        let nearestNoteLineOffset = noteEdgeOffset + CGFloat(nearestNoteLine) * spaceBetweenNoteLines
        let distanceFromNearestNote = abs(x - nearestNoteLineOffset)

        if distanceFromNearestNote <= snapDistance {
            // Snap to nearest note
            return nearestNoteLine
        } else {
            let distFromLastSnap = x - lowerBoundNoteLineOffset - snapDistance
            let distBetweenSnaps = spaceBetweenNoteLines - 2.0 * snapDistance

            return lowerBoundNoteLine + Double(distFromLastSnap / distBetweenSnaps)
        }
    }

    private func rowComputationForOffset(y: CGFloat) -> (odd: Int, even: Int, oddToEvenBlend: Double) {
        let distFromFirstRow = y - rowEdgeOffset
        let lowerBoundRow = Int(floor((distFromFirstRow + snapDistance) / spaceBetweenRowLines))

        let isLowerBoundEven = (lowerBoundRow % 2 == 0)

        let oddRow = (isLowerBoundEven ? lowerBoundRow + 1 : lowerBoundRow)
        let evenRow = (isLowerBoundEven ? lowerBoundRow : lowerBoundRow + 1)


        let lowerBoundRowMaximumOffset = rowEdgeOffset + CGFloat(lowerBoundRow) * spaceBetweenRowLines + snapDistance

        let distanceFromLower = max(0.0, y - lowerBoundRowMaximumOffset)
        let blendableDistance = spaceBetweenRowLines - (2.0 * snapDistance)
        let blendValue = Double(distanceFromLower / blendableDistance)

        let oddToEvenBlend = isLowerBoundEven ? (1.0 - blendValue) : blendValue

        return (odd: oddRow, even: evenRow, oddToEvenBlend: oddToEvenBlend)
    }

    private func amplitudeForTouch(touch: UITouch) -> Double {
        if (forceTouchAvailable) {
        return Double(touch.force) / 6.67
        } else {
            return 1.0
        }
    }
}
