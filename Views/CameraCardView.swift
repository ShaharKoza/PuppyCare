import SwiftUI

struct CameraCardView: View {
    let imageURL: URL?
    var updatedAt: Date? = nil

    @State private var showFullScreen = false

    /// Bundled fallback shown whenever there is no live camera frame (no URL,
    /// still loading, or the load failed). The moment the Raspberry Pi camera
    /// publishes a working URL again, AsyncImage's `.success` branch takes
    /// over automatically — no code change needed to switch back to live.
    private let placeholderImageName = "KennelPlaceholder"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            snapshotArea
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
        .fullScreenCover(isPresented: $showFullScreen) {
            fullScreenViewer
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accentBrown)

                Text("Camera Snapshot")
                    .font(AppTheme.sectionTitleFont)
                    .lineLimit(1)

                snapshotBadge
            }

            Spacer()

            // Always available — there's always something to expand (live frame
            // or the bundled placeholder).
            Button {
                showFullScreen = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.accentBrown)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.accentBrown.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var snapshotBadge: some View {
        Text("Snapshot")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(AppTheme.accentBrown)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.accentBrown.opacity(0.10))
            .clipShape(Capsule())
    }

    // MARK: - Snapshot area

    @ViewBuilder
    private var snapshotArea: some View {
        if let url = imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    ZStack(alignment: .bottomLeading) {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 156)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .onTapGesture {
                                showFullScreen = true
                            }

                        Text(updatedAt.map { "Last snapshot: \(relativeTime(from: $0))" } ?? "Live stream")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.55))
                            .clipShape(Capsule())
                            .padding(10)
                    }

                default:
                    // .empty (loading) and .failure both fall back to the
                    // bundled snapshot so the card never shows a spinner or an
                    // error — the live frame replaces it the instant it loads.
                    staticSnapshot
                }
            }
        } else {
            staticSnapshot
        }
    }

    /// The bundled placeholder, styled exactly like a live frame.
    private var staticSnapshot: some View {
        Image(placeholderImageName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 156)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture {
                showFullScreen = true
            }
    }

    // MARK: - Full screen

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

                        default:
                            // Loading or failed → show the bundled snapshot
                            // full-screen, consistent with the card.
                            Image(placeholderImageName)
                                .resizable()
                                .scaledToFit()
                                .ignoresSafeArea()
                        }
                    }
                } else {
                    Image(placeholderImageName)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showFullScreen = false
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Helpers

    private func relativeTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}
