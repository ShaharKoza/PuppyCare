import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @EnvironmentObject var profileStore: ProfileStore

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var breedSearchText: String = ""

    private var filteredBreeds: [String] {
        DogDataOptions.prioritizedBreeds(searchText: breedSearchText)
    }

    private var isMixedBreedSelection: Bool {
        DogDataOptions.mixedBreedOptions.contains(profileStore.profile.breed)
    }

    private var completedRequiredFields: Int {
        var count = 0
        if !profileStore.profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty      { count += 1 }
        if !profileStore.profile.breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty     { count += 1 }
        if !profileStore.profile.sex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty       { count += 1 }
        if !profileStore.profile.ageMonths.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if !profileStore.profile.weightKg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  { count += 1 }
        return count
    }

    private let totalRequiredFields = 5

    private var progressValue: Double {
        Double(completedRequiredFields) / Double(totalRequiredFields)
    }

    private var canContinue: Bool { profileStore.profile.isCompleteForOnboarding }

    private var profileImage: UIImage? {
        guard !profileStore.profile.profileImageFilename.isEmpty else { return nil }
        return ImageStorageManager.shared.loadImage(filename: profileStore.profile.profileImageFilename)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppTheme.sectionSpacing) {
                headerSection
                progressSection
                photoSection
                formCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, AppTheme.screenTopSpacing)
            .padding(.bottom, 16)
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: selectedPhotoItem) {
            await loadSelectedPhoto()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("Puppy Setup")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.accentBrown)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.accentBrown.opacity(0.10))
                    .clipShape(Capsule())
                Spacer()
            }

            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.accentBrown.opacity(0.10))
                        .frame(width: 52, height: 52)
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppTheme.accentBrown)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("PuppyCare")
                        .font(.system(size: 30, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                    Text("Set up your puppy's profile to get started.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
        }
        .padding(18)
        .cardStyle()
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Setup progress")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(completedRequiredFields)/\(totalRequiredFields) complete")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.12))
                        .frame(height: 9)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: canContinue
                                    ? [Color.green, Color.green.opacity(0.75)]
                                    : [AppTheme.accentBrown, AppTheme.accentBrown.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(16, geometry.size.width * progressValue),
                            height: 9
                        )
                        .animation(.spring(duration: 0.4), value: progressValue)
                }
            }
            .frame(height: 9)

            Text(canContinue
                 ? "Everything is ready. Tap Continue when you want to enter the app."
                 : "Complete the required fields to continue.")
                .font(AppTheme.captionFont)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .cardStyle()
    }

    // MARK: - Photo section

    private var photoSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.accentBrown.opacity(0.16),
                                AppTheme.accentBrown.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 114, height: 114)

                if let image = profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 106, height: 106)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(AppTheme.accentBrown)
                }
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 7) {
                    Image(systemName: "camera.fill")
                    Text(profileImage == nil ? "Add Puppy Photo" : "Change Photo")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.accentBrown)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.accentBrown.opacity(0.10))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    // MARK: - Form card

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            inputField(
                title: "Dog Name",
                isCompleted: !profileStore.profile.name
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                TextField("e.g. Charlie", text: $profileStore.profile.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }

            breedPickerSection

            menuPicker(
                title: "Sex",
                selection: $profileStore.profile.sex,
                options: DogDataOptions.sexOptions,
                placeholder: "Select sex",
                isCompleted: !profileStore.profile.sex.isEmpty
            )

            menuPicker(
                title: "Age (Months)",
                selection: $profileStore.profile.ageMonths,
                options: DogDataOptions.ageMonths,
                placeholder: "Select age",
                isCompleted: !profileStore.profile.ageMonths.isEmpty
            )

            menuPicker(
                title: "Weight (kg)",
                selection: $profileStore.profile.weightKg,
                options: DogDataOptions.weightOptions,
                placeholder: "Select weight",
                isCompleted: !profileStore.profile.weightKg.isEmpty
            )

            Toggle(isOn: $profileStore.profile.isInKennel) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Dog Currently In Kennel")
                        .font(.system(size: 15, weight: .semibold))
                    Text("You can change this later from the main app.")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: AppTheme.accentBrown))
            .padding(.top, 2)

            // Continue button
            Button {
                guard canContinue else { return }
                profileStore.profile.hasCompletedOnboarding = true
            } label: {
                HStack(spacing: 8) {
                    Spacer()
                    if canContinue {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text("Continue")
                    Image(systemName: "arrow.right")
                    Spacer()
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .padding(.vertical, 15)
                .background(
                    canContinue
                        ? LinearGradient(
                            colors: [AppTheme.accentBrown, AppTheme.accentBrown.opacity(0.82)],
                            startPoint: .leading, endPoint: .trailing
                          )
                        : LinearGradient(
                            colors: [Color.gray.opacity(0.55), Color.gray.opacity(0.55)],
                            startPoint: .leading, endPoint: .trailing
                          )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius + 2, style: .continuous))
                .shadow(
                    color: canContinue ? AppTheme.accentBrown.opacity(0.20) : .clear,
                    radius: 12, y: 6
                )
            }
            .disabled(!canContinue)
            .animation(.easeInOut(duration: 0.2), value: canContinue)
            .padding(.top, 4)
        }
        .padding(20)
        .cardStyle()
    }

    // MARK: - Breed picker section

    private var breedPickerSection: some View {
        let completed = !profileStore.profile.breed
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                fieldTitle("Breed", isCompleted: completed)

                if isMixedBreedSelection {
                    Text("Mixed")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            TextField("Search breed or mixed breed", text: $breedSearchText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(AppTheme.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous))

            Menu {
                if !DogDataOptions.mixedBreedOptions.isEmpty {
                    Section("Mixed Breed Options") {
                        ForEach(DogDataOptions.mixedBreedOptions, id: \.self) { breed in
                            Button(breed) {
                                profileStore.profile.breed = breed
                                breedSearchText = ""
                            }
                        }
                    }
                }
                Section("All Breeds") {
                    ForEach(
                        filteredBreeds.filter { !DogDataOptions.mixedBreedOptions.contains($0) },
                        id: \.self
                    ) { breed in
                        Button(breed) {
                            profileStore.profile.breed = breed
                            breedSearchText = ""
                        }
                    }
                }
            } label: {
                menuLabel(
                    text: profileStore.profile.breed.isEmpty
                          ? "Select breed"
                          : profileStore.profile.breed,
                    isPlaceholder: profileStore.profile.breed.isEmpty,
                    isCompleted: completed
                )
            }
        }
    }

    // MARK: - Form field helpers

    private func inputField<Content: View>(
        title: String,
        isCompleted: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldTitle(title, isCompleted: isCompleted)

            content()
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(AppTheme.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous))
        }
    }

    private func menuPicker(
        title: String,
        selection: Binding<String>,
        options: [String],
        placeholder: String,
        isCompleted: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldTitle(title, isCompleted: isCompleted)

            Menu {
                ForEach(options, id: \.self) { item in
                    Button(item) { selection.wrappedValue = item }
                }
            } label: {
                menuLabel(
                    text: selection.wrappedValue.isEmpty ? placeholder : selection.wrappedValue,
                    isPlaceholder: selection.wrappedValue.isEmpty,
                    isCompleted: isCompleted
                )
            }
        }
    }

    private func menuLabel(text: String, isPlaceholder: Bool, isCompleted: Bool) -> some View {
        HStack {
            Text(text)
                .foregroundStyle(isPlaceholder ? .secondary : .primary)
                .lineLimit(1)
            Spacer()
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "chevron.down")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isCompleted ? .green : AppTheme.accentBrown.opacity(0.70))
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(AppTheme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous))
    }

    private func fieldTitle(_ title: String, isCompleted: Bool) -> some View {
        HStack(spacing: 7) {
            Text(title)
                .font(AppTheme.fieldLabelFont)
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Photo loading

    private func loadSelectedPhoto() async {
        guard
            let selectedPhotoItem,
            let data = try? await selectedPhotoItem.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else { return }

        if !profileStore.profile.profileImageFilename.isEmpty {
            ImageStorageManager.shared.deleteImage(
                filename: profileStore.profile.profileImageFilename
            )
        }
        if let filename = ImageStorageManager.shared.saveImage(image) {
            profileStore.profile.profileImageFilename = filename
        }
    }
}
