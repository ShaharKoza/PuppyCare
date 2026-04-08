import SwiftUI

// MARK: - Training Category

private enum TrainingCategory: String, CaseIterable, Identifiable {
    case basics       = "basics"
    case reinforcement = "reinforcement"
    case kennel       = "kennel"
    case leash        = "leash"
    case routine      = "routine"
    case behavior     = "behavior"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .basics:        return "Basics"
        case .reinforcement: return "Reinforcement"
        case .kennel:        return "Kennel"
        case .leash:         return "Leash"
        case .routine:       return "Routine"
        case .behavior:      return "Behavior"
        }
    }

    var icon: String {
        switch self {
        case .basics:        return "star.fill"
        case .reinforcement: return "hand.thumbsup.fill"
        case .kennel:        return "house.fill"
        case .leash:         return "figure.walk"
        case .routine:       return "clock.fill"
        case .behavior:      return "brain.head.profile"
        }
    }

    var tint: Color {
        switch self {
        case .basics:        return .yellow
        case .reinforcement: return .green
        case .kennel:        return AppTheme.accentBrown
        case .leash:         return .blue
        case .routine:       return .purple
        case .behavior:      return .orange
        }
    }
}

// MARK: - Training Tip

private struct TrainingTip: Identifiable {
    var id: String { title }
    let title:    String
    let body:     String
    let icon:     String
    let category: TrainingCategory

    static let allTips: [TrainingTip] = [

        // Basics
        TrainingTip(
            title: "Teach 'Sit' First",
            body:  "Sit is the foundation for almost every other command. Hold a treat above your dog's nose, move it back slowly — their bottom will naturally lower. Say 'Sit', reward immediately.",
            icon:  "hand.point.up.fill",
            category: .basics
        ),
        TrainingTip(
            title: "Keep Sessions Short",
            body:  "Puppies concentrate for 3–5 minutes, adult dogs 10–15 minutes max. Multiple short sessions every day beat a single long one. End on a success so they finish motivated.",
            icon:  "timer",
            category: .basics
        ),
        TrainingTip(
            title: "One Command at a Time",
            body:  "Introduce one new cue per session. Mixing multiple commands before mastering each one creates confusion and slows progress for both of you.",
            icon:  "1.circle.fill",
            category: .basics
        ),

        // Positive Reinforcement
        TrainingTip(
            title: "Reward Within 2 Seconds",
            body:  "Dogs connect the treat to the action that happened 1–2 seconds ago. A delayed reward teaches nothing — or worse, rewards the wrong behavior.",
            icon:  "clock.badge.checkmark.fill",
            category: .reinforcement
        ),
        TrainingTip(
            title: "Vary Your Rewards",
            body:  "Alternate between food treats, verbal praise, and play. Variable rewards keep dogs more engaged and motivated than a predictable treat every single time.",
            icon:  "shuffle",
            category: .reinforcement
        ),
        TrainingTip(
            title: "Never Punish Confusion",
            body:  "If your dog doesn't respond, they likely don't understand yet — not disobeying. Ignore the non-response, reset, ask again from a shorter distance or simpler context.",
            icon:  "heart.fill",
            category: .reinforcement
        ),

        // Kennel Training
        TrainingTip(
            title: "Make the Kennel a Safe Place",
            body:  "Feed meals inside the kennel with the door open before you ever close it. Your dog should voluntarily enter before any confinement begins.",
            icon:  "house.fill",
            category: .kennel
        ),
        TrainingTip(
            title: "Build Duration Gradually",
            body:  "Start with 1 minute in the closed kennel while you're in view, then 5, then 10. Never go from open-door feeding to an hour of confinement in one step.",
            icon:  "chart.line.uptrend.xyaxis",
            category: .kennel
        ),
        TrainingTip(
            title: "Don't Open for Whining",
            body:  "If you open the kennel door when your dog whines, you teach them whining works. Wait for a 3-second quiet pause, then open — reward quiet, not noise.",
            icon:  "speaker.slash.fill",
            category: .kennel
        ),

        // Leash
        TrainingTip(
            title: "Loose Leash Walking",
            body:  "Stop the moment the leash goes tight. Stand still until your dog returns to your side, then continue. Consistency teaches them that pulling stops forward progress.",
            icon:  "figure.walk",
            category: .leash
        ),
        TrainingTip(
            title: "Reward Check-ins",
            body:  "Any time your dog looks up at you during a walk, reward it immediately. Eye contact while walking builds the habit of attention and makes loose-leash walking natural.",
            icon:  "eye.fill",
            category: .leash
        ),
        TrainingTip(
            title: "Use High-Value Treats Outside",
            body:  "The outdoor environment is full of distractions. Use small pieces of chicken, cheese, or hot dog — not kibble — to compete with all the interesting smells and sights.",
            icon:  "star.circle.fill",
            category: .leash
        ),

        // Routine
        TrainingTip(
            title: "Same Times Every Day",
            body:  "Dogs thrive on predictability. Feeding, walking, and play sessions at consistent times reduces anxiety and makes your dog easier to manage throughout the day.",
            icon:  "clock.fill",
            category: .routine
        ),
        TrainingTip(
            title: "Post-Meal Toilet Walks",
            body:  "Most puppies need to toilet within 15–20 minutes of eating. Schedule a walk or garden trip right after every meal to establish this habit early.",
            icon:  "figure.walk.motion",
            category: .routine
        ),
        TrainingTip(
            title: "Evening Wind-Down",
            body:  "Reduce play intensity in the hour before bedtime. Calm activities and a final short walk signal to your dog that quiet time is coming — smoother nights start here.",
            icon:  "moon.fill",
            category: .routine
        ),

        // Behavior
        TrainingTip(
            title: "Redirect, Don't React",
            body:  "When your dog chews something they shouldn't, calmly redirect to an appropriate toy — don't chase or shout, which makes the behavior more exciting and rewarding.",
            icon:  "arrow.uturn.left.circle.fill",
            category: .behavior
        ),
        TrainingTip(
            title: "Prevent Jumping Early",
            body:  "Turn your back and fold your arms every time your dog jumps up. Only give attention — including eye contact — when all four paws are on the floor.",
            icon:  "figure.stand",
            category: .behavior
        ),
        TrainingTip(
            title: "Socialization Window",
            body:  "The critical socialization period closes around 12–16 weeks. Safely expose your puppy to different people, sounds, surfaces, and environments during this window — it shapes behavior for life.",
            icon:  "person.3.fill",
            category: .behavior
        ),
    ]
}

// MARK: - Training View

struct TrainingView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @State private var selectedCategory: TrainingCategory? = nil

    private var dogName: String {
        let n = profileStore.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "your dog" : n.capitalized
    }

    private var filteredTips: [TrainingTip] {
        guard let cat = selectedCategory else { return TrainingTip.allTips }
        return TrainingTip.allTips.filter { $0.category == cat }
    }

    private var groupedTips: [(category: TrainingCategory, tips: [TrainingTip])] {
        if let cat = selectedCategory {
            let tips = TrainingTip.allTips.filter { $0.category == cat }
            return tips.isEmpty ? [] : [(category: cat, tips: tips)]
        }
        return TrainingCategory.allCases.map { cat in
            (category: cat, tips: TrainingTip.allTips.filter { $0.category == cat })
        }
    }

    /// Picks a "today's focus" tip based on the day of year so it rotates daily.
    private var todaysTip: TrainingTip {
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let tips = TrainingTip.allTips
        return tips[(dayIndex - 1) % tips.count]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                headerSection
                todaysFocusCard
                smartKennelCard
                filterChipsRow
                tipsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, AppTheme.screenTopSpacing)
            .padding(.bottom, 40)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Training")
                .font(AppTheme.titleFont)
            Text("Tips and techniques for \(dogName)")
                .font(AppTheme.bodyFont)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Today's Focus Card

    private var todaysFocusCard: some View {
        let tip = todaysTip
        return VStack(alignment: .leading, spacing: AppTheme.contentSpacing) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tip.category.tint)
                Text("Today's Focus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tip.category.tint)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer(minLength: 0)
                Text(tip.category.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tip.category.tint.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: tip.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tip.category.tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.title)
                        .font(AppTheme.bodyTitleFont)
                    Text(tip.body)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    // MARK: - PuppyCare Integration Card

    private var smartKennelCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.contentSpacing) {
            Text("PuppyCare Integration")
                .font(AppTheme.sectionTitleFont)

            VStack(spacing: 0) {
                integrationRow(
                    icon: "house.fill",
                    iconColor: AppTheme.accentBrown,
                    title: "Kennel as Safe Zone",
                    subtitle: "Use PuppyCare sensors to confirm a calm environment before training sessions in the kennel."
                )
                Divider().padding(.leading, 52)
                integrationRow(
                    icon: "thermometer.medium",
                    iconColor: .orange,
                    title: "Temperature Aware",
                    subtitle: "Avoid training outdoors when kennel temps are above 28°C — your dog may already be stressed."
                )
                Divider().padding(.leading, 52)
                integrationRow(
                    icon: "waveform",
                    iconColor: .purple,
                    title: "Barking Patterns",
                    subtitle: "High bark counts in the morning often signal excess energy — add a play session before training."
                )
                Divider().padding(.leading, 52)
                integrationRow(
                    icon: "clock.fill",
                    iconColor: .blue,
                    title: "Routine Timing",
                    subtitle: "Schedule training sessions in Routine for 20–30 minutes after a meal walk when your dog is calm."
                )
            }
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    private func integrationRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Filter Chips

    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", icon: "list.bullet", color: .gray, isSelected: selectedCategory == nil) {
                    withAnimation(.spring(duration: 0.25)) { selectedCategory = nil }
                }
                ForEach(TrainingCategory.allCases) { cat in
                    filterChip(
                        label: cat.displayName,
                        icon: cat.icon,
                        color: cat.tint,
                        isSelected: selectedCategory == cat
                    ) {
                        withAnimation(.spring(duration: 0.25)) {
                            selectedCategory = (selectedCategory == cat) ? nil : cat
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
        }
        .padding(.horizontal, -AppTheme.horizontalPadding)
    }

    private func filterChip(label: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(AppTheme.captionFont)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : AppTheme.warmTile)
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tips Section

    @ViewBuilder
    private var tipsSection: some View {
        ForEach(groupedTips, id: \.category) { group in
            VStack(alignment: .leading, spacing: 8) {
                // Section header (hidden when a single category is selected)
                if selectedCategory == nil {
                    HStack(spacing: 6) {
                        Image(systemName: group.category.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(group.category.tint)
                        Text(group.category.displayName)
                            .font(AppTheme.captionFont)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }
                    .padding(.horizontal, 4)
                }

                VStack(spacing: 0) {
                    ForEach(group.tips) { tip in
                        tipRow(tip, groupCategory: group.category)
                        if group.tips.last?.id != tip.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
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
    }

    private func tipRow(_ tip: TrainingTip, groupCategory: TrainingCategory) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(groupCategory.tint.opacity(0.13))
                    .frame(width: 36, height: 36)
                Image(systemName: tip.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(groupCategory.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(.primary)
                Text(tip.body)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.cardPadding)
        .padding(.vertical, 14)
    }
}
