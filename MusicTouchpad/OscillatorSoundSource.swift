//
//  OscillatorSoundSource.swift
//  MusicThing
//
//  Created by Ethan Jud on 2/1/17.
//  Copyright © 2017 Ethan Jud. All rights reserved.
//

import UIKit
import AudioKit

class OscillatorSoundSource: NSObject, MusicTouchSoundSource {

    private let oscillatorCount = 10

    private var unusedOscillators: [AKOscillator]

    private let mixer = AKMixer()

    private class OscillatorSound: MusicTouchSound {
        let oscillator: AKOscillator

        init?(oscillator: AKOscillator) {
            self.oscillator = oscillator
        }

        func start(withFrequency frequency: Double, amplitude: Double) {
            oscillator.frequency = frequency
            oscillator.amplitude = amplitude
            oscillator.start()
        }

        func update(withFrequency frequency: Double, amplitude: Double) {
            oscillator.frequency = frequency
            oscillator.amplitude = amplitude
        }
    }

    //MARK: Public

    var audioKitNode: AKNode {
        return mixer
    }

    override init() {
        unusedOscillators = (1...oscillatorCount).map { _ in
            return AKOscillator()
        }

        super.init()

        // Connect nodes to mixer
        for osc in unusedOscillators {
            mixer.connect(osc)
        }

        mixer.start()
    }

    //MARK: MusicTouchSoundSource

    func getSound() -> MusicTouchSound? {
        if unusedOscillators.isEmpty {
            return nil
        }

        // Pop from unused stack, move to map
        return OscillatorSound(oscillator: unusedOscillators.removeLast())
    }

    func finished(withSound sound: MusicTouchSound) {
        if let oscSound = sound as? OscillatorSound {
            oscSound.oscillator.stop()
            unusedOscillators.append(oscSound.oscillator)
        }
    }
}
