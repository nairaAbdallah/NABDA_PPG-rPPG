//
//  ViewController.swift
//  HeartRate_fromCamera
//
//  Created by Naira Bassam on 31/07/2021.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
    
    var contourPoint :[CGPoint] = []
    var allContourPoint: [[CGPoint]] = []
    var img: [UIImage] = []
    var cggImage:CGImage?
    //xxxxxxxxxxxxxxxxxxxxxxxxx
    weak var loopTimer: Timer?
    var secondRemaining = 0
    var click = 1
    //xxxxxxxxxxxxxxxxxxxxxxxxx
    private let captureSession = AVCaptureSession()
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var faceLayers: [CAShapeLayer] = []

    //xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    func runLoopTimer() {
        loopTimer?.invalidate()
        loopTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
    }
    @objc func updateTimer() {
        if secondRemaining > 0 {
            secondRemaining -= 1
            timerCount.text = "\(secondRemaining)"
            if secondRemaining == 0 {
                captureSession.stopRunning()
                self.performSegue(withIdentifier: "resultRPPG", sender: self)
            }
        }
    }
    
    @IBOutlet weak var timer: UIButton!
    @IBOutlet weak var timerCount: UILabel!
    @IBAction func timerAction(_ sender: UIButton) {
        if (click % 2) != 0 {
            captureSession.startRunning()
            secondRemaining = 10
            timer.isHidden = true
            runLoopTimer()
        }else{
            timer.isHidden = false
        }
    }
    
    //xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    override func viewDidLoad() {
        super.viewDidLoad()
        style(timer)
        setupCamera()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.view.frame
        self.view.addSubview(timer)
        self.view.addSubview(timerCount)
    }
    
    //camera
    private func setupCamera() {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        if let device = deviceDiscoverySession.devices.first {
            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                if captureSession.canAddInput(deviceInput) {
                    captureSession.addInput(deviceInput)
                    
                    setupPreview()
                }
            }
        }
    }
    
    private func setupPreview() {
        self.previewLayer.videoGravity = .resizeAspectFill
        self.view.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = self.view.frame
        
        self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]

        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera queue"))
        self.captureSession.addOutput(self.videoDataOutput)
        
        let videoConnection = self.videoDataOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait
    }
    
    //xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if segue.destination is ResultViewController {
            let vc = segue.destination as? ResultViewController
            vc?.bufferImg = img
            vc?.pointContour = allContourPoint
        }
    }
    //xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
          return
        }
        //xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        let ciImageDepth            = CIImage(cvPixelBuffer: imageBuffer)
        let contextDepth:CIContext  = CIContext.init(options: nil)
        let cgImageDepth:CGImage    = contextDepth.createCGImage(ciImageDepth, from: ciImageDepth.extent)!
//        let uiImageDepth:UIImage    = UIImage(cgImage: cgImageDepth, scale: 1, orientation: UIImage.Orientation.up)
        cggImage = cgImageDepth
        //xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                self.faceLayers.forEach({ drawing in drawing.removeFromSuperlayer() })

                if let observations = request.results as? [VNFaceObservation] {
                    self.handleFaceDetectionObservations(observations: observations)
                }
            }
        })

        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: .leftMirrored, options: [:])
       
        do {
            try imageRequestHandler.perform([faceDetectionRequest])
        } catch {
          print(error.localizedDescription)
        }
    }
    
    private func handleFaceDetectionObservations(observations: [VNFaceObservation]) {
        for observation in observations {
            let faceRectConverted = self.previewLayer.layerRectConverted(fromMetadataOutputRect: observation.boundingBox)
            let faceRectanglePath = CGPath(rect: faceRectConverted, transform: nil)
            
            let faceLayer = CAShapeLayer()
            faceLayer.path = faceRectanglePath
            faceLayer.fillColor = UIColor.clear.cgColor
            faceLayer.strokeColor = UIColor.yellow.cgColor
            
            self.faceLayers.append(faceLayer)
            self.view.layer.addSublayer(faceLayer)
            
            //FACE LANDMARKS
            if let landmarks = observation.landmarks {
               
                //xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
                if let faceContour = landmarks.faceContour {
                    self.handleLandmark(faceContour, faceBoundingBox: faceRectConverted)
                    contourPoint = faceContour.normalizedPoints
                    allContourPoint.append(contourPoint)
                }
                //xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
                if let leftEye = landmarks.leftEye {
                    self.handleLandmark(leftEye, faceBoundingBox: faceRectConverted)
                }
                if let leftEyebrow = landmarks.leftEyebrow {
                    self.handleLandmark(leftEyebrow, faceBoundingBox: faceRectConverted)
                }
                if let rightEye = landmarks.rightEye {
                    self.handleLandmark(rightEye, faceBoundingBox: faceRectConverted)
                }
                if let rightEyebrow = landmarks.rightEyebrow {
                    self.handleLandmark(rightEyebrow, faceBoundingBox: faceRectConverted)
                }

                if let nose = landmarks.nose {
                    self.handleLandmark(nose, faceBoundingBox: faceRectConverted)
                }

                if let outerLips = landmarks.outerLips {
                    self.handleLandmark(outerLips, faceBoundingBox: faceRectConverted)
                }
                if let innerLips = landmarks.innerLips {
                    self.handleLandmark(innerLips, faceBoundingBox: faceRectConverted)
                }
            }
        }
    }
    
    private func handleLandmark(_ eye: VNFaceLandmarkRegion2D, faceBoundingBox: CGRect) {
        let landmarkPath = CGMutablePath()
        let landmarkPathPoints = eye.normalizedPoints
            .map({ eyePoint in
                CGPoint(
                    x: eyePoint.y * faceBoundingBox.height + faceBoundingBox.origin.x,
                    y: eyePoint.x * faceBoundingBox.width + faceBoundingBox.origin.y)
            })
        landmarkPath.addLines(between: landmarkPathPoints)
        landmarkPath.closeSubpath()
        let landmarkLayer = CAShapeLayer()
        landmarkLayer.path = landmarkPath
        landmarkLayer.fillColor = UIColor.clear.cgColor
        landmarkLayer.strokeColor = UIColor.green.cgColor
        
        self.faceLayers.append(landmarkLayer)
        self.view.layer.addSublayer(landmarkLayer)
        if let imageWillCroped = cggImage {
            let croppedCGImage = imageWillCroped.cropping(
                to: faceBoundingBox
            )!
            let uiImageDepth:UIImage = UIImage(cgImage: croppedCGImage, scale: 1, orientation: UIImage.Orientation.up)
            img.append(uiImageDepth)
        }
    }
    
    func style (_ component: UIButton){
        component.layer.cornerRadius = component.frame.size.height / 2
        component.layer.shadowColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        component.layer.shadowOffset = CGSize(width: 0, height: 1.7)
        component.layer.shadowRadius = component.frame.size.height / 2
        component.layer.shadowOpacity = 0.19
    }
}

