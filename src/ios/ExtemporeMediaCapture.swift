
import AVFoundation
import UIKit

@objc(ExtemporeMediaCapture) class ExtemporeMediaCapture : CDVPlugin, AVCaptureFileOutputRecordingDelegate {
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var onDoneBlock : ((String) -> Void)?
    var videoOutput = AVCaptureMovieFileOutput()
    var activeInput: AVCaptureDeviceInput!
    var outputURL: URL!
    var outputName: String = "empty"
    var callbackId: String!
    
    @objc(openPreview:)
    func openPreview(command: CDVInvokedUrlCommand) {
        self.webView.isOpaque = false
        self.webView.backgroundColor = UIColor.clear
        
        do {
            let captureDevice: AVCaptureDevice
            if #available(iOS 11.1, *) {
                captureDevice = self.bestDevice(in: AVCaptureDevice.Position.front)
            } else {
                captureDevice = AVCaptureDevice.default(for: AVMediaType.video)!
            }
            let input = try AVCaptureDeviceInput.init(device: captureDevice)
            captureSession = AVCaptureSession()
            captureSession?.addInput(input)
            activeInput = input
            let microphone = AVCaptureDevice.default(for: AVMediaType.audio)
            
            do {
                let micInput = try AVCaptureDeviceInput(device: microphone!)
                if (captureSession?.canAddInput(micInput))! {
                    captureSession?.addInput(micInput)
                }
            } catch {
                print("Error setting device audio input: \(error)")
            }

            self.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            self.videoPreviewLayer?.frame = (self.webView.superview?.layer.bounds)!
            self.webView.superview?.layer.addSublayer(self.videoPreviewLayer!)
            self.webView.superview?.bringSubview(toFront: self.webView)
            captureSession?.startRunning()
        } catch  {
            print(error)
        }
    }

    
    @objc(stopRecording:)
    func stopRecording(command: CDVInvokedUrlCommand) {
        callbackId =  command.callbackId
        self.stop()
    }

    func completed() {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )
        self.videoPreviewLayer?.removeFromSuperlayer()
        let payload = "{ \"name\": \"\(outputName)\" }"
        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAs: payload
        )
        self.commandDelegate!.send(
            pluginResult,
            callbackId: callbackId
        )
    }
    
    @objc(startRecording:)
    func startRecording(command: CDVInvokedUrlCommand) {
        outputName = UUID().uuidString + ".mov";
        let dir = URL(fileURLWithPath: NSTemporaryDirectory());
        let fileUrl = dir.appendingPathComponent(outputName)
        try? FileManager.default.removeItem(at: fileUrl)

        self.videoOutput = AVCaptureMovieFileOutput()
        if (self.captureSession?.canAddOutput(self.videoOutput))! {
            self.captureSession?.addOutput(self.videoOutput)
            self.captureSession?.startRunning()
            self.videoOutput.startRecording(to: fileUrl, recordingDelegate: self)
        }
    }

    func tempURL() -> URL? {
        let directory = NSTemporaryDirectory() as NSString
        outputName = UUID().uuidString + ".mov"
        if directory != "" {
            let path = directory.appendingPathComponent(outputName)
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    func currentVideoOrientation() -> AVCaptureVideoOrientation {
        var orientation: AVCaptureVideoOrientation
        
        switch UIDevice.current.orientation {
        case .portrait:
            orientation = AVCaptureVideoOrientation.portrait
        case .landscapeRight:
            orientation = AVCaptureVideoOrientation.landscapeLeft
        case .portraitUpsideDown:
            orientation = AVCaptureVideoOrientation.portraitUpsideDown
        default:
            orientation = AVCaptureVideoOrientation.landscapeRight
        }
        
        return orientation
    }

    func videoQueue() -> DispatchQueue {
        return DispatchQueue.main
    }

    func startSession() {
        if !(captureSession?.isRunning)! {
            videoQueue().async {
                self.captureSession?.startRunning()
            }
        }
    }
    
    func stopSession() {
        if (captureSession?.isRunning)! {
            videoQueue().async {
                self.captureSession?.stopRunning()
            }
        }
    }

    func start() {
        if videoOutput.isRecording == false {
            outputURL = tempURL()
            videoOutput.startRecording(to: outputURL, recordingDelegate: self)
        }
        else {
            stop()
        }
    }

    func stop() {
        if videoOutput.isRecording == true {
            videoOutput.stopRecording()
            self.stopSession()
        }
    }

    func setupCaptureMode(_ mode: Int) {
        // Video Mode
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        completed()
    }
    
    
    @available(iOS 11.1, *)
    func bestDevice(in position: AVCaptureDevice.Position) -> AVCaptureDevice {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes:
            [.builtInTrueDepthCamera, .builtInDualCamera, .builtInWideAngleCamera],
                                                                mediaType: .video, position: .unspecified)
        let devices = discoverySession.devices
        guard !devices.isEmpty else { fatalError("Missing capture devices.")}
        
        return devices.first(where: { device in device.position == position })!
    }
    
    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
        videoPreviewLayer?.frame = (self.webView.superview?.layer.bounds)!
    }

    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        if (error != nil) {
            print("Error recording movie: \(error!.localizedDescription)")
        } else {
            
            _ = outputURL as URL
            
        }
        outputURL = nil
    }
}
