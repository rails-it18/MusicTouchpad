//
//  DefaultSoundSource.swift
//  MusicThing
//
//  Created by Ethan Jud on 2/1/17.
//  Copyright © 2017 Ethan Jud. All rights reserved.
//

import UIKit
import AudioKit

class DefaultSoundSource: NSObject, MusicTouchSoundSource {

    private let soundCount = 10

    private var unusedSounds: [DefaultSound]

    private let mixer = AKMixer()

    private class DefaultSound: MusicTouchSound {
        private let oscillator: AKOscillator
        private let envelope: AKAmplitudeEnvelope

        init() {
            oscillator = AKOscillator()
            oscillator.start()

            envelope = AKAmplitudeEnvelope(oscillator)
            envelope.attackDuration = 0.02
            envelope.decayDuration = 0.1
            envelope.sustainLevel = 1.0
            envelope.releaseDuration = 0.02
        }

        var node: AKNode {
            return envelope
        }

        func stop() {
            envelope.stop()
        }

        // MARK: - MusicTouchSound

        func start(withFrequency frequency: Double, amplitude: Double) {
            oscillator.frequency = frequency
            oscillator.amplitude = amplitude
            envelope.start()
        }

        func update(withFrequency frequency: Double, amplitude: Double) {
            oscillator.frequency = frequency
            oscillator.amplitude = amplitude
        }
    }

    // MARK: - Public

    var audioKitNode: AKNode {
        return mixer
    }

    override init() {
        // Generate an array of sound objects
        unusedSounds = (1...soundCount).map { _ in
            return DefaultSound()
        }

        super.init()

        // Connect nodes to mixer
        for sound in unusedSounds {
            mixer.connect(sound.node)
        }

        mixer.start()
    }

    // MARK: - MusicTouchSoundSource

    func getSound() -> MusicTouchSound? {
        if unusedSounds.isEmpty {
            return nil
        }

        // Pop from unused stack, move to map
        return unusedSounds.removeLast()
    }

    func finished(withSound sound: MusicTouchSound) {
        if let sound = sound as? DefaultSound {
            sound.stop()
            unusedSounds.append(sound)
        }
    }
}
