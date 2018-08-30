
import AVFoundation
import UIKit

@objc(ExtemporeMediaCapture) class ExtemporeMediaCapture : CDVPlugin, AVCaptureFileOutputRecordingDelegate {
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var onDoneBlock : ((String) -> Void)?
    var videoOutput = AVCaptureMovieFileOutput()
    
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
            
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            videoPreviewLayer?.frame = (self.webView.superview?.layer.bounds)!
            self.webView.superview?.layer.addSublayer(videoPreviewLayer!)
            self.webView.superview?.bringSubview(toFront: self.webView)
            print("Starting preview")
            captureSession?.startRunning()
        } catch  {
            print(error)
        }
    }

    
    @objc(stopRecording:)
    func stopRecording(command: CDVInvokedUrlCommand) {
        var pluginResult = CDVPluginResult(
            status: CDVCommandStatus_ERROR
        )
        self.onDoneBlock = { result in
            pluginResult = CDVPluginResult(
                status: CDVCommandStatus_OK,
                messageAs: result
            )
            
            self.commandDelegate!.send(
                pluginResult,
                callbackId: command.callbackId
            )
        }
        self.videoOutput.stopRecording()
    }
    
    @objc(startRecording:)
    func startRecording(command: CDVInvokedUrlCommand) {
        print("Recording now")
        self.captureSession?.addOutput(self.videoOutput)
        self.captureSession?.commitConfiguration()
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileUrl = paths[0].appendingPathComponent("output.mov")
        try? FileManager.default.removeItem(at: fileUrl)
        self.videoOutput.startRecording(to: fileUrl, recordingDelegate: self)
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        print("FINISHED \(error)")
        // save video to camera roll
        if error == nil {
            if(onDoneBlock != nil) {
                do {
                    let x = try String(contentsOfFile: outputFileURL.absoluteString )
                    onDoneBlock!(x)
                    // onDoneBlock!("Trying to read from:" + outputFileURL.absoluteString)
                } catch {
                    onDoneBlock!("Failed to read from file." + outputFileURL.absoluteString)
                }
                
            } else {
                print("Couldn't on done block.")
            }
        }
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
}
