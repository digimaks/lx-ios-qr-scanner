//
//  QRScannerManager.swift
//  QRCodeScannerPackage
//
//  Created by Matīss Mamedovs on 27/11/2024.
//
#if canImport(UIKit)

import Foundation
import AVFoundation
import UIKit

@MainActor final public class QRScannerManager: NSObject, Sendable {
    
    @MainActor fileprivate let captureSession: AVCaptureSession = AVCaptureSession()
    fileprivate let sessionQueue = DispatchQueue(label: "QRCodeScannerManager.sessionQueue")
    fileprivate let sessionQueueKey = DispatchSpecificKey<Void>()
    fileprivate var previewLayer: AVCaptureVideoPreviewLayer?
    fileprivate var focusImageView: UIImageView?
    fileprivate var closeButton: UIButton?
    public static let shared = QRScannerManager()
    
    public override init() {
        super.init()
        sessionQueue.setSpecific(key: sessionQueueKey, value: ())
    }
    
    public weak var delegate: QRCodeActionDelegate?
    
    fileprivate var needCallback: Bool = true
    
    public func runSession(for parent: UIViewController) {
        needCallback = true
        self.addLayer(for: parent)
        let session = self.captureSession
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            session.startRunning()
            DispatchQueue.main.async {
                self.addViewFinder(parent: parent)
            }
        }
    }
    public func stopSession() {
        let session = self.captureSession
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if session.isRunning {
                session.stopRunning()
            }
            DispatchQueue.main.async {
                self.removeLayer()
            }
        }
    }
    
    public func setUp(completion: @escaping (Bool) -> Void) {
        self.requestCameraAccess(completion: { granted in
            if granted {
                guard let device = AVCaptureDevice.default(for: .video) else {
                    DispatchQueue.main.async { completion(false) }
                    return
                }
                
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    let output = AVCaptureMetadataOutput()
                    output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                    
                    self.sessionQueue.async {
                        let session = self.captureSession
                        session.beginConfiguration()
                        
                        if session.canAddInput(input) {
                            session.addInput(input)
                        }
                        
                        if session.canAddOutput(output) {
                            session.addOutput(output)
                            output.metadataObjectTypes = [.qr]
                        }
                        
                        session.commitConfiguration()
                        
                        DispatchQueue.main.async {
                            completion(true)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.delegate?.showError(.noCamera)
                        completion(false)
                    }
                    print(error)
                }
            } else {
                completion(false)
            }
        })
    }
}

extension QRScannerManager {
    fileprivate func requestCameraAccess(completion: @escaping (Bool) -> Void) {
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch cameraAuthorizationStatus {
        case .notDetermined:
            print("notDetermined")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("granted")
                DispatchQueue.main.async {
                    print("granted1")
                    completion(granted)
                }
            }
        case .restricted, .denied:
            completion(false)
        case .authorized:
            completion(true)
        @unknown default:
            completion(false)
        }
    }
    
    fileprivate func addLayer(for parent: UIViewController) {
        if previewLayer == nil {
            sessionQueue.sync {
                let layer = AVCaptureVideoPreviewLayer(session: captureSession)
                layer.videoGravity = .resizeAspectFill
                self.previewLayer = layer
            }
            
            guard let previewLayer = previewLayer else { return }
            DispatchQueue.main.async {
                previewLayer.frame = parent.view.bounds
                parent.view.layer.addSublayer(previewLayer)
            }
            
            guard let image = UIImage(named: "viewfinder") else {
                return
            }
            
            let imageView = UIImageView(image: image)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            focusImageView = imageView
            
            closeButton = UIButton(type: .system)
            let xImage = UIImage(systemName: "xmark")
            
            closeButton?.setImage(xImage, for: .normal)
            closeButton?.tintColor = .white
            closeButton?.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            closeButton?.layer.cornerRadius = 25
            closeButton?.addTarget(self, action: #selector(close), for: .touchUpInside)
            closeButton?.translatesAutoresizingMaskIntoConstraints = false
        }
    }
    
    @objc func close() {
        self.stopSession()
    }
    
    private func addViewFinder(parent: UIViewController) {
        guard let imageView = focusImageView else { return }
        
        parent.view.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.centerYAnchor.constraint(equalTo: parent.view.centerYAnchor),
            imageView.centerXAnchor.constraint(equalTo: parent.view.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 300),
            imageView.heightAnchor.constraint(equalToConstant: 300),
        ])
        
        guard let closeButton = closeButton else { return }
        
        parent.view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.rightAnchor.constraint(equalTo: parent.view.rightAnchor, constant: -30),
            closeButton.topAnchor.constraint(equalTo: parent.view.topAnchor, constant: 50),
            closeButton.widthAnchor.constraint(equalToConstant: 50),
            closeButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }
    
    fileprivate func removeLayer() {
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        focusImageView?.removeFromSuperview()
        focusImageView = nil
        closeButton?.removeFromSuperview()
        closeButton = nil
    }
    
    fileprivate func isPresentationAction(url: String) -> Bool {
        for value in OpenIDPresentationScheme.allCases {
            if url.starts(with: value.rawValue) {
                return true
            }
        }
        
        return false
    }
    
    fileprivate func isIssuanceAction(url: String) -> Bool {
        for value in CredentialOfferIssuanceScheme.allCases {
            if url.starts(with: value.rawValue) {
                return true
            }
        }
        
        return false
    }
}

extension QRScannerManager: AVCaptureMetadataOutputObjectsDelegate {
    
    nonisolated public func metadataOutput(_ output: AVCaptureMetadataOutput,
                                           didOutput metadataObjects: [AVMetadataObject],
                                           from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObject.type == .qr,
              let stringValue = metadataObject.stringValue else { return }
        
        DispatchQueue.main.async(execute: {
            if self.isPresentationAction(url: stringValue) || self.isIssuanceAction(url: stringValue) {
                self.stopSession()
                if self.needCallback {
                    self.needCallback = false
                    self.delegate?.showQRCodeResult(result: stringValue)
                }
            } else {
                self.stopSession()
                self.delegate?.showQRInvalid()
            }
        })
    }
}

#endif

public protocol QRCodeActionDelegate: NSObject {
    func showError(_ error: ScanningError)
    func showQRCodeResult(result: String)
    func showQRInvalid()
}
public enum ScanningError: Error {
    case noCamera
    case noPermission
}


public enum OpenIDPresentationScheme: String, CaseIterable {
    case openid4VP = "openid4vp"
    case openidVP = "openid-vp"
    case mDocOpenID4VP = "mdoc-openid4vp"
    case eudiOpenID4VP = "eudi-openid4vp"
}

public enum CredentialOfferIssuanceScheme: String, CaseIterable {
    case eudiWallet = "eudi-wallet"
    case openIDCredentialOffer = "openid-credential-offer"
    case haipVCI = "haip-vci"
}
