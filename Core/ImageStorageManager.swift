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
    func saveImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.65) else { return nil }
        let filename = "dog_profile_\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return filename
        } catch {
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
