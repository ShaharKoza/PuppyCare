import SwiftUI

extension FoodSafetyStatus {
    var color: Color {
        switch self {
        case .safe:
            return .green
        case .caution:
            return .orange
        case .danger:
            return .red
        case .unknown:
            return Color(.systemGray)
        }
    }
}

struct FoodAssistantView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @FocusState private var isInputFocused: Bool

    @State private var queryText = ""
    @State private var result: FoodAssistantResult?
    @State private var isLoading = false

    private let service: FoodAssistantQuerying = FoodAssistantService.shared

    private let suggestions = [
        "Cucumber", "Banana", "Apple", "Eggs",
        "Peanut Butter", "Tuna", "Yogurt", "Grapes", "Chocolate"
    ]

    private var dogName: String {
        let n = profileStore.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "your dog" : n.capitalized
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                headerSection
                inputCard

                if result == nil && !isLoading {
                    suggestionsSection
                }

                if let result {
                    resultCard(result)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer(minLength: 12)
                disclaimer
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, AppTheme.screenTopSpacing)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.3), value: result == nil)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Food Assistant")
                .font(AppTheme.titleFont)

            Text("Ask what \(dogName) can safely eat")
                .font(AppTheme.bodyFont)
                .foregroundStyle(.secondary)
        }
    }

    private var inputCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("e.g. Can my dog eat cucumber?", text: $queryText)
                    .font(AppTheme.bodyFont)
                    .focused($isInputFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { askQuestion() }
                    .onChange(of: queryText) { _, _ in
                        if result != nil {
                            result = nil
                        }
                    }

                if !queryText.isEmpty {
                    Button {
                        queryText = ""
                        result = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(.systemGray3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(AppTheme.warmTile)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous))

            Button {
                askQuestion()
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                    }

                    Text(isLoading ? "Thinking…" : "Ask PuppyCare")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    (queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    ? AppTheme.accentBrown.opacity(0.40)
                    : AppTheme.accentBrown
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous))
                .animation(.easeInOut(duration: 0.15), value: isLoading)
            }
            .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try asking about")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { food in
                        suggestionChip(food)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func suggestionChip(_ food: String) -> some View {
        Button {
            queryText = "Can my dog eat \(food.lowercased())?"
            askQuestion()
        } label: {
            Text(food)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.accentBrown)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.accentBrown.opacity(0.10))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func resultCard(_ r: FoodAssistantResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: r.status.icon)
                    .font(.system(size: 14, weight: .bold))

                Text(r.status.label)
                    .font(.system(size: 14, weight: .bold))

                Spacer(minLength: 0)
            }
            .foregroundStyle(r.status.color)
            .padding(.horizontal, AppTheme.cardPadding)
            .padding(.vertical, 12)
            .background(r.status.color.opacity(0.10))

            VStack(alignment: .leading, spacing: 12) {
                Text(r.headline)
                    .font(AppTheme.sectionTitleFont)

                Text(r.explanation)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !r.tips.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(r.tips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 5))
                                    .foregroundStyle(r.status.color)
                                    .padding(.top, 7)

                                Text(tip)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.cardPadding)
        }
        .background(AppTheme.cardFill)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(r.status.color.opacity(0.25), lineWidth: 1.5)
        )
        .shadow(color: AppTheme.softShadow, radius: 10, y: 4)
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.tertiary)
                .padding(.top, 1)

            Text("General guidance only — not a substitute for professional veterinary advice. Always consult your vet if you are unsure about your dog's diet or health.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
    }

    private func askQuestion() {
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isInputFocused = false
        isLoading = true
        result = nil

        Task {
            let response = await service.query(trimmed)
            withAnimation(.spring(duration: 0.4)) {
                result = response
                isLoading = false
            }
        }
    }
}
