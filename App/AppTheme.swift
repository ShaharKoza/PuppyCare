import SwiftUI

enum AppTheme {
    // MARK: - Brand
    static let accentBrown = Color(red: 176/255, green: 126/255, blue: 84/255)

    // MARK: - Semantic backgrounds
    static let warmTile       = Color(.secondarySystemBackground)
    static let cardFill       = Color(.systemBackground)
    static let pageBackground = Color(.systemGroupedBackground)
    /// Recessed background for form inputs inside a card (creates a sunken-field feel).
    static let inputBackground = Color(.secondarySystemBackground)

    // MARK: - Borders & shadows
    static let softBorder = Color.primary.opacity(0.08)
    static let softShadow = Color.black.opacity(0.045)

    // MARK: - Corner radii
    static let cardRadius: CGFloat  = 22
    static let tileRadius: CGFloat  = 18
    static let fieldRadius: CGFloat = 14
    static let pillRadius: CGFloat  = 999

    // MARK: - Spacing
    static let horizontalPadding: CGFloat  = 18
    static let screenTopSpacing: CGFloat   = 10
    static let sectionSpacing: CGFloat     = 14
    static let contentSpacing: CGFloat     = 12
    static let cardPadding: CGFloat        = 16
    static let innerTilePadding: CGFloat   = 14

    // MARK: - Component heights
    static let sensorTileHeight: CGFloat   = 124
    static let summaryTileHeight: CGFloat  = 112
    static let compactTileHeight: CGFloat  = 88

    static let floatingButtonHeight: CGFloat            = 50
    static let floatingButtonHorizontalPadding: CGFloat = 22

    // MARK: - Typography
    static let titleFont: Font        = .system(size: 34, weight: .bold)
    static let sectionTitleFont: Font = .system(size: 19, weight: .bold)
    static let bodyTitleFont: Font    = .system(size: 18, weight: .bold)
    static let bodyFont: Font         = .system(size: 16, weight: .medium)
    /// Use for form field labels (slightly lighter than bodyFont).
    static let fieldLabelFont: Font   = .system(size: 15, weight: .semibold)
    static let captionFont: Font      = .system(size: 14, weight: .medium)
    static let tileLabelFont: Font    = .system(size: 13, weight: .medium)
    static let tileValueFont: Font    = .system(size: 20, weight: .bold)
}

// MARK: - Card style

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .fill(AppTheme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                            .stroke(AppTheme.softBorder, lineWidth: 1)
                    )
                    .shadow(color: AppTheme.softShadow, radius: 10, y: 4)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
