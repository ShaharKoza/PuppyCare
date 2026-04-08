import SwiftUI

// MARK: - Color extension for ScheduleItemType (view layer only)

extension ScheduleItemType {
    var tint: Color {
        switch self {
        case .meal: return AppTheme.accentBrown
        case .walk: return .blue
        case .play: return .orange
        }
    }
}

// MARK: - Daily Routine View

struct DailyRoutineView: View {
    @EnvironmentObject var profileStore: ProfileStore

    @State private var showEditor = false
    @State private var itemToEdit: ScheduleItem? = nil
    @State private var deleteTarget: ScheduleItem? = nil

    // MARK: - Derived data

    private var sortedItems: [ScheduleItem] {
        profileStore.profile.scheduleItems.sorted { $0.time < $1.time }
    }

    private var nextItemID: UUID? {
        let cal = Calendar.current
        let now = Date()
        let nowMins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)

        return sortedItems.first { item in
            let parts = item.time.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return false }
            return parts[0] * 60 + parts[1] >= nowMins
        }?.id
    }

    private var mealCount: Int { profileStore.profile.mealItems.count }
    private var walkCount: Int { profileStore.profile.walkItems.count }
    private var playCount: Int { profileStore.profile.playItems.count }

    private var dogName: String {
        let n = profileStore.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "your dog" : n.capitalized
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                headerSection
                summaryRow
                aiInsightCard

                if sortedItems.isEmpty {
                    emptyState
                } else {
                    routineList
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, AppTheme.screenTopSpacing)
            .padding(.bottom, 24)
        }
        // safeAreaInset reserves exactly the button's height above the tab bar's
        // safe area — no magic numbers, no overlap on any device.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            addButton
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Delete \"\(deleteTarget?.label ?? "")\"?",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let item = deleteTarget {
                    withAnimation(.easeInOut(duration: 0.2)) { deleteItem(item) }
                }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("This item will be removed from the daily routine.")
        }
        .sheet(isPresented: $showEditor) {
            ScheduleItemEditor(
                existingItem: itemToEdit,
                profile: profileStore.profile
            ) { saved in
                applyEdit(saved)
            }
            .onDisappear { itemToEdit = nil }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Routine")
                .font(AppTheme.titleFont)

            HStack(alignment: .firstTextBaseline) {
                Text("\(dogName)'s schedule for today")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(dayLabel())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Summary chips row

    private var summaryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                summaryChip(
                    icon: "fork.knife",
                    text: mealCount == 1 ? "1 meal" : "\(mealCount) meals",
                    tint: AppTheme.accentBrown,
                    dimmed: mealCount == 0
                )
                summaryChip(
                    icon: "figure.walk",
                    text: walkCount == 1 ? "1 walk" : "\(walkCount) walks",
                    tint: .blue,
                    dimmed: walkCount == 0
                )
                summaryChip(
                    icon: "figure.play",
                    text: playCount == 1 ? "1 play" : "\(playCount) plays",
                    tint: .orange,
                    dimmed: playCount == 0
                )

                let grams = profileStore.profile.totalDailyGrams
                if grams > 0 {
                    summaryChip(
                        icon: "scalemass.fill",
                        text: "\(grams) g",
                        tint: .green
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func summaryChip(icon: String, text: String, tint: Color, dimmed: Bool = false) -> some View {
        let effectiveTint: Color = dimmed ? .secondary : tint

        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(effectiveTint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(effectiveTint.opacity(dimmed ? 0.07 : 0.10))
        .clipShape(Capsule())
    }

    // MARK: - AI Insight

    private var aiInsightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accentBrown)

                Text("Smart Routine Insight")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Text(routineInsightText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var routineInsightText: String {
        if sortedItems.isEmpty {
            return "Start by adding meals, walks, and play sessions so \(dogName) has a calmer and more predictable daily rhythm."
        }

        if walkCount < 3 {
            return "\(dogName) currently has only \(walkCount) walk\(walkCount == 1 ? "" : "s") planned. Adding another walk may help with calmer behavior and better energy release."
        }

        if playCount == 0 {
            return "There is no play session in today's routine. Adding even 15–20 minutes of play can help \(dogName) stay more relaxed and engaged."
        }

        if mealCount <= 2 {
            return "\(dogName) has only \(mealCount) meal\(mealCount == 1 ? "" : "s") planned. A more balanced feeding routine may make the day feel more structured."
        }

        let mealsWithoutGrams = profileStore.profile.mealItems.filter { $0.grams == nil }.count
        if mealsWithoutGrams > 0 {
            return "\(mealsWithoutGrams) meal\(mealsWithoutGrams == 1 ? "" : "s") still have no gram amount. Adding portions will make the routine more precise and easier to follow."
        }

        return "\(dogName)'s routine looks balanced for today. Meals, walks, and play are all represented — nice job."
    }

    // MARK: - Routine list

    private var routineList: some View {
        VStack(spacing: 10) {
            ForEach(sortedItems) { item in
                routineRow(item, isNext: item.id == nextItemID)
            }
        }
    }

    // MARK: - Routine row

    private func routineRow(_ item: ScheduleItem, isNext: Bool) -> some View {
        HStack(spacing: 0) {
            // Left accent bar
            Rectangle()
                .fill(item.type.tint)
                .frame(width: 4)

            // Content area — tappable for edit. The Menu button sits outside this
            // Button so its tap never reaches the edit-sheet action.
            Button {
                itemToEdit = item
                showEditor = true
            } label: {
                HStack(spacing: 12) {
                    Text(item.time)
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(isNext ? item.type.tint : .primary)
                        .lineLimit(1)
                        .frame(width: 60, alignment: .leading)

                    Rectangle()
                        .fill(Color.primary.opacity(0.07))
                        .frame(width: 1, height: 34)

                    ZStack {
                        Circle()
                            .fill(item.type.tint.opacity(isNext ? 0.18 : 0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: item.type.systemIcon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(item.type.tint)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(formattedLabel(item.label))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Group {
                            if item.type == .meal, let g = item.grams {
                                Text("\(g) g · Meal")
                            } else if item.type == .play, let d = item.durationMinutes {
                                Text("\(d) min · Play")
                            } else {
                                Text(item.type.displayName)
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                    // Compress the label before the badge+menu group is affected
                    .layoutPriority(-1)

                    Spacer(minLength: 0)

                    if isNext {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(item.type.tint)
                                .frame(width: 6, height: 6)
                            Text("Next")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(item.type.tint)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .fixedSize()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(item.type.tint.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                .padding(.leading, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isNext ? item.type.tint.opacity(0.04) : AppTheme.cardFill)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Ellipsis menu — sits outside the content Button so its tap is
            // fully independent and never opens the edit sheet.
            // frame(maxHeight: .infinity) stretches this column to match the
            // row height so the background fills cleanly without a colour seam.
            Menu {
                Button {
                    itemToEdit = item
                    showEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    deleteTarget = item
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Circle())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .frame(maxHeight: .infinity)
            .background(isNext ? item.type.tint.opacity(0.04) : AppTheme.cardFill)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(
                    isNext ? item.type.tint.opacity(0.30) : AppTheme.softBorder,
                    lineWidth: isNext ? 1.5 : 1
                )
        )
        .shadow(color: AppTheme.softShadow, radius: 8, y: 3)
        .animation(.easeInOut(duration: 0.2), value: isNext)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentBrown.opacity(0.08))
                    .frame(width: 96, height: 96)
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(AppTheme.accentBrown)
            }

            VStack(spacing: 8) {
                Text("No routine set up yet")
                    .font(AppTheme.bodyTitleFont)
                Text("Add \(dogName)'s meals, walks, and play sessions to build a daily schedule that repeats every day.")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                itemToEdit = nil
                showEditor = true
            } label: {
                Label("Add first item", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 13)
                    .background(AppTheme.accentBrown)
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.accentBrown.opacity(0.25), radius: 10, y: 5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.vertical, 40)
    }

    // MARK: - Floating add button
    //
    // Rendered via .safeAreaInset(edge: .bottom) on the ScrollView.
    // This means SwiftUI automatically:
    //   • Pushes scroll content up so the last card is never hidden behind the button
    //   • Positions the button above the real safe area (tab bar + home indicator)
    //   • Works correctly on every device — no hardcoded bottom offsets needed

    private var addButton: some View {
        HStack {
            Spacer()
            Button {
                itemToEdit = nil
                showEditor = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                    Text("Add")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .frame(height: 52)
                .background(AppTheme.accentBrown)
                .clipShape(Capsule())
                .shadow(color: AppTheme.accentBrown.opacity(0.30), radius: 12, y: 6)
            }
        }
        .padding(.horizontal, AppTheme.horizontalPadding)
        .padding(.vertical, 12)
        .background(
            // Subtle gradient fade so the button doesn't abruptly cut off content
            LinearGradient(
                colors: [AppTheme.pageBackground.opacity(0), AppTheme.pageBackground],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.45)
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Helpers

    private func applyEdit(_ item: ScheduleItem) {
        if let idx = profileStore.profile.scheduleItems.firstIndex(where: { $0.id == item.id }) {
            profileStore.profile.scheduleItems[idx] = item
        } else {
            profileStore.profile.scheduleItems.append(item)
            profileStore.profile.scheduleItems.sort { $0.time < $1.time }
        }
    }

    private func deleteItem(_ item: ScheduleItem) {
        profileStore.profile.scheduleItems.removeAll { $0.id == item.id }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f
    }()

    private func dayLabel() -> String {
        Self.dayFormatter.string(from: Date())
    }

    private func formattedLabel(_ text: String) -> String {
        text
            .split(separator: " ")
            .map { word in
                guard let first = word.first else { return String(word) }
                return first.uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}

// MARK: - Schedule Item Editor Sheet

private struct ScheduleItemEditor: View {
    let existingItem: ScheduleItem?
    let profile: DogProfile
    let onSave: (ScheduleItem) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: ScheduleItemType
    @State private var selectedTime: Date
    @State private var label: String
    @State private var gramsString: String
    @State private var durationString: String
    @State private var labelWasEdited: Bool

    init(existingItem: ScheduleItem?, profile: DogProfile, onSave: @escaping (ScheduleItem) -> Void) {
        self.existingItem = existingItem
        self.profile = profile
        self.onSave = onSave

        if let item = existingItem {
            _selectedType = State(initialValue: item.type)
            _selectedTime = State(initialValue: Self.parseTime(item.time))
            _label = State(initialValue: item.label)
            _gramsString = State(initialValue: item.grams.map { "\($0)" } ?? "")
            _durationString = State(initialValue: item.durationMinutes.map { "\($0)" } ?? "")
            _labelWasEdited = State(initialValue: true)
        } else {
            let defaultTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
            _selectedType = State(initialValue: .meal)
            _selectedTime = State(initialValue: defaultTime)
            _label = State(initialValue: ScheduleItem.autoLabel(type: .meal, timeString: "08:00"))
            _gramsString = State(initialValue: "")
            _durationString = State(initialValue: "")
            _labelWasEdited = State(initialValue: false)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    typePickerSection
                    timePickerSection
                    labelSection
                    if selectedType == .meal {
                        gramsSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    if selectedType == .play {
                        durationSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 20)
                .padding(.bottom, 40)
                .animation(.spring(duration: 0.3), value: selectedType)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(existingItem == nil ? "Add to Routine" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.accentBrown)
                        .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var typePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Type")
            HStack(spacing: 10) {
                ForEach(ScheduleItemType.allCases, id: \.self) { type in
                    typeButton(type)
                }
            }
        }
    }

    private func typeButton(_ type: ScheduleItemType) -> some View {
        let isSelected = selectedType == type
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                selectedType = type
                if !labelWasEdited { updateAutoLabel() }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: type.systemIcon)
                    .font(.system(size: 15, weight: .semibold))
                Text(type.displayName)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : type.tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? type.tint : type.tint.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous)
                    .stroke(isSelected ? Color.clear : type.tint.opacity(0.20), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var timePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Time")
            DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .tint(AppTheme.accentBrown)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous)
                        .fill(AppTheme.inputBackground)
                )
                .onChange(of: selectedTime) { _, _ in
                    if !labelWasEdited { updateAutoLabel() }
                }
        }
    }

    private var labelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("Label")
                Spacer()
                if !labelWasEdited {
                    Text("Auto-filled")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }

            TextField("e.g. Morning Meal", text: $label)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(AppTheme.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous))
                .onChange(of: label) { _, _ in labelWasEdited = true }
        }
    }

    private var gramsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Amount (grams)")

            HStack(spacing: 0) {
                stepperButton(symbol: "minus", enabled: gramsValue > 0) {
                    gramsString = "\(max(0, gramsValue - 5))"
                }

                Text(gramsValue > 0 ? "\(gramsValue) g" : "—")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(gramsValue > 0 ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())

                stepperButton(symbol: "plus", enabled: gramsValue < 1000) {
                    gramsString = "\(min(1000, gramsValue + 5))"
                }
            }
            .frame(height: 50)
            .background(AppTheme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous))

            Text("Optional — leave at — to skip the gram count for this meal.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.tertiary)
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Duration (minutes)")

            HStack(spacing: 0) {
                stepperButton(symbol: "minus", enabled: durationValue > 0) {
                    durationString = "\(max(0, durationValue - 5))"
                }

                Text(durationValue > 0 ? "\(durationValue) min" : "—")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(durationValue > 0 ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())

                stepperButton(symbol: "plus", enabled: durationValue < 180) {
                    durationString = "\(min(180, durationValue + 5))"
                }
            }
            .frame(height: 50)
            .background(AppTheme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldRadius, style: .continuous))

            Text("Optional — leave at — to log the play session without a duration.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.tertiary)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private var gramsValue: Int { Int(gramsString) ?? 0 }
    private var durationValue: Int { Int(durationString) ?? 0 }

    private func save() {
        let timeStr = Self.formatTime(selectedTime)
        let finalGrams: Int? = (selectedType == .meal && gramsValue > 0) ? gramsValue : nil
        let finalDuration: Int? = (selectedType == .play && durationValue > 0) ? durationValue : nil

        let item = ScheduleItem(
            id: existingItem?.id ?? UUID(),
            type: selectedType,
            time: timeStr,
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            grams: finalGrams,
            durationMinutes: finalDuration
        )
        onSave(item)
        dismiss()
    }

    private func updateAutoLabel() {
        label = ScheduleItem.autoLabel(type: selectedType, timeString: Self.formatTime(selectedTime))
    }

    private func stepperButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.1)) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(enabled ? AppTheme.accentBrown : Color.secondary.opacity(0.35))
                .frame(width: 52, height: 50)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
    }

    private static func parseTime(_ string: String) -> Date {
        let parts = string.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else {
            return Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date()) ?? Date()
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    private static func formatTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }
}
