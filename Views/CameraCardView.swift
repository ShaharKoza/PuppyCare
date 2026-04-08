import SwiftUI

/// Dashboard card that shows the latest Pi camera image.
/// Handles loading, error, and empty states.
/// Shows a "Capture" button when onCaptureRequest is provided.
/// Supports tap-to-full-screen.
struct CameraCardView: View {
    let imageURL: URL?
    var updatedAt: Date? = nil
    var capturePending: Bool = false
    var onCaptureRequest: (() -> Void)? = nil

    @State private var showFullScreen = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            imageArea
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
        .fullScreenCover(isPresented: $showFullScreen) {
            fullScreenViewer
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.accentBrown)
                    Text("Live Camera")
                        .font(AppTheme.sectionTitleFont)
                }
                if let updatedAt {
                    Text("Updated \(Self.timeFormatter.string(from: updatedAt))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                // Capture button — shown only when onCaptureRequest is wired
                if let onCaptureRequest {
                    Button {
                        onCaptureRequest()
                    } label: {
                        ZStack {
                            if capturePending {
                                ProgressView()
                                    .tint(AppTheme.accentBrown)
                                    .scaleEffect(0.75)
                            } else {
                                Image(systemName: "camera")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.accentBrown)
                            }
                        }
                        .frame(width: 32, height: 32)
                        .background(AppTheme.accentBrown.opacity(capturePending ? 0.06 : 0.10))
                        .clipShape(Circle())
                    }
                    .disabled(capturePending)
                    .animation(.easeInOut(duration: 0.15), value: capturePending)
                }

                // Expand button — shown only when an image is loaded
                if imageURL != nil {
                    Button {
                        showFullScreen = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.accentBrown)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.accentBrown.opacity(0.10))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    // MARK: - Image area

    @ViewBuilder
    private var imageArea: some View {
        if let url = imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    loadingView
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onTapGesture { showFullScreen = true }
                case .failure:
                    errorView
                @unknown default:
                    loadingView
                }
            }
        } else {
            emptyView
        }
    }

    // MARK: - State placeholders

    private var loadingView: some View {
        placeholder {
            VStack(spacing: 8) {
                ProgressView()
                    .tint(AppTheme.accentBrown)
                Text("Loading image…")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var errorView: some View {
        placeholder {
            VStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary)
                Text("Could not load image")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyView: some View {
        placeholder {
            VStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.accentBrown.opacity(0.30))
                Text("No image yet")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(.secondary)
                if onCaptureRequest != nil {
                    Text("Tap the camera button above to take a photo,\nor it will update automatically on motion.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("The camera will upload automatically\nafter the first motion or alert.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func placeholder<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.warmTile)
                .frame(height: 180)
            content()
        }
    }

    // MARK: - Full-screen viewer

    private var fullScreenViewer: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let url = imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .ignoresSafeArea()
                        case .empty:
                            ProgressView().tint(.white)
                        default:
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 36))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showFullScreen = false }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
