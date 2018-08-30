//
//  ViewController.swift
//  CameraMotionLogger
//
//  Created by Hastings Greer on 8/29/18.
//  Copyright © 2018 Kitware. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMotion
import Vision
import VideoToolbox



class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate{

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        motionManager = CMMotionManager()
        motionManager?.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xArbitraryZVertical
            , to: OperationQueue(), withHandler: { (motion:CMDeviceMotion?, e: Error?) in
                self.logEstimatedRotation(motion:motion!)
        })
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        amRecording  = false
    }
    @IBOutlet weak var yaw_label: UILabel!
    @IBOutlet weak var pitch_label: UILabel!
    @IBOutlet weak var roll_label: UILabel!
    @IBOutlet weak var time_label: UILabel!
    
    @IBOutlet weak var rand_pix: UILabel!
    @IBOutlet weak var preview: UIView!
    var motionManager: CMMotionManager?
    
    var i = 0
    
    var motionEvents: [[Double]] = []
    var imagesAndTimestamps: [(Double, Data)] = []
    var amRecording = false
    
    @IBAction func record(_ sender: Any) {
        amRecording = true
        imagesAndTimestamps = []
        motionEvents = []
    }
    @IBAction func stop(_ sender: Any) {
        amRecording = false
    }
    @IBAction func submit(_ sender: Any) {
        amRecording = false
        let imagesTimestampsCopy = imagesAndTimestamps
        imagesAndTimestamps = []
        let base = "http://hastings-alien.local/"
        guard let url = URL(string:base + "upload") else {return};
        let motion_json = try? JSONSerialization.data(withJSONObject: motionEvents)
        var request = URLRequest(url:url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let task = URLSession.shared.uploadTask(with: request, from: motion_json!){data, response, error in
            print(response, error?.localizedDescription)
            return
        }
   
        task.resume()
        
        for datapoint in imagesTimestampsCopy {
            let imageurl = URL(string:base + "imageupload/" + String(format:"%f", datapoint.0))
            var request = URLRequest(url:imageurl!)
            request.httpMethod = "POST"
            //let boundary = "thequickbrownfoxjumpsoverthelazydog"
            request.setValue("image/png", forHTTPHeaderField: "Content-Type")
            let task = URLSession.shared.uploadTask(with: request, from: datapoint.1){data, response, error in
                print(response, error?.localizedDescription)
                return
            }
            task.resume()
         
            
        }
        
        
        
        
        
    }
    
    //https://www.pyimagesearch.com/2018/04/23/running-keras-models-on-ios-with-coreml/
    
    func setupCaptureSession() {
        // create a new capture session
        let captureSession = AVCaptureSession()
        
        // find the available cameras
        let availableDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .front).devices
        
        do {
            // select a camera
            if let captureDevice = availableDevices.first {
                captureSession.addInput(try AVCaptureDeviceInput(device: captureDevice))
            }
        } catch {
            // print an error if the camera is not available
            print(error.localizedDescription)
        }
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        // setup the video output to the screen and add output to our capture session
        let captureOutput = AVCaptureVideoDataOutput()
        captureSession.addOutput(captureOutput)
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = preview.frame
        view.layer.addSublayer(previewLayer)
        
        // buffer the video and start the capture session
        captureOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.startRunning()
    }
    func logEstimatedRotation(motion: CMDeviceMotion){
        let attitude = motion.attitude
        let time = Date().timeIntervalSince1970
        if amRecording {
            motionEvents.append([attitude.roll, attitude.yaw, attitude.pitch, time])
        }
        DispatchQueue.main.async {
            self.roll_label.text = String(format: "%f", attitude.roll)
            self.yaw_label.text = String(format: "%f", attitude.yaw)
            self.pitch_label.text = String(format: "%f", attitude.pitch)
            self.time_label.text = String(format: "%f", time)
            
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let time = Date().timeIntervalSince1970
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, nil, &cgImage)
        let uiImage = UIImage(cgImage: cgImage!)
        let png = UIImagePNGRepresentation(uiImage)
        
        if amRecording {
            imagesAndTimestamps.append((time, png!))
            
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let pointer = unsafeBitCast(CVPixelBufferGetBaseAddress(pixelBuffer), to: UnsafeMutablePointer<UInt32>.self)
        
        
        let firstPixel = pointer[5000];
        
        
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        i += 1;
        DispatchQueue.main.async {
            self.rand_pix.text = String(format: "%d", firstPixel)
        }
    }
}


