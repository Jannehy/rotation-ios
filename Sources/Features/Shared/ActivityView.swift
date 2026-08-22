import SwiftUI
import UIKit

/// The system share sheet, handed a `UIImage`.
///
/// `ShareLink` offers a file, and a file only ever gets "Save to Files".
/// Photos accepts an image object, which is what puts "Save Image" in the
/// sheet – so sharing the picture takes this route instead.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
