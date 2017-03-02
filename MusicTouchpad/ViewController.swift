//
//  ViewController.swift
//  MusicTouchpad
//
//  Created by Ethan Jud on 2/27/17.
//  Copyright © 2017 Ethan Jud. All rights reserved.
//

import UIKit
import AudioKit

class ViewController: UIViewController {

    @IBOutlet weak var musicTouchView: MusicTouchView!

    private let soundSource = DefaultSoundSource()

    override func viewDidLoad() {
        super.viewDidLoad()

        musicTouchView.soundSource = soundSource

        AudioKit.output = soundSource.audioKitNode
        AudioKit.start()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
