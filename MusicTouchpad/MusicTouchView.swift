//
//  MusicTouchView.swift
//  MusicThing
//
//  Created by Ethan Jud on 12/10/16.
//  Copyright © 2016 Ethan Jud. All rights reserved.
//

import UIKit
import AudioKit

protocol MusicTouchSound {
    func start(withFrequency frequency: Double, amplitude: Double)
    func update(withFrequency frequency: Double, amplitude: Double)
}

protocol MusicTouchSoundSource: class {
    func getSound() -> MusicTouchSound?
    func finished(withSound sound: MusicTouchSound)
}

class MusicTouchView: UIView {

    weak var soundSource: MusicTouchSoundSource?

    private let frequencyConverter = NoteFrequencyConverter(baseNote: .G, baseOctave: 2)

    private let rowCount = 4
    private let colCount = 8

    private let snapDistance: CGFloat = 20.0
    private let rowEdgeOffset: CGFloat = 40.0

    private typealias SoundMapKey = UnsafeMutableRawPointer
    private var soundMap: [SoundMapKey: MusicTouchSound] = [:]

    private var spaceBetweenRowLines: CGFloat {
        let numberOfSpaces = rowCount - 1
        return (self.bounds.size.height - 2.0 * rowEdgeOffset) / CGFloat(numberOfSpaces)
    }

    private var spaceBetweenNoteLines: CGFloat {
        return self.bounds.size.width / CGFloat(colCount)
    }
    private var noteEdgeOffset: CGFloat {
        return spaceBetweenNoteLines / 2.0
    }

    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext()
            else { return }

        UIColor.black.setStroke()

        context.setLineWidth(1.0)

        let crosshairWidth: CGFloat = 5.0
        let crosshairHeight: CGFloat = 5.0

        for row in (0 ..< rowCount) {
            let y = rowEdgeOffset + CGFloat(row) * spaceBetweenRowLines

            for col in (0 ..< colCount) {
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
            // We need an unused oscillator for each touch
            let key = mapKeyForTouch(touch: touch)

            guard let sound = soundSource?.getSound()
                else { continue }

            soundMap[key] = sound

            let params = soundParameters(forTouch: touch)
            sound.start(withFrequency: params.frequency, amplitude: params.amplitude)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let key = mapKeyForTouch(touch: touch)
            if let sound = soundMap[key] {
                let params = soundParameters(forTouch: touch)
                sound.update(withFrequency: params.frequency, amplitude: params.amplitude)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let key = mapKeyForTouch(touch: touch)

            if let sound = soundMap.removeValue(forKey: key) {
                soundSource?.finished(withSound: sound)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let key = mapKeyForTouch(touch: touch)

            if let sound = soundMap.removeValue(forKey: key) {
                soundSource?.finished(withSound: sound)
            }
        }
    }

    private func mapKeyForTouch(touch: UITouch) -> SoundMapKey {
        return Unmanaged.passUnretained(touch).toOpaque()
    }

    private func soundParameters(forTouch touch: UITouch) -> (frequency: Double, amplitude: Double) {
        let point = touch.location(in: self)

        let noteIndex = noteIndexForPoint(point: point)
        let frequency = frequencyConverter.frequency(forStepOffset: noteIndex)
        return (frequency: frequency, amplitude: amplitudeForTouch(touch: touch))
    }

    private func noteIndexForPoint(point: CGPoint) -> Double {
        let halfStepsForRow = halfStepsAboveRowBaseForOffset(x: point.x)
        let row = rowForOffset(y: point.y)

        return (rowCount - row - 1) * 7.0 + halfStepsForRow
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

    private func rowForOffset(y: CGFloat) -> Int {
        let distFromFirstRow = y - rowEdgeOffset
        let lowerBoundRow = Int(floor(distFromFirstRow / spaceBetweenRowLines))
        let lowerBoundRowOffset = rowEdgeOffset + CGFloat(lowerBoundRow) * spaceBetweenRowLines

        let closerToLower = (y - lowerBoundRowOffset < spaceBetweenRowLines / 2.0)
        let nearestRowLine = closerToLower ? lowerBoundRow : (lowerBoundRow + 1)

        return nearestRowLine
    }

    private func amplitudeForTouch(touch: UITouch) -> Double {
        return Double(touch.force) / 6.67
    }
}
