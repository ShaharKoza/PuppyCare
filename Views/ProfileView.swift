import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var profileStore: ProfileStore

    @State private var isEditing               = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var breedSearchText         = ""
    @State private var showDeleteConfirmation  = false

    private var filteredBreeds: [String] {
        DogDataOptions.prioritizedBreeds(searchText: breedSearchText)
    }
    private var isMixedBreedSelection: Bool {
        DogDataOptions.mixedBreedOptions.contains(profileStore.profile.breed)
    }
    private var profileImage: UIImage? {
        guard !profileStore.profile.profileImageFilename.isEmpty else { return nil }
        return ImageStorageManager.shared.loadImage(filename: profileStore.profile.profileImageFilename)
    }
    private var displayName: String {
        let name = profileStore.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "My Dog" : name.capitalized
    }
    private var profileSubtitle: String {
        let breed = profileStore.profile.breed.trimmingCharacters(in: .whitespacesAndNewlines)
        let sex   = profileStore.profile.sex.trimmingCharacters(in: .whitespacesAndNewlines)
        if breed.isEmpty && sex.isEmpty { return "Dog profile" }
        if breed.isEmpty { return sex }
        if sex.isEmpty   { return breed }
        return "\(breed) • \(sex)"
    }
    private var ageText:    String { profileStore.profile.ageMonths.isEmpty  ? "Not set" : "\(profileStore.profile.ageMonths) mo" }
    private var weightText: String { profileStore.profile.weightKg.isEmpty   ? "Not set" : "\(profileStore.profile.weightKg) kg" }
    private var foodText:   String {
        let food = profileStore.profile.foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        return food.isEmpty ? "Not set" : food
    }
    private var sexText: String { profileStore.profile.sex.isEmpty ? "Not set" : profileStore.profile.sex }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                topBar
                compactHeaderCard
                kennelCard
                overviewCard
                if isEditing { editableDetailsCard } else { compactDetailsCard }
                aboutCard
                dataCard
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
        .task(id: selectedPhotoItem) { await loadSelectedPhoto() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Spacer()
            Button(isEditing ? "Done" : "Edit") {
                withAnimation(.easeInOut(duration: 0.2)) { isEditing.toggle() }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isEditing ? .white : AppTheme.accentBrown)
            .padding(.horizontal, AppTheme.floatingButtonHorizontalPadding)
            .frame(height: AppTheme.floatingButtonHeight)
            .background(isEditing ? AppTheme.accentBrown : Color(.systemBackground))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Header card

    private var compactHeaderCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(AppTheme.accentBrown.opacity(0.12)).frame(width: 82, height: 82)
                if let image = profileImage {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 82, height: 82).clipShape(Circle())
                } else {
                    Image(systemName: "pawprint.fill").font(.system(size: 30)).foregroundStyle(AppTheme.accentBrown)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(displayName).font(AppTheme.titleFont).lineLimit(1).minimumScaleFactor(0.82)
                Text(profileSubtitle).font(AppTheme.bodyFont).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .cardStyle()
    }

    // MARK: - Kennel card

    private var kennelCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(profileStore.profile.isInKennel ? Color.green.opacity(0.14) : Color.orange.opacity(0.14))
                    .frame(width: 52, height: 52)
                Image(systemName: profileStore.profile.isInKennel ? "house.fill" : "figure.walk")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(profileStore.profile.isInKennel ? .green : .orange)
            }
            .animation(.easeInOut(duration: 0.2), value: profileStore.profile.isInKennel)

            VStack(alignment: .leading, spacing: 3) {
                Text("Kennel Presence").font(AppTheme.captionFont).foregroundStyle(.secondary)
                Text(profileStore.profile.isInKennel ? "Dog is in the kennel" : "Dog is outside the kennel")
                    .font(AppTheme.bodyTitleFont).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $profileStore.profile.isInKennel)
                .labelsHidden().tint(AppTheme.accentBrown)
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    // MARK: - Overview card

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview").font(AppTheme.sectionTitleFont)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statTile(title: "Age",    value: ageText)
                statTile(title: "Weight", value: weightText)
                statTile(title: "Sex",    value: sexText)
                statTile(title: "Food",   value: foodText)
            }
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    // MARK: - Compact details (read-only)

    private var routineItemsSummary: String {
        let profile = profileStore.profile
        guard !profile.scheduleItems.isEmpty else { return "None set" }
        var parts: [String] = []
        let m = profile.mealItems.count
        let w = profile.walkItems.count
        let p = profile.playItems.count
        if m > 0 { parts.append("\(m) \(m == 1 ? "meal" : "meals")") }
        if w > 0 { parts.append("\(w) \(w == 1 ? "walk" : "walks")") }
        if p > 0 { parts.append("\(p) \(p == 1 ? "play" : "plays")") }
        return parts.isEmpty ? "None set" : parts.joined(separator: " · ")
    }

    private var compactDetailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Profile details").font(AppTheme.sectionTitleFont)

            VStack(spacing: 0) {
                compactRow(title: "Dog Name",         value: profileStore.profile.name)
                Divider()
                compactRow(title: "Breed",            value: profileStore.profile.breed)
                Divider()
                compactRow(title: "Food kcal / 100g", value: profileStore.profile.foodCaloriesPer100g)
                Divider()
                compactRow(
                    title: "Temp thresholds",
                    value: String(format: "⚠️ %.0f° / 🔴 %.0f°",
                                  profileStore.profile.tempWarnHigh,
                                  profileStore.profile.tempCriticalHigh)
                )
                Divider()
                compactRow(title: "Routine items", value: routineItemsSummary)
            }
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    // MARK: - Editable details

    private var editableDetailsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Edit profile").font(AppTheme.sectionTitleFont)

            inputField(title: "Dog Name", text: $profileStore.profile.name, placeholder: "e.g. Charlie")

            // Breed picker
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Breed").font(AppTheme.fieldLabelFont)
                    if isMixedBreedSelection {
                        Text("Mixed").font(.system(size: 12, weight: .semibold)).foregroundStyle(.orange)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.orange.opacity(0.12)).clipShape(Capsule())
                    }
                }
                TextField("Search breed or mixed breed", text: $breedSearchText)
                    .textInputAutocapitalization(.words).autocorrectionDisabled()
                    .padding(.horizontal, 14).frame(height: 50)
                    .background(AppTheme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous))
                Menu {
                    if !DogDataOptions.mixedBreedOptions.isEmpty {
                        Section("Mixed Breed Options") {
                            ForEach(DogDataOptions.mixedBreedOptions, id: \.self) { breed in
                                Button(breed) { profileStore.profile.breed = breed; breedSearchText = "" }
                            }
                        }
                    }
                    Section("All Breeds") {
                        ForEach(filteredBreeds.filter { !DogDataOptions.mixedBreedOptions.contains($0) }, id: \.self) { breed in
                            Button(breed) { profileStore.profile.breed = breed; breedSearchText = "" }
                        }
                    }
                } label: {
                    menuRow(
                        text: profileStore.profile.breed.isEmpty ? "Select breed" : profileStore.profile.breed,
                        isPlaceholder: profileStore.profile.breed.isEmpty
                    )
                }
            }

            menuPicker(title: "Sex",          selection: $profileStore.profile.sex,       options: DogDataOptions.sexOptions,   placeholder: "Select sex")
            menuPicker(title: "Age (Months)", selection: $profileStore.profile.ageMonths, options: DogDataOptions.ageMonths,    placeholder: "Select age")
            menuPicker(title: "Weight (kg)",  selection: $profileStore.profile.weightKg,  options: DogDataOptions.weightOptions, placeholder: "Select weight")

            inputField(title: "Food Name",        text: $profileStore.profile.foodName,            placeholder: "e.g. Royal Canin Puppy")
            inputField(title: "Food kcal / 100g", text: $profileStore.profile.foodCaloriesPer100g, placeholder: "e.g. 380")

            // Temperature thresholds
            temperatureThresholdsSection

            // Walk reminders are now managed in the Routine tab
            routineRedirectHint

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text("Change Photo")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.accentBrown)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(AppTheme.accentBrown.opacity(0.10))
                .clipShape(Capsule())
            }
            .padding(.top, 2)
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    // MARK: - Temperature thresholds section

    private var temperatureThresholdsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "thermometer.medium")
                    .foregroundStyle(.orange)
                    .font(.system(size: 14, weight: .semibold))
                Text("Temperature Alert Thresholds")
                    .font(AppTheme.sectionTitleFont)
            }

            Text("Adjust when alerts fire. Defaults: warn >28°C, critical >32°C, warn <12°C, critical <8°C.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                thresholdRow(
                    label: "Warn above",
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .orange,
                    value: $profileStore.profile.tempWarnHigh,
                    range: 20...40
                )
                thresholdRow(
                    label: "Critical above",
                    icon: "xmark.octagon.fill",
                    iconColor: .red,
                    value: $profileStore.profile.tempCriticalHigh,
                    range: 25...45
                )
                thresholdRow(
                    label: "Warn below",
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .blue,
                    value: $profileStore.profile.tempWarnLow,
                    range: 0...20
                )
                thresholdRow(
                    label: "Critical below",
                    icon: "xmark.octagon.fill",
                    iconColor: .cyan,
                    value: $profileStore.profile.tempCriticalLow,
                    range: 0...15
                )
            }
        }
        .padding(14)
        .background(AppTheme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous))
    }

    private func thresholdRow(
        label: String, icon: String, iconColor: Color,
        value: Binding<Double>, range: ClosedRange<Double>
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 18)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 0) {
                Button {
                    let newValue = max(range.lowerBound, value.wrappedValue - 1)
                    value.wrappedValue = newValue
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(value.wrappedValue > range.lowerBound ? AppTheme.accentBrown : .secondary.opacity(0.35))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .disabled(value.wrappedValue <= range.lowerBound)

                Text(String(format: "%.0f°", value.wrappedValue))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(minWidth: 44)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())

                Button {
                    let newValue = min(range.upperBound, value.wrappedValue + 1)
                    value.wrappedValue = newValue
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(value.wrappedValue < range.upperBound ? AppTheme.accentBrown : .secondary.opacity(0.35))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .disabled(value.wrappedValue >= range.upperBound)
            }
            .background(Color(.systemBackground).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Routine redirect hint

    /// Replaces the legacy walk-times editor. Walks are now managed as ScheduleItems
    /// in the Routine tab, so this card simply redirects the user there.
    private var routineRedirectHint: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.10))
                    .frame(width: 40, height: 40)
                Image(systemName: "figure.walk")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Walk Reminders")
                    .font(AppTheme.fieldLabelFont)
                Text("Managed in the Routine tab")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.right.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppTheme.accentBrown.opacity(0.45))
        }
        .padding(14)
        .background(AppTheme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous))
    }

    // MARK: - Data card (delete account)

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data").font(AppTheme.sectionTitleFont)

            Button {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.10))
                            .frame(width: 36, height: 36)
                        Image(systemName: "trash.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                    Text("Delete All Data")
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(.red)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, AppTheme.innerTilePadding)
                .padding(.vertical, 13)
                .background(AppTheme.warmTile)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
            }
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
        .confirmationDialog(
            "Delete All Data?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Data", role: .destructive) {
                profileStore.deleteAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will erase your dog profile, all settings, and remove push notification access. This cannot be undone.")
        }
    }

    // MARK: - About card

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About").font(AppTheme.sectionTitleFont)

            VStack(spacing: 0) {
                aboutLinkRow(
                    icon: "globe",
                    iconColor: AppTheme.accentBrown,
                    title: "PuppyCare Website",
                    subtitle: "shaharkoza.github.io/PuppyCare",
                    url: "https://shaharkoza.github.io/PuppyCare/"
                )
                Divider().padding(.leading, 58)
                aboutLinkRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    iconColor: .primary,
                    title: "Source Code",
                    subtitle: "github.com/ShaharKoza/PuppyCare",
                    url: "https://github.com/ShaharKoza/PuppyCare"
                )
                Divider().padding(.leading, 58)
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemFill))
                            .frame(width: 36, height: 36)
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text("Version")
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    Text("1.0.0")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, AppTheme.innerTilePadding)
                .padding(.vertical, 13)
            }
            .background(AppTheme.warmTile)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
        }
        .padding(AppTheme.cardPadding)
        .cardStyle()
    }

    private func aboutLinkRow(icon: String, iconColor: Color, title: String, subtitle: String, url: String) -> some View {
        Group {
            if let destination = URL(string: url) {
                Link(destination: destination) {
                    aboutRowContent(icon: icon, iconColor: iconColor, title: title, subtitle: subtitle)
                }
            }
        }
    }

    private func aboutRowContent(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, AppTheme.innerTilePadding)
        .padding(.vertical, 13)
    }

    // MARK: - Tile & row builders

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(AppTheme.tileLabelFont).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 8)
            Text(value).font(AppTheme.tileValueFont).lineLimit(2).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: AppTheme.compactTileHeight, alignment: .topLeading)
        .padding(AppTheme.innerTilePadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                .fill(AppTheme.warmTile)
        )
    }

    private func compactRow(title: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary)
            Spacer(minLength: 8)
            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not set" : value)
                .font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing).lineLimit(2)
        }
        .padding(.vertical, 13)
    }

    // MARK: - Form field helpers

    private func inputField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(AppTheme.fieldLabelFont)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.words).autocorrectionDisabled()
                .padding(.horizontal, 14).frame(height: 50)
                .background(AppTheme.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous))
        }
    }

    private func menuPicker(title: String, selection: Binding<String>, options: [String], placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(AppTheme.fieldLabelFont)
            Menu {
                ForEach(options, id: \.self) { item in
                    Button(item) { selection.wrappedValue = item }
                }
            } label: {
                menuRow(
                    text: selection.wrappedValue.isEmpty ? placeholder : selection.wrappedValue,
                    isPlaceholder: selection.wrappedValue.isEmpty
                )
            }
        }
    }

    private func menuRow(text: String, isPlaceholder: Bool) -> some View {
        HStack {
            Text(text).foregroundStyle(isPlaceholder ? .secondary : .primary).lineLimit(1)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.accentBrown.opacity(0.70))
        }
        .padding(.horizontal, 14).frame(height: 50)
        .background(AppTheme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous))
    }

    // MARK: - Photo loading

    private func loadSelectedPhoto() async {
        guard
            let selectedPhotoItem,
            let data  = try? await selectedPhotoItem.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else { return }

        if !profileStore.profile.profileImageFilename.isEmpty {
            ImageStorageManager.shared.deleteImage(filename: profileStore.profile.profileImageFilename)
        }
        if let filename = ImageStorageManager.shared.saveImage(image) {
            profileStore.profile.profileImageFilename = filename
        }
    }
}
