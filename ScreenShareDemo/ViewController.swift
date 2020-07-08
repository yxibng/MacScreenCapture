//
//  ViewController.swift
//  ScreenShareDemo
//
//  Created by yxibng on 2020/6/17.
//  Copyright © 2020 yxibng. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    deinit {
        self.capturer.stop()
    }
    
    lazy var capturer: DbyVideoCapturer = DbyVideoCapturer.init(delegate: self)
    
    @IBOutlet weak var videoView: DbyPreviewVideoView!
    override func viewDidLoad() {
        super.viewDidLoad()
        capturer.start()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}

extension ViewController: DbyVideoCapturerDelegate {
    func videoCapturer(_ capturer: DbyVideoCapturer, didReceive sampleBuffer: CMSampleBuffer) {
        
    }
    
    func videoCapturer(_ capturer: DbyVideoCapturer, didStartWithStatus status: Int32) {
        print("\(#function) \(status)")
        self.videoView.setSession(capturer.session)
        
    }
    func videoCapturer(_ capturer: DbyVideoCapturer, didStopWithStatus status: Int32) {
        print("\(#function) \(status)")
    }
    
    func videoCapturer(_ capturer: DbyVideoCapturer, didReceive pixelBuffer: CVPixelBuffer) {
        //print(pixelBuffer)
    }
    
}

