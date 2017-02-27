//
//  NoteFrequencyConverter.swift
//  MusicThing
//
//  Created by Ethan Jud on 2/1/17.
//  Copyright © 2017 Ethan Jud. All rights reserved.
//

import UIKit

enum Note: Int {
    case A      = 0
    case ASharp = 1
    case B      = 2
    case C      = 3
    case CSharp = 4
    case D      = 5
    case DSharp = 6
    case E      = 7
    case F      = 8
    case FSharp = 9
    case G      = 10
    case GSharp = 11
}

struct MusicConstants {
    static let frequencyA0 = 27.50
}

class NoteFrequencyConverter: NSObject {
    private let baseStepsAboveA0: Int

    init(baseNote: Note, baseOctave: Int) {
        baseStepsAboveA0 = 12 * baseOctave + baseNote.rawValue
    }

    func frequency(forStepOffset stepOffset: Double) -> Double {
        let absStepOffset = Double(baseStepsAboveA0) + stepOffset
        let octavesAboveA0 = absStepOffset / 12.0

        return MusicConstants.frequencyA0 * pow(2.0, octavesAboveA0)
    }
}
