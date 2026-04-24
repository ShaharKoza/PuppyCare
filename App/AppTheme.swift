import SwiftUI

enum AppTheme {
    static let accentBrown = Color(red: 176/255, green: 126/255, blue: 84/255)

    static let warmTile = Color(.secondarySystemBackground)
    static let cardFill = Color(.systemBackground)
    static let pageBackground = Color(.systemGroupedBackground)
    static let inputBackground = Color(.secondarySystemBackground)

    static let alertWarning = Color(red: 224/255, green: 175/255, blue: 0)
    static let alertStress = Color.orange
    static let alertEmergency = Color.red
    static let alertNormal = Color.green

    static let softBorder = Color.primary.opacity(0.08)
    static let softShadow = Color.black.opacity(0.045)

    static let cardRadius: CGFloat = 22
    static let tileRadius: CGFloat = 18
    static let fieldRadius: CGFloat = 14
    static let pillRadius: CGFloat = 999

    // קומפקטי יותר כדי ליישר קו עם עמוד הפרופיל
    static let horizontalPadding: CGFloat = 16
    static let screenTopSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 10
    static let contentSpacing: CGFloat = 10
    static let cardPadding: CGFloat = 14
    static let innerTilePadding: CGFloat = 12

    // כרטיסים קטנים יותר לדשבורד
    static let sensorTileHeight: CGFloat = 94
    static let summaryTileHeight: CGFloat = 92
    static let compactTileHeight: CGFloat = 74

    static let floatingButtonHeight: CGFloat = 50
    static let floatingButtonHorizontalPadding: CGFloat = 22

    // טיפוגרפיה מאוזנת יותר
    static let titleFont: Font = .system(size: 30, weight: .bold)
    static let sectionTitleFont: Font = .system(size: 17, weight: .bold)
    static let bodyTitleFont: Font = .system(size: 16, weight: .bold)
    static let bodyFont: Font = .system(size: 15, weight: .medium)
    static let fieldLabelFont: Font = .system(size: 14, weight: .semibold)
    static let captionFont: Font = .system(size: 13, weight: .medium)
    static let tileLabelFont: Font = .system(size: 12, weight: .medium)
    static let tileValueFont: Font = .system(size: 16, weight: .bold)
}

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
