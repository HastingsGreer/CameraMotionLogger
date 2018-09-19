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
        
        self.syncClockThenSetup()
        
        // Do any additional setup after loading the view, typically from a nib.
        
       
    }
    func setup() {
        self.setupCaptureSession()
        self.motionManager = CMMotionManager()
        self.motionManager?.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xArbitraryZVertical
            , to: OperationQueue(), withHandler: { (motion:CMDeviceMotion?, e: Error?) in
                self.logEstimatedRotation(motion:motion!)
        })
    }
    
    func syncClockThenSetup(){
        var t1 = Date().timeIntervalSince1970
        
        guard let url = URL(string:base + "time") else {return};
        
        var request = URLRequest(url:url)
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            let t2 = Date().timeIntervalSince1970
            let computer_t = Double(String(data: data!, encoding: .utf8)!)!
            print(t1, computer_t, t2)
            if t2 - t1 > 0.11{
                self.syncClockThenSetup()
            } else {
                self.secs_ahead_of_computer = (t1 + t2) / 2 - computer_t
                DispatchQueue.main.async {
                    self.setup()
                }
            }
        })
        t1 = Date().timeIntervalSince1970
        task.resume()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("memorywarning")
        amRecording  = false
    }
    @IBOutlet weak var yaw_label: UILabel!
    @IBOutlet weak var pitch_label: UILabel!
    @IBOutlet weak var unsubmitted_events_label: UILabel!
    @IBOutlet weak var roll_label: UILabel!
    @IBOutlet weak var time_label: UILabel!
    
    @IBOutlet weak var successfully_submitted: UILabel!
    @IBOutlet weak var rand_pix: UILabel!
    @IBOutlet weak var preview: UIView!
    var motionManager: CMMotionManager?
    
    var i = 0
    var submitted_count = 0
    var secs_ahead_of_computer = 0.0
    
    var motionEvents: [[Double]] = []
    var imagesAndTimestamps: [(Double, Data)] = []
    var amRecording = false
    
    var base = "http://hastings-alien.local/"
    func clear() {
        i = 0
        submitted_count = 0
        imagesAndTimestamps = []
        motionEvents = []
    }
    @IBAction func record(_ sender: Any) {
        clear()
        amRecording = true
        
        
    }
    @IBAction func stop(_ sender: Any) {
        amRecording = false
    }
    @IBAction func submit(_ sender: Any) {
        amRecording = false
        let imagesTimestampsCopy = imagesAndTimestamps
        imagesAndTimestamps = []
        
        guard let url = URL(string:base + "upload") else {return};
        let motion_json = try? JSONSerialization.data(withJSONObject: motionEvents)
        var request = URLRequest(url:url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let task = URLSession.shared.uploadTask(with: request, from: motion_json!){data, response, error in
            //print(response, error?.localizedDescription)
            if let response_http = response as? HTTPURLResponse {
                //print(response_http)
            
                if response_http.statusCode == 200 {
                    print("success_json")
                    self.motionEvents = []
                    
                }
            }
            return
        }
   
        task.resume()
        
        for datapoint in imagesTimestampsCopy {
            submitImageDatapoint(datapoint: datapoint)
        }
        
    }
    
    func submitImageDatapoint(datapoint: (Double, Data)) {
        let imageurl = URL(string:base + "imageupload/" + String(format:"%f", datapoint.0))
        var request = URLRequest(url:imageurl!)
        request.httpMethod = "POST"
        //let boundary = "thequickbrownfoxjumpsoverthelazydog"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let task = URLSession.shared.uploadTask(with: request, from: datapoint.1){data, response, error in
            if let response_http = response as? HTTPURLResponse {
                //print(response_http)
                
                if response_http.statusCode == 200 {
                    print("success")
                    self.submitted_count += 1
                    DispatchQueue.main.async {
                        self.successfully_submitted.text = String(format:"%d", self.submitted_count)
                    }
                }
            }
        }
        task.resume()
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
            motionEvents.append([attitude.roll, attitude.yaw, attitude.pitch, time - self.secs_ahead_of_computer])
        }
        DispatchQueue.main.async {
            self.roll_label.text = String(format: "%f", attitude.roll)
            self.yaw_label.text = String(format: "%f", attitude.yaw)
            self.pitch_label.text = String(format: "%f", attitude.pitch)
            self.time_label.text = String(format: "%f", time)
            self.unsubmitted_events_label.text = String(format: "%d", self.motionEvents.count)
            
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        
        if amRecording {
            let time = Date().timeIntervalSince1970
            guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            var cgImage: CGImage?
            VTCreateCGImageFromCVPixelBuffer(pixelBuffer, nil, &cgImage)
            let uiImage = UIImage(cgImage: cgImage!)
            let png = UIImageJPEGRepresentation(uiImage, 0.7)
            //imagesAndTimestamps.append((time - self.secs_ahead_of_computer, png!))
            submitImageDatapoint(datapoint: (time - self.secs_ahead_of_computer, png!))
            i += 1;
        }
        
        DispatchQueue.main.async {
            self.rand_pix.text = String(format: "%d", self.i)
        }
    }
}


