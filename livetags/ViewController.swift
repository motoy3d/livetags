//
//  ViewController.swift
//  livetags
//
//  Created by Motoi Kataoka on 2019/06/23.
//  Copyright © 2019 Motoi Kataoka. All rights reserved.
//
import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {
    
    var videoDevice: AVCaptureDevice?
    var videoLayer: AVCaptureVideoPreviewLayer!
    let fileOutput = AVCaptureMovieFileOutput()
    
    var recordButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black
        self.setUpCamera()
    }
    
    // カメラの入力設定とUI構築を行う
    func setUpCamera() {
        let captureSession: AVCaptureSession = AVCaptureSession()
        self.videoDevice = self.defaultCamera()
        let audioDevice: AVCaptureDevice? = AVCaptureDevice.default(for: AVMediaType.audio)
        
        // ビデオ入力
        let videoInput: AVCaptureDeviceInput = try! AVCaptureDeviceInput(device: videoDevice!)
        captureSession.addInput(videoInput)
        
        // 音声入力
        let audioInput = try! AVCaptureDeviceInput(device: audioDevice!)
        captureSession.addInput(audioInput)
        
        // 録画の最長時間の設定(１時間)
        self.fileOutput.maxRecordedDuration = CMTimeMake(value: 3600, timescale: 1)
        
        captureSession.addOutput(self.fileOutput)
        
        // 動画画質
        captureSession.beginConfiguration()
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }
        captureSession.commitConfiguration()
        
        // 出力設定
//        let videoDataOutput = AVCaptureVideoDataOutput()
//        captureSession.addOutput(videoDataOutput)
        
        captureSession.startRunning()
        
        // ビデオプレビューレイヤー
        videoLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoLayer.frame = self.view.bounds
        videoLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        // 向きを設定
//        videoLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
        if let orientation = self.convertUIOrientation2VideoOrientation() {
            videoLayer.connection?.videoOrientation = orientation
            fileOutput.connection(with: .video)?.videoOrientation = orientation
            print("初回向きを設定 " + String(orientation.rawValue))
        }
        
        self.view.layer.addSublayer(videoLayer)
        
        // ズームスライダー
        let slider: UISlider = UISlider()
        let sliderWidth: CGFloat = self.view.bounds.width * 0.75
        let sliderHeight: CGFloat = 40
        let sliderRect: CGRect = CGRect(x: (self.view.bounds.width - sliderWidth) / 2, y: self.view.bounds.height - 120, width: sliderWidth, height: sliderHeight)
        slider.frame = sliderRect
        slider.minimumValue = 0.0
        slider.maximumValue = 1.0
        slider.value = 0.0
        slider.addTarget(self, action: #selector(self.onSliderChanged(sender:)), for: .valueChanged)
        self.view.addSubview(slider)
        
        // Recordingボタン
        self.recordButton = UIButton(frame: CGRect(x: 0, y: 0, width: 120, height: 50))
        self.recordButton.backgroundColor = UIColor.gray
        self.recordButton.layer.masksToBounds = true
        self.recordButton.setTitle("Record", for: .normal)
        self.recordButton.layer.cornerRadius = 20
        self.recordButton.layer.position = CGPoint(x: self.view.bounds.width - 150, y:self.view.bounds.height - 50)
        self.recordButton.addTarget(self, action: #selector(self.onClickRecordButton(sender:)), for: .touchUpInside)
        self.view.addSubview(recordButton)
    }
    
    //
    // デフォルトカメラインスタンスを返す。デュアルカメラがあればそれを返し、なければワイドアングルカメラを返す。
    //
    func defaultCamera() -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInDualCamera, for: AVMediaType.video, position: .back) {
            print("カメラ:デュアルカメラ")
            return device
        } else if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back) {
            print("カメラ:ワイドアングルカメラ")
            return device
        } else {
            return nil
        }
    }
    
    // Recordingボタンを押したときの処理
    // 録画開始・録画終了
    @objc func onClickRecordButton(sender: UIButton) {
        if self.fileOutput.isRecording {
            // 録画終了
            fileOutput.stopRecording()
            
            self.recordButton.backgroundColor = .gray
            self.recordButton.setTitle("Record", for: .normal)
        } else {
            // 録画開始。ドキュメントディレクトリに保存。iOSの「ファイル」アプリで見れる
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
//            let directory = "....";
//DIR追加            let urlDirectory = urlPath.appendingPathComponent(directory, isDirectory: true)
            let filePath: URL = URL(fileURLWithPath: documentsPath + "/myvideo.mov")
            fileOutput.startRecording(to: filePath, recordingDelegate: self)
            
            self.recordButton.backgroundColor = .red
            self.recordButton.setTitle("●Recording", for: .normal)
        }
    }
    
    // ズーム変更時の処理
    @objc func onSliderChanged(sender: UISlider) {
        // zoom in / zoom out
        do {
            try self.videoDevice?.lockForConfiguration()
            self.videoDevice?.ramp(
                toVideoZoomFactor: (self.videoDevice?.minAvailableVideoZoomFactor)! + CGFloat(sender.value) * ((self.videoDevice?.maxAvailableVideoZoomFactor)! - (self.videoDevice?.minAvailableVideoZoomFactor)!),
                withRate: 30.0)
            self.videoDevice?.unlockForConfiguration()
        } catch {
            print("Failed to change zoom.")
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("fileOutput. " + outputFileURL.absoluteString)
        if error != nil {print(error.debugDescription)}
    }
 
    // UIInterfaceOrientation -> AVCaptureVideoOrientationにConvert
    func convertUIOrientation2VideoOrientation() -> AVCaptureVideoOrientation? {
        let newOrientation: AVCaptureVideoOrientation
        switch UIDevice.current.orientation {
            case .portrait:
                newOrientation = .portrait
            case .portraitUpsideDown:
                newOrientation = .portraitUpsideDown
            case .landscapeLeft:
                newOrientation = .landscapeRight
            case .landscapeRight:
                newOrientation = .landscapeLeft
            default :
                newOrientation = .portrait
        }
        return newOrientation
//        let v = f()
//        switch v {
//        case UIDeviceOrientation.unknown: return nil
//        default:
//            return ([
//                .portrait: .portrait,
//                .portraitUpsideDown: .portraitUpsideDown,
//                .landscapeLeft: .landscapeRight,
//                .landscapeRight: .landscapeLeft
//                ])[v]
//        }
    }
    
    func appOrientation() -> UIDeviceOrientation {
//        return UIApplication.shared.statusBarOrientation
        return UIDevice.current.orientation
    }
    
    // 画面の回転にも対応したい時は viewWillTransitionToSize で同じく向きを教える。
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(
            alongsideTransition: nil,
            completion: {(UIViewControllerTransitionCoordinatorContext) in
                //画面の回転後に向きを教える。
                if let orientation = self.convertUIOrientation2VideoOrientation() {
                    self.videoLayer.connection?.videoOrientation = orientation
                    self.fileOutput.connection(with: .video)?.videoOrientation = orientation
                    print("回転時に向きを設定 " + String(orientation.rawValue))
                }
            }
        )
    }
}
