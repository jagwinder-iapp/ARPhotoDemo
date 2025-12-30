//
//  ContentView.swift
//  ARPhotoDemo
//
//  Created by Geetam Singh on 24/12/25.
//

import SwiftUI
import PhotosUI // Required for Photo Picker

struct ContentView: View {
    // MARK: - State Properties
    @State private var selectedImage: UIImage? = nil
    
    // For Photo Library
    @State private var photosPickerItem: PhotosPickerItem? = nil
    
    // For Files App
    @State private var isFileImporterPresented = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                
                // 1. Image Display Area
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedImage == nil ? Color.secondary.opacity(0.1) : Color.clear)
                        .frame(height: 300)
                    
                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                            .cornerRadius(12)
                    } else {
                        VStack {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 50))
                                .foregroundStyle(.gray)
                            Text("No Image Selected")
                                .foregroundStyle(.gray)
                        }
                    }
                }
                .padding()
                
                // Actual Controls
                HStack(spacing: 20) {
                    // A. Photo Picker Button
                    PhotosPicker(selection: $photosPickerItem, matching: .images) {
                        Label("Photos", systemImage: "photo")
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                    }
                    
                    // B. Files Button
                    Button(action: {
                        isFileImporterPresented = true
                    }) {
                        Label("Files", systemImage: "folder")
                            .padding()
                            .background(Color.indigo)
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                    }
                }
                
                if UIDevice.current.userInterfaceIdiom == .phone{
                    Spacer()
                }
                
                // 3. Go To AR Button
                Button{
                    if let image = selectedImage{
                        Helper.topViewController()?.present(USDZPreviewViewController(images: [image]), animated: true)
                    }
                } label: {
                    Text("Go to AR")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedImage == nil ? Color.gray : Color.green)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                }
                .disabled(selectedImage == nil) // Logic: Disabled if image is nil
                .padding()
            }
            .navigationTitle("Import Photo")
            
            // MARK: - Modifiers
            
            // Handle Photo Library Selection
            .onChange(of: photosPickerItem, perform: { newValue in

                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            self.selectedImage = uiImage
                        }
                    }
                }
            })
            
            // Handle File Import
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.image], // Limit to images
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    
                    // Security scoping is required to read files outside the sandbox
                    if url.startAccessingSecurityScopedResource() {
                        if let data = try? Data(contentsOf: url),
                           let uiImage = UIImage(data: data) {
                            self.selectedImage = uiImage
                        }
                        url.stopAccessingSecurityScopedResource()
                    }
                case .failure(let error):
                    print("File import failed: \(error.localizedDescription)")
                }
            }
        }
        .frame(maxWidth: 500)
    }
}

#Preview {
    ContentView()
}
