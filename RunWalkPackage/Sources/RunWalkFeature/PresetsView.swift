import SwiftUI
import SwiftData
import RunWalkShared

/// Callback type for when a preset is selected
public typealias PresetSelectionHandler = (WorkoutPreset) -> Void

/// A dedicated view for browsing and managing workout presets
public struct PresetsView: View {
    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: - SwiftData Queries

    @Query(sort: [SortDescriptor(\WorkoutPreset.categoryRaw), SortDescriptor(\WorkoutPreset.sortOrder)])
    private var allPresets: [WorkoutPreset]

    // MARK: - State

    @State private var showCreatePresetSheet = false
    @State private var selectedPreset: WorkoutPreset?
    @State private var showDeleteConfirmation = false
    @State private var presetToDelete: WorkoutPreset?

    // MARK: - Callback

    /// Called when a preset is selected to apply it
    private let onPresetSelected: PresetSelectionHandler?

    // MARK: - Initialization

    public init(onPresetSelected: PresetSelectionHandler? = nil) {
        self.onPresetSelected = onPresetSelected
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if allPresets.isEmpty {
                    emptyStateView
                } else {
                    presetListView
                }
            }
            .navigationTitle("Presets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreatePresetSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    }
                }
            }
            .sheet(isPresented: $showCreatePresetSheet) {
                CreatePresetSheet(
                    onCreate: { name, description, runSeconds, walkSeconds in
                        createPreset(name: name, description: description, runSeconds: runSeconds, walkSeconds: walkSeconds)
                    }
                )
            }
            .confirmationDialog(
                "Delete Preset",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let preset = presetToDelete {
                        deletePreset(preset)
                    }
                }
                Button("Cancel", role: .cancel) {
                    presetToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this preset? This action cannot be undone.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Presets Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create your first preset or wait for built-in presets to load.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showCreatePresetSheet = true
            } label: {
                Label("Create Preset", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.green, in: Capsule())
            }
            .padding(.top, 10)
        }
    }

    // MARK: - Preset List

    private var presetListView: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(PresetCategory.allCases, id: \.self) { category in
                    let categoryPresets = allPresets.filter { $0.category == category }
                    if !categoryPresets.isEmpty {
                        PresetCategorySection(
                            category: category,
                            presets: categoryPresets,
                            onSelect: { preset in
                                onPresetSelected?(preset)
                            },
                            onDelete: { preset in
                                presetToDelete = preset
                                showDeleteConfirmation = true
                            }
                        )
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func createPreset(name: String, description: String?, runSeconds: Int, walkSeconds: Int) {
        PresetManager.shared.createUserPreset(
            name: name,
            description: description,
            runSeconds: runSeconds,
            walkSeconds: walkSeconds,
            context: modelContext
        )
    }

    private func deletePreset(_ preset: WorkoutPreset) {
        _ = PresetManager.shared.deletePreset(preset, context: modelContext)
        presetToDelete = nil
    }
}

// MARK: - Preset Category Section

struct PresetCategorySection: View {
    let category: PresetCategory
    let presets: [WorkoutPreset]
    let onSelect: (WorkoutPreset) -> Void
    let onDelete: (WorkoutPreset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.subheadline.weight(.semibold))
                Text(category.rawValue)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(categoryColor)

            // Preset cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(presets, id: \.id) { preset in
                    PresetCard(
                        preset: preset,
                        color: categoryColor,
                        onSelect: { onSelect(preset) },
                        onDelete: preset.isBuiltIn ? nil : { onDelete(preset) }
                    )
                }
            }
        }
    }

    private var categoryColor: Color {
        switch category {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        case .custom: return .purple
        }
    }
}

// MARK: - Preset Card

struct PresetCard: View {
    let preset: WorkoutPreset
    let color: Color
    let onSelect: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Name
                Text(preset.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // Interval summary
                Text(preset.intervalSummary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                // Description (if available)
                if let description = preset.presetDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(color.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onSelect()
            } label: {
                Label("Apply Preset", systemImage: "play.fill")
            }

            if let onDelete = onDelete {
                Divider()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Create Preset Sheet

struct CreatePresetSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var runMinutes = 1
    @State private var runSeconds = 0
    @State private var walkMinutes = 1
    @State private var walkSeconds = 0

    let onCreate: (String, String?, Int, Int) -> Void

    private var totalRunSeconds: Int {
        runMinutes * 60 + runSeconds
    }

    private var totalWalkSeconds: Int {
        walkMinutes * 60 + walkSeconds
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        totalRunSeconds >= 10 &&
        totalWalkSeconds >= 10
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preset Info") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description)
                }

                Section("Run Interval") {
                    HStack {
                        Picker("Minutes", selection: $runMinutes) {
                            ForEach(0...30, id: \.self) { min in
                                Text("\(min) min").tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 120)

                        Picker("Seconds", selection: $runSeconds) {
                            ForEach([0, 15, 30, 45], id: \.self) { sec in
                                Text("\(sec) sec").tag(sec)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 120)
                    }
                    .frame(height: 120)

                    Text("Total: \(formatSeconds(totalRunSeconds))")
                        .foregroundStyle(.orange)
                        .font(.headline)
                }

                Section("Walk Interval") {
                    HStack {
                        Picker("Minutes", selection: $walkMinutes) {
                            ForEach(0...30, id: \.self) { min in
                                Text("\(min) min").tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 120)

                        Picker("Seconds", selection: $walkSeconds) {
                            ForEach([0, 15, 30, 45], id: \.self) { sec in
                                Text("\(sec) sec").tag(sec)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 120)
                    }
                    .frame(height: 120)

                    Text("Total: \(formatSeconds(totalWalkSeconds))")
                        .foregroundStyle(.green)
                        .font(.headline)
                }

                if !isValid {
                    Section {
                        Text("Name is required and intervals must be at least 10 seconds")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        let desc = description.trimmingCharacters(in: .whitespaces)
                        onCreate(
                            name.trimmingCharacters(in: .whitespaces),
                            desc.isEmpty ? nil : desc,
                            totalRunSeconds,
                            totalWalkSeconds
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func formatSeconds(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes == 0 {
            return "\(seconds)s"
        } else if seconds == 0 {
            return "\(minutes)m"
        } else {
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Preview

#Preview {
    PresetsView()
        .preferredColorScheme(.dark)
}
