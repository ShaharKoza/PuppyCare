import SwiftUI

struct CameraCardView: View {
    let imageURL: URL?
    var updatedAt: Date? = nil

    @State private var showFullScreen = false

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

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

            if imageURL != nil {
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
                case .empty:
                    placeholder {
                        VStack(spacing: 8) {
                            ProgressView()
                                .tint(AppTheme.accentBrown)

                            Text("Loading latest snapshot…")
                                .font(AppTheme.captionFont)
                                .foregroundStyle(.secondary)
                        }
                    }

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

                        if let updatedAt {
                            Text("Last snapshot: \(relativeTime(from: updatedAt))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.55))
                                .clipShape(Capsule())
                                .padding(10)
                        } else {
                            Text("Snapshot \(Self.timeFormatter.string(from: Date()))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.55))
                                .clipShape(Capsule())
                                .padding(10)
                        }
                    }

                case .failure:
                    placeholder {
                        VStack(spacing: 10) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 22))
                                .foregroundStyle(.secondary)

                            Text("Can’t load the latest snapshot")
                                .font(AppTheme.bodyFont)
                                .foregroundStyle(.secondary)

                            Text("Check the iPhone and Raspberry Pi are on the same Wi-Fi.")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 12)
                    }

                @unknown default:
                    placeholder {
                        ProgressView()
                            .tint(AppTheme.accentBrown)
                    }
                }
            }
        } else {
            placeholder {
                VStack(spacing: 10) {
                    Image(systemName: "camera.slash")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.accentBrown.opacity(0.30))

                    Text("Waiting for first snapshot")
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(.secondary)

                    Text("The Raspberry Pi has not published a camera image yet.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 12)
            }
        }
    }

    private func placeholder<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.warmTile)
                .frame(height: 156)

            content()
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

                        case .empty:
                            ProgressView()
                                .tint(.white)

                        default:
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 36))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                } else {
                    Image(systemName: "camera.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.5))
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
