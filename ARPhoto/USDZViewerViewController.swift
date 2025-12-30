//
// USDZViewerViewController.swift
//  ARPhotoDemo
//
//  Created by Geetam Singh on 24/12/25.
//

import UIKit
import SceneKit
import ARKit

// A custom button class to store the type of item it represents (Color or Texture)
class SelectionButton: UIButton {
    var isTexture: Bool = false
    var textureName: String?
}

// Enumeration to define the current selection mode
enum SelectionMode {
    case colors
    case textures
    case adjust // New mode for sliders
}

final class USDZPreviewViewController: UIViewController {
    private let images: [UIImage] // front/back
    private var sceneView: SCNView!
    private var frameNodes: [SCNNode] = [] // Stores the 4 frame pieces
    private var frameGroup: SCNNode?
    private var isFrameVisible: Bool = true
    
    // Initial values for frame dimensions
    private var currentFrameThickness: CGFloat = 0.05
    private var currentFrameDepth: CGFloat = 0.05
    // NEW: Initial value for frame roundness (chamfer radius)
    private var currentFrameRoundness: CGFloat = 0.005

    // --- Data Sources ---
    private let frameColors: [UIColor] = [
        .black,
        .white,
        UIColor(red: 0.8, green: 0.6, blue: 0.4, alpha: 1.0), // Light Wood/Beige
        UIColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1.0), // Dark Brown/Wood
        .gray,
        .lightGray,
        .darkGray,
        .red,
        .systemPink,
        .blue,
        .systemTeal,
        .green,
        .systemIndigo,
        .systemPurple,
        .systemOrange,
        .systemYellow
    ]

    // Texture names as requested (assuming these are image asset names)
    private let frameTextureNames: [String] = [
        "3DTexture1",
        "3DTexture2",
        "3DTexture3",
        "3DTexture5",
        "3DTexture6",
        "3DTexture7",
        "3DTexture8",
        "3DTexture9",
        "3DTexture10",
        "3DTexture11",
    ]

    // --- UI Elements for Toolbar ---
    // Updated: Added "Adjust" segment
    private let segmentedControl = UISegmentedControl(items: ["Colors", "Textures", "Adjust"])
    private let toolbarScrollView = UIScrollView()
    private let toolbarStackView = UIStackView()
    private let toolbarContainer = UIView() // Container to hold the segmented control and scroll view/sliders
    private let frameToggleSwitch = UISwitch()
    
    // Sliders Container and Elements
    private let slidersContainer = UIStackView()
    private let thicknessSlider = UISlider()
    private let depthSlider = UISlider()
    // NEW: Roundness Slider and Label
    private let roundnessSlider = UISlider()
    private let thicknessLabel = UILabel()
    private let depthLabel = UILabel()
    private let roundnessLabel = UILabel()

    init(images: [UIImage]) {
        self.images = images
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gray

        setupSceneView()
        setupSceneContent()
        addDismissButton()
        addARButton()
        
        // 1. Initialize the new dynamic toolbar and sliders
        addFrameToolbar()
        
        // 2. Set the initial state
        segmentedControl.selectedSegmentIndex = 0
        updateSelectionToolbar(for: .colors)
    }

    // MARK: - Scene Setup
    private func setupSceneView() {
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = .gray
        view.addSubview(sceneView)
    }

    private func setupSceneContent() {
        let scene = SCNScene()
        sceneView.scene = scene

        guard let frontImage = images.first else { return }
        let backImage = images.count > 1 ? images[1] : nil

        let imageWidth: CGFloat = 1.0
        let imageHeight: CGFloat = frontImage.size.height / frontImage.size.width

        // Frame Material (Initial Material)
        let frameMaterial = SCNMaterial()
        frameMaterial.diffuse.contents = UIColor.darkGray
        frameMaterial.metalness.contents = 0.6
        frameMaterial.roughness.contents = 0.3

        // --- Frame Nodes ---
        // Initially create the nodes based on initial values
        createFrameNodes(
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            frameThickness: currentFrameThickness,
            frameDepth: currentFrameDepth,
            frameRoundness: currentFrameRoundness, // NEW
            frameMaterial: frameMaterial,
            scene: scene
        )

        // --- Front Plane ---
        let frontPlane = SCNPlane(width: imageWidth, height: imageHeight)
        let frontMaterial = SCNMaterial()
        frontMaterial.diffuse.contents = frontImage
        frontMaterial.lightingModel = .physicallyBased
        frontMaterial.isDoubleSided = images.count == 1
        frontPlane.firstMaterial = frontMaterial

        let frontNode = SCNNode(geometry: frontPlane)
        frontNode.eulerAngles.x = -.pi/2
        // Position relative to the frame depth
        frontNode.position = SCNVector3(0, 0, Float(currentFrameDepth/2 - 0.025))
        scene.rootNode.addChildNode(frontNode)

        // --- Back Plane ---
        if let backImage = backImage {
            let backPlane = SCNPlane(width: imageWidth, height: imageHeight)
            let backMaterial = SCNMaterial()
            backMaterial.diffuse.contents = backImage
            backMaterial.lightingModel = .physicallyBased
            backPlane.firstMaterial = backMaterial

            let backNode = SCNNode(geometry: backPlane)
            backNode.eulerAngles.x = .pi/2
            // Position relative to the frame depth
            backNode.position = SCNVector3(0, 0, Float(-currentFrameDepth/2 + 0.025))
            scene.rootNode.addChildNode(backNode)
        }

        // --- Camera ---
        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.fieldOfView = 60.0
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(-1.5, 3.0, 3.0)
        let lookAtConstraint = SCNLookAtConstraint(target: SCNNode())
        lookAtConstraint.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAtConstraint]
        scene.rootNode.addChildNode(cameraNode)
        sceneView.pointOfView = cameraNode
    }
    
    /**
     Removes existing frame nodes and creates new SCNBox nodes for the picture frame
     using the specified dimensions and material.
     
     UPDATED: Added frameRoundness parameter.
     */
    private func createFrameNodes(imageWidth: CGFloat, imageHeight: CGFloat, frameThickness: CGFloat, frameDepth: CGFloat, frameRoundness: CGFloat, frameMaterial: SCNMaterial, scene: SCNScene) {
        // Remove existing frame nodes if any
        frameGroup?.removeFromParentNode()
        frameNodes.removeAll()

        let halfWidth = imageWidth / 2
        let halfHeight = imageHeight / 2

        // 1. Top Bar
        // NEW: Use frameRoundness for chamferRadius
        let top = SCNBox(width: imageWidth + 2*frameThickness, height: frameThickness, length: frameDepth, chamferRadius: frameRoundness)
        top.firstMaterial = frameMaterial
        let topNode = SCNNode(geometry: top)
        topNode.position = SCNVector3(0, Float(halfHeight + frameThickness/2), 0)

        // 2. Bottom Bar
        // NEW: Use frameRoundness for chamferRadius
        let bottom = SCNBox(width: imageWidth + 2*frameThickness, height: frameThickness, length: frameDepth, chamferRadius: frameRoundness)
        bottom.firstMaterial = frameMaterial
        let bottomNode = SCNNode(geometry: bottom)
        bottomNode.position = SCNVector3(0, Float(-halfHeight - frameThickness/2), 0)

        // 3. Left Bar
        // NEW: Use frameRoundness for chamferRadius
        let left = SCNBox(width: frameThickness, height: imageHeight, length: frameDepth, chamferRadius: frameRoundness)
        left.firstMaterial = frameMaterial
        let leftNode = SCNNode(geometry: left)
        leftNode.position = SCNVector3(Float(-halfWidth - frameThickness/2), 0, 0)

        // 4. Right Bar
        // NEW: Use frameRoundness for chamferRadius
        let right = SCNBox(width: frameThickness, height: imageHeight, length: frameDepth, chamferRadius: frameRoundness)
        right.firstMaterial = frameMaterial
        let rightNode = SCNNode(geometry: right)
        rightNode.position = SCNVector3(Float(halfWidth + frameThickness/2), 0, 0)

        let frameGroupNode = SCNNode()
        frameGroupNode.addChildNode(topNode)
        frameGroupNode.addChildNode(bottomNode)
        frameGroupNode.addChildNode(leftNode)
        frameGroupNode.addChildNode(rightNode)
        
        // Adjust orientation
        frameGroupNode.eulerAngles.x = -.pi/2
        scene.rootNode.addChildNode(frameGroupNode)
        
        // Store the frame group and nodes for later manipulation
        frameGroup = frameGroupNode
        frameNodes = [topNode, bottomNode, leftNode, rightNode]
        
        // Restore visibility state
        frameGroup?.isHidden = !isFrameVisible
    }

    // MARK: - UI
    private func addDismissButton() {
        let dismissButton = UIButton(type: .system)
        dismissButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        dismissButton.tintColor = .white
        dismissButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        dismissButton.layer.cornerRadius = 20
        dismissButton.clipsToBounds = true
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.addTarget(self, action: #selector(dismissViewer), for: .touchUpInside)
        view.addSubview(dismissButton)

        NSLayoutConstraint.activate([
            dismissButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            dismissButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            dismissButton.widthAnchor.constraint(equalToConstant: 40),
            dismissButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func addARButton() {
        let arButton = UIButton(type: .system)
        arButton.setImage(UIImage(systemName: "arkit"), for: .normal)
        arButton.tintColor = .white
        arButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        arButton.layer.cornerRadius = 20
        arButton.clipsToBounds = true
        arButton.translatesAutoresizingMaskIntoConstraints = false
        arButton.addTarget(self, action: #selector(viewInAR), for: .touchUpInside)
        view.addSubview(arButton)

        NSLayoutConstraint.activate([
            arButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            arButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            arButton.widthAnchor.constraint(equalToConstant: 40),
            arButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    // Integrates Segments, ScrollView, and Sliders
    private func addFrameToolbar() {
        let buttonSize: CGFloat = 40.0
        let toolbarContentHeight = buttonSize + 20 // For scroll view buttons + padding
        let slidersHeight: CGFloat = 100.0 // Increased height to fit THREE sliders and labels (was 70)
        let toolbarHeight = slidersHeight + 50 // Height of segmented control + sliders
        

        // 1. Configure the Frame Toggle Switch (OUTSIDE container)
        let frameToggleLabel = UILabel()
        frameToggleLabel.text = "Frame"
        frameToggleLabel.textColor = .label
        frameToggleLabel.font = .systemFont(ofSize: 12)
        frameToggleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(frameToggleLabel)
        
        view.addSubview(frameToggleSwitch)
        frameToggleSwitch.translatesAutoresizingMaskIntoConstraints = false
        frameToggleSwitch.isOn = true
        frameToggleSwitch.onTintColor = .systemBlue
        frameToggleSwitch.addTarget(self, action: #selector(toggleFrameVisibility), for: .valueChanged)

        // 2. Configure the Toolbar Container
        view.addSubview(toolbarContainer)
        toolbarContainer.translatesAutoresizingMaskIntoConstraints = false
        toolbarContainer.backgroundColor = .secondarySystemBackground
        toolbarContainer.layer.cornerRadius = 12
        toolbarContainer.clipsToBounds = true

        // 3. Configure the Segmented Control
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(self, action: #selector(segmentedControlChanged), for: .valueChanged)
        toolbarContainer.addSubview(segmentedControl)

        // 4. Configure the Scroll View (Colors/Textures)
        toolbarScrollView.showsHorizontalScrollIndicator = false
        toolbarScrollView.translatesAutoresizingMaskIntoConstraints = false
        toolbarScrollView.contentInset = .init(top: 0, left: 10, bottom: 0, right: 10)
        toolbarContainer.addSubview(toolbarScrollView)

        // 5. Configure the Stack View inside the Scroll View
        toolbarStackView.axis = .horizontal
        toolbarStackView.distribution = .fillProportionally
        toolbarStackView.alignment = .center
        toolbarStackView.spacing = 15
        toolbarStackView.translatesAutoresizingMaskIntoConstraints = false
        toolbarScrollView.addSubview(toolbarStackView)
        
        // 6. Configure the Sliders Container (NEW)
        setupSlidersContainer() // Removed explicit height, using constraint instead
        toolbarContainer.addSubview(slidersContainer)

        // Define the height constraint outside the array to assign an identifier
        let toolbarHeightConstraint = toolbarContainer.heightAnchor.constraint(equalToConstant: toolbarHeight)
        toolbarHeightConstraint.identifier = "toolbarHeightConstraint"
        toolbarHeightConstraint.isActive = true // Activate it immediately

        // 7. Set up Auto Layout Constraints
        NSLayoutConstraint.activate([
            // Frame Toggle Switch & Label Constraints (OUTSIDE, at bottom left)
            frameToggleSwitch.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            frameToggleSwitch.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            frameToggleLabel.centerXAnchor.constraint(equalTo: frameToggleSwitch.centerXAnchor),
            frameToggleLabel.bottomAnchor.constraint(equalTo: frameToggleSwitch.topAnchor, constant: -5),


            // Toolbar Container Constraints (at the bottom)
            toolbarContainer.leadingAnchor.constraint(equalTo: frameToggleSwitch.trailingAnchor, constant: 15),
            toolbarContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            toolbarContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            
            // Segmented Control Constraints
            segmentedControl.topAnchor.constraint(equalTo: toolbarContainer.topAnchor, constant: 10),
            segmentedControl.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor, constant: 10),
            segmentedControl.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor, constant: -10),
            
            // Scroll View Constraints (Colors/Textures)
            toolbarScrollView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
            toolbarScrollView.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor, constant: 0),
            toolbarScrollView.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor, constant: 0),
            toolbarScrollView.bottomAnchor.constraint(equalTo: toolbarContainer.bottomAnchor, constant: -10),
            toolbarScrollView.heightAnchor.constraint(equalToConstant: toolbarContentHeight),

            // Stack View Constraints (inside Scroll View)
            toolbarStackView.topAnchor.constraint(equalTo: toolbarScrollView.contentLayoutGuide.topAnchor),
            toolbarStackView.bottomAnchor.constraint(equalTo: toolbarScrollView.contentLayoutGuide.bottomAnchor),
            toolbarStackView.leadingAnchor.constraint(equalTo: toolbarScrollView.contentLayoutGuide.leadingAnchor),
            toolbarStackView.trailingAnchor.constraint(equalTo: toolbarScrollView.contentLayoutGuide.trailingAnchor),
            
            toolbarStackView.heightAnchor.constraint(equalTo: toolbarScrollView.heightAnchor),
            
            // Sliders Container Constraints (NEW) - takes the same space as ScrollView
            slidersContainer.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
            slidersContainer.leadingAnchor.constraint(equalTo: toolbarContainer.leadingAnchor, constant: 10),
            slidersContainer.trailingAnchor.constraint(equalTo: toolbarContainer.trailingAnchor, constant: -10),
            slidersContainer.bottomAnchor.constraint(equalTo: toolbarContainer.bottomAnchor, constant: -10),
        ])
    }
    
    // Helper to set up the thickness, depth, and roundness sliders
    private func setupSlidersContainer() {
        slidersContainer.axis = .vertical
        slidersContainer.distribution = .fillEqually
        slidersContainer.alignment = .fill
        slidersContainer.spacing = 5
        slidersContainer.translatesAutoresizingMaskIntoConstraints = false
        slidersContainer.isHidden = true // Initially hidden

        // --- Thickness Slider Group ---
        let thicknessStack = UIStackView()
        thicknessStack.axis = .horizontal
        thicknessStack.spacing = 10
        thicknessStack.alignment = .center

        thicknessLabel.text = "Thickness: \(String(format: "%.2f", currentFrameThickness))"
        thicknessLabel.font = .systemFont(ofSize: 12)
        thicknessLabel.textColor = .label
        thicknessLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true

        thicknessSlider.minimumValue = 0.01 // Min thickness in meters
        thicknessSlider.maximumValue = 0.15 // Max thickness in meters
        thicknessSlider.value = Float(currentFrameThickness)
        thicknessSlider.isContinuous = true
        thicknessSlider.addTarget(self, action: #selector(thicknessSliderValueChanged), for: .valueChanged)

        thicknessStack.addArrangedSubview(thicknessLabel)
        thicknessStack.addArrangedSubview(thicknessSlider)
        slidersContainer.addArrangedSubview(thicknessStack)

        // --- Depth Slider Group ---
        let depthStack = UIStackView()
        depthStack.axis = .horizontal
        depthStack.spacing = 10
        depthStack.alignment = .center

        depthLabel.text = "Depth: \(String(format: "%.2f", currentFrameDepth))"
        depthLabel.font = .systemFont(ofSize: 12)
        depthLabel.textColor = .label
        depthLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true

        depthSlider.minimumValue = 0.01 // Min depth in meters
        depthSlider.maximumValue = 0.15 // Max depth in meters
        depthSlider.value = Float(currentFrameDepth)
        depthSlider.isContinuous = true
        depthSlider.addTarget(self, action: #selector(depthSliderValueChanged), for: .valueChanged)

        depthStack.addArrangedSubview(depthLabel)
        depthStack.addArrangedSubview(depthSlider)
        slidersContainer.addArrangedSubview(depthStack)
        
        // --- NEW: Roundness Slider Group ---
        let roundnessStack = UIStackView()
        roundnessStack.axis = .horizontal
        roundnessStack.spacing = 10
        roundnessStack.alignment = .center

        roundnessLabel.text = "Roundness: \(String(format: "%.3f", currentFrameRoundness))"
        roundnessLabel.font = .systemFont(ofSize: 12)
        roundnessLabel.textColor = .label
        roundnessLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
        
        roundnessSlider.minimumValue = 0.00 // Min chamfer radius
        roundnessSlider.maximumValue = 0.05 // Max chamfer radius (relative to thickness/depth)
        roundnessSlider.value = Float(currentFrameRoundness)
        roundnessSlider.isContinuous = true
        roundnessSlider.addTarget(self, action: #selector(roundnessSliderValueChanged), for: .valueChanged)
        
        roundnessStack.addArrangedSubview(roundnessLabel)
        roundnessStack.addArrangedSubview(roundnessSlider)
        slidersContainer.addArrangedSubview(roundnessStack)
    }

    // MARK: - Actions

    // Handles the segmented control change event
    @objc private func segmentedControlChanged(_ sender: UISegmentedControl) {
        let mode: SelectionMode
        switch sender.selectedSegmentIndex {
        case 0: mode = .colors
        case 1: mode = .textures
        case 2: mode = .adjust // New segment
        default: return
        }
        updateSelectionToolbar(for: mode)
    }
    
    // Toggles frame visibility
    @objc private func toggleFrameVisibility() {
        isFrameVisible = frameToggleSwitch.isOn
        frameGroup?.isHidden = !isFrameVisible
        toolbarContainer.isHidden = !isFrameVisible
    }

    // Function to dynamically rebuild the toolbar content and adjust container height
    private func updateSelectionToolbar(for mode: SelectionMode) {
        // Toggle visibility of the content views
        let isColorOrTexture = (mode == .colors || mode == .textures)
        toolbarScrollView.isHidden = !isColorOrTexture
        slidersContainer.isHidden = isColorOrTexture

        // Clear and rebuild buttons only for Colors/Textures
        if isColorOrTexture {
            // Clear existing buttons from the stack view
            toolbarStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            
            let buttonSize: CGFloat = 40.0

            let items: [(content: Any, isTexture: Bool, name: String?)] = mode == .colors
                ? frameColors.map { ($0, false, nil) }
                : frameTextureNames.map { (UIImage(named: $0) ?? $0, true, $0) }
            
            for item in items {
                let button = SelectionButton(type: .custom)
                button.isTexture = item.isTexture
                
                if item.isTexture, let textureName = item.name {
                    button.textureName = textureName
                    // Configure appearance for texture buttons
                    button.layer.cornerRadius = 8
                    button.clipsToBounds = true
                    button.layer.borderColor = UIColor.systemGray.cgColor
                    button.layer.borderWidth = 1.0
                    button.setImage(UIImage(named: textureName), for: .normal)
                    NSLayoutConstraint.activate([
                        button.widthAnchor.constraint(equalToConstant: 60),
                        button.heightAnchor.constraint(equalToConstant: buttonSize)
                    ])
                } else if let color = item.content as? UIColor {
                    button.backgroundColor = color
                    // Configure appearance for color buttons
                    button.layer.cornerRadius = buttonSize / 2
                    button.clipsToBounds = true
                    button.layer.borderColor = UIColor.gray.cgColor
                    button.layer.borderWidth = 1.0
                    NSLayoutConstraint.activate([
                        button.widthAnchor.constraint(equalToConstant: buttonSize),
                        button.heightAnchor.constraint(equalToConstant: buttonSize)
                    ])
                }

                button.addTarget(self, action: #selector(selectionButtonTapped(_:)), for: .touchUpInside)
                toolbarStackView.addArrangedSubview(button)
            }
        }
    }

    // Unified action method to handle both color and texture selection, updating the SCNNodes
    @objc private func selectionButtonTapped(_ sender: SelectionButton) {
        if sender.isTexture {
            // Logic for applying a texture
            if let textureName = sender.textureName, let textureImage = UIImage(named: textureName) {
                // Apply the actual loaded texture image
                for node in frameNodes {
                    // Set the image as the diffuse content for all frame material
                    node.geometry?.firstMaterial?.diffuse.contents = textureImage
                    node.geometry?.firstMaterial?.metalness.contents = 0.0 // Reset PBR properties for texture
                    node.geometry?.firstMaterial?.roughness.contents = 1.0 // Reset PBR properties for texture
                }
                print("Applied Texture: \(textureName)")
            } else {
                // Fallback if texture image is not found (e.g., use a temporary placeholder color)
                for node in frameNodes {
                    node.geometry?.firstMaterial?.diffuse.contents = UIColor.brown.withAlphaComponent(0.8)
                }
                print("Texture not found, applied brown placeholder.")
            }
        } else {
            // Logic for applying a solid color
            guard let color = sender.backgroundColor else { return }
            for node in frameNodes {
                // Set the UIColor as the diffuse content
                node.geometry?.firstMaterial?.diffuse.contents = color
                // Apply default PBR properties for color materials
                node.geometry?.firstMaterial?.metalness.contents = 0.6
                node.geometry?.firstMaterial?.roughness.contents = 0.3
            }
            print("Applied Color: \(color.description)")
        }
    }
    
    // MARK: - Slider Handlers
    
    @objc private func thicknessSliderValueChanged(_ sender: UISlider) {
        let newThickness = CGFloat(sender.value)
        currentFrameThickness = newThickness
        thicknessLabel.text = "Thickness: \(String(format: "%.2f", newThickness))"
        updateFrameGeometry()
    }

    @objc private func depthSliderValueChanged(_ sender: UISlider) {
        let newDepth = CGFloat(sender.value)
        currentFrameDepth = newDepth
        depthLabel.text = "Depth: \(String(format: "%.2f", newDepth))"
        updateFrameGeometry()
    }
    
    // NEW: Slider handler for Roundness
    @objc private func roundnessSliderValueChanged(_ sender: UISlider) {
        let newRoundness = CGFloat(sender.value)
        currentFrameRoundness = newRoundness
        roundnessLabel.text = "Roundness: \(String(format: "%.3f", newRoundness))"
        updateFrameGeometry()
    }
    
    /**
     Updates the frame's geometry (thickness and depth) and repositions the image planes.
     This is achieved by recreating the frame's SCNNodes.
     
     UPDATED: Passes currentFrameRoundness.
     */
    private func updateFrameGeometry() {
        guard let frontImage = images.first, let scene = sceneView.scene else { return }
        
        // 1. Get current material... (Existing logic)
        guard let existingMaterial = frameNodes.first?.geometry?.firstMaterial else { return }
        
        let imageWidth: CGFloat = 1.0
        let imageHeight: CGFloat = frontImage.size.height / frontImage.size.width

        // 2. Recreate the frame nodes with new dimensions (Existing logic)
        createFrameNodes(
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            frameThickness: currentFrameThickness,
            frameDepth: currentFrameDepth,
            frameRoundness: currentFrameRoundness, // NEW
            frameMaterial: existingMaterial,
            scene: scene
        )
        
        // 3. Update the image planes' Y position (World Up/Down)
        let planeNodes = scene.rootNode.childNodes.filter { $0.geometry is SCNPlane }
        
        // Determine the offset needed to center the image within the new frame depth
        // The total frame depth is currentFrameDepth. The gap is currentFrameDepth - 0.05
        // 0.05 is the sum of two 0.025 offsets (one for front, one for back)
        let offset = Float(currentFrameDepth / 2) - 0.025
        // The previous implementation used 0.025, assuming a constant gap between the plane and the edge.
        // The dynamic value should be half the depth minus the assumed internal margin (0.025).

        for node in planeNodes {
            // This is the CRITICAL change: use Y instead of Z
            
            if node.eulerAngles.x < 0 { // Front plane (-pi/2)
                // Position closer to the camera side of the frame depth
                node.position = SCNVector3(0, offset, 0)
            } else { // Back plane (+pi/2)
                // Position closer to the back side of the frame depth
                node.position = SCNVector3(0, -offset, 0)
            }
        }
        
        print("Frame Updated: T=\(String(format: "%.2f", currentFrameThickness)), D=\(String(format: "%.2f", currentFrameDepth)), R=\(String(format: "%.3f", currentFrameRoundness))")
    }

    @objc private func dismissViewer() {
        dismiss(animated: true)
    }
    
    @objc private func viewInAR() {
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh){
            let tempDirectory = FileManager.default.temporaryDirectory
            let usdzURL = tempDirectory.appendingPathComponent("logosAR.usdz")
            
            // The write operation can be slow, especially for complex scenes.
            let success = sceneView.scene?.write(to: usdzURL, options: nil, delegate: nil, progressHandler: nil)
            if success == true{
                // Present the AR View Controller (assuming it's compatible)
                Helper.topViewController()?.present(ARUSDZViewController(usdzURL: usdzURL), animated: true)
            } else {
                print("Failed to write USDZ file for AR view.")
                // Optionally present an alert to the user
            }
        }
        else{
            let alert = UIAlertController(title: "Not Supported", message: "Scene reconstruction is not supported by this device.\nPlease try with different device which have LiDAR.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Okay", style: .default))
            Helper.topViewController()?.present(alert, animated: true)
        }
    }
}
