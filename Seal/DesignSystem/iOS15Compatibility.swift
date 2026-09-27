import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// iOS 15-compatible wrapper around PHPickerViewController.
/// Used instead of SwiftUI PhotosPicker, which requires iOS 16.
struct LegacyPhotoPicker: UIViewControllerRepresentable {
    let onPick: (Data?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPick: (Data?) -> Void

        init(onPick: @escaping (Data?) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                DispatchQueue.main.async { self.onPick(nil) }
                return
            }

            let provider = result.itemProvider
            let imageType = UTType.image.identifier
            guard provider.hasItemConformingToTypeIdentifier(imageType) else {
                DispatchQueue.main.async { self.onPick(nil) }
                return
            }

            provider.loadDataRepresentation(forTypeIdentifier: imageType) { data, _ in
                DispatchQueue.main.async {
                    self.onPick(data)
                }
            }
        }
    }
}

/// iOS 15-compatible share sheet used instead of the SwiftUI iOS 16 share control.
struct LegacyActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
