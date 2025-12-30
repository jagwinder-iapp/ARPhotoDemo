//
//  ARUSDZViewController.swift
//  ARPhotoDemo
//
//  Created by Geetam Singh on 24/12/25.
//

import UIKit
import RealityKit
import ARKit
import Combine

class ARUSDZViewController: UIViewController {
    
    let usdzURL: URL
    private var arView: ARView!
    private var anchor: AnchorEntity?
    private var modelEntity: ModelEntity?
    private var cancellables = Set<AnyCancellable>()
    
    init(usdzURL: URL) {
        self.usdzURL = usdzURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupGestures()
        setupButtons()
    }
    
    // MARK: - AR Setup
    private func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        config.isLightEstimationEnabled = true
        config.sceneReconstruction = .mesh
        config.frameSemantics = [.personSegmentationWithDepth]
        
        arView.automaticallyConfigureSession = true
        arView.session.run(config)
        
        arView.environment.lighting.intensityExponent = 1.0
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
    }
    
    // MARK: - Gestures
    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tap)
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        arView.addGestureRecognizer(pinch)
        
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        arView.addGestureRecognizer(rotation)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        arView.addGestureRecognizer(pan)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)
        guard let result = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .any).first else {
            print("Raycast missed an existing plane geometry.")
            return
        }
        placeUSDZ(with: result)
    }
    
    private func placeUSDZ(with raycastResult: ARRaycastResult) {
        anchor?.removeFromParent()
        anchor = AnchorEntity(raycastResult: raycastResult)
        
        ModelEntity.loadModelAsync(contentsOf: usdzURL)
            .sink { completion in
                if case let .failure(error) = completion { print("Load failed:", error) }
            } receiveValue: { [weak self] model in
                guard let self = self else { return }
                self.modelEntity = model
                model.scale = [0.2, 0.2, 0.2]
                model.position = [0, 0.001, 0]
                
                let matrix = model.transformMatrix(relativeTo: nil)
                let yaw = atan2(matrix.columns.0.z, matrix.columns.0.x)
                model.orientation = simd_quatf(angle: yaw, axis: [0,1,0])
                
                self.anchor?.addChild(model)
            }
            .store(in: &cancellables)
        
        if let anchor = anchor { arView.scene.addAnchor(anchor) }
    }
    
    // MARK: - Gesture Handlers
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let model = modelEntity else { return }
        let scale = Float(gesture.scale)
        model.scale *= scale
        gesture.scale = 1
    }
    
    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard let model = modelEntity else { return }
        let rotation = -Float(gesture.rotation)
        model.orientation *= simd_quatf(angle: rotation, axis: [0,1,0])
        gesture.rotation = 0
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let model = modelEntity else { return }
        let location = gesture.translation(in: arView)
        
        let sensitivity: Float = 0.001   // adjust movement speed
        
        // Move model according to pan
        model.position.x += Float(location.x) * sensitivity
        model.position.z += Float(location.y) * sensitivity
        
        gesture.setTranslation(.zero, in: arView)
    }
    
    // MARK: - Buttons
    private func setupButtons() {
        
        let dismissButton = UIButton(type: .system)
        dismissButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        dismissButton.tintColor = .white
        dismissButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        dismissButton.layer.cornerRadius = 20
        dismissButton.clipsToBounds = true
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.addTarget(self, action: #selector(handleDismiss), for: .touchUpInside)
        view.addSubview(dismissButton)

        NSLayoutConstraint.activate([
            dismissButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            dismissButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            dismissButton.widthAnchor.constraint(equalToConstant: 40),
            dismissButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        let cameraButton = UIButton(type: .system)
        cameraButton.setImage(UIImage(systemName: "camera"), for: .normal)
        cameraButton.tintColor = .white
        cameraButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        cameraButton.layer.cornerRadius = 20
        cameraButton.clipsToBounds = true
        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        cameraButton.addTarget(self, action: #selector(handleScreenshot), for: .touchUpInside)
        view.addSubview(cameraButton)

        NSLayoutConstraint.activate([
            cameraButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cameraButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            cameraButton.widthAnchor.constraint(equalToConstant: 40),
            cameraButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc private func handleDismiss() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func handleScreenshot() {
        UIImageWriteToSavedPhotosAlbum(arView.screenshot(), nil, nil, nil)
        let alert = UIAlertController(title: "Success", message: "AR Image Saved to Photos", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// Extensions
private extension simd_float4x4 {
    var translation: SIMD3<Float> { let t = columns.3; return [t.x, t.y, t.z] }
}
