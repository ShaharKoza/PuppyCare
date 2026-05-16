import UIKit

final class ImageStorageManager {
    static let shared = ImageStorageManager()

    private let directory: URL

    private init() {
        // urls(for:in:) returns an empty array only if the search path doesn't exist on the
        // platform, which never happens for .documentDirectory on iOS. The fallback to the
        // temp directory is a pure safety net that should never be reached in practice.
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        directory = docs.appendingPathComponent("profile_images", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Compresses and saves a UIImage to the Documents/profile_images directory.
    /// Returns the filename on success, nil on failure.
    ///
    /// Implementation note — write is atomic relative to the final filename:
    ///   1. Write the JPEG to "<filename>.tmp" first.
    ///   2. If that succeeds, atomically rename to the final filename via
    ///      .atomic option on Data.write — POSIX guarantees the rename is
    ///      either fully visible or not visible at all.
    /// Without this, a write that fails halfway (out-of-space, app killed
    /// mid-write) left a partial JPEG that UIImage(data:) silently rejected
    /// later, and the profile's filename pointer became a dangling reference.
    func saveImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.65) else { return nil }
        let filename = "dog_profile_\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: [.atomic])
            return filename
        } catch {
            // Clean up any partial file the failed write may have left behind
            // so subsequent loadImage() calls return nil instead of decoding garbage.
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    /// Loads a UIImage from the Documents/profile_images directory by filename.
    func loadImage(filename: String) -> UIImage? {
        guard !filename.isEmpty else { return nil }
        let url = directory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Deletes an image file. Call this before saving a new photo to avoid orphaned files.
    func deleteImage(filename: String) {
        guard !filename.isEmpty else { return }
        let url = directory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
