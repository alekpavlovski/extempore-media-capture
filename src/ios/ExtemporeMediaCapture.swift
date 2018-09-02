
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
        let videoName = outputName + ".mp4"
        if self.fileExists(fileName: videoName) {
            print("FOUND IT: \(videoName)")
        }
        let payload = "{ \"name\": \"\(videoName)\" }"
        pluginResult = CDVPluginResult(
            status: CDVCommandStatus_OK,
            messageAs: payload
        )
        self.commandDelegate!.send(
            pluginResult,
            callbackId: callbackId
        )
    }
    
    func fileExists(fileName: String) -> Bool {
        let url = NSURL(fileURLWithPath: NSTemporaryDirectory())
        if let pathComponent = url.appendingPathComponent(fileName) {
            let filePath = pathComponent.path
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: filePath) {
                print("FILE AVAILABLE")
                return true
            } else {
                print("FILE NOT AVAILABLE")
                return false
            }
        } else {
            print("FILE PATH NOT AVAILABLE")
            return false
        }
    }
    
    @objc(startRecording:)
    func startRecording(command: CDVInvokedUrlCommand) {
        outputName = UUID().uuidString;
        let movName = outputName + ".mov";
        let dir = URL(fileURLWithPath: NSTemporaryDirectory());
        let fileUrl = dir.appendingPathComponent(movName)
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
        outputName = UUID().uuidString
        var movName = outputName + ".mov";
        if directory != "" {
            let path = directory.appendingPathComponent(movName)
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
        encodeVideo(videoUrl: outputFileURL, resultClosure: { url in
            print("Final file url: \(url)")
            self.completed()
        })
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
    
    func encodeVideo(videoUrl: URL, outputUrl: URL? = nil, resultClosure: @escaping (URL?) -> Void ) {
        print("Starting conversion")
        var finalOutputUrl: URL? = outputUrl
        
        if finalOutputUrl == nil {
            var url = videoUrl
            url.deletePathExtension()
            url.appendPathExtension("mp4")
            finalOutputUrl = url
        }
        
        if FileManager.default.fileExists(atPath: finalOutputUrl!.path) {
            print("Converted file already exists \(finalOutputUrl!.path)")
            resultClosure(finalOutputUrl)
            return
        }
        
        let asset = AVURLAsset(url: videoUrl)
        if let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) {
            exportSession.outputURL = finalOutputUrl!
            exportSession.outputFileType = AVFileType.mp4
            let start = CMTimeMakeWithSeconds(0.0, 0)
            let range = CMTimeRangeMake(start, asset.duration)
            exportSession.timeRange = range
            exportSession.shouldOptimizeForNetworkUse = true
            exportSession.exportAsynchronously() {
                
                switch exportSession.status {
                case .failed:
                    print("Export failed: \(exportSession.error != nil ? exportSession.error!.localizedDescription : "No Error Info")")
                case .cancelled:
                    print("Export canceled")
                case .completed:
                    print("Completed conversion \(finalOutputUrl)")
                    resultClosure(finalOutputUrl!)
                default:
                    break
                }
            }
        } else {
            print("Failed conversion for \(finalOutputUrl)")
            resultClosure(nil)
        }
    }
}
