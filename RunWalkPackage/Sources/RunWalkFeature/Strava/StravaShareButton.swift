import SwiftUI
import RunWalkShared

/// Button to share a workout to Strava
public struct StravaShareButton: View {
    @Environment(StravaManager.self) private var stravaManager
    @Environment(\.modelContext) private var modelContext

    let record: WorkoutRecord

    @State private var showingResult = false
    @State private var resultMessage = ""
    @State private var resultIsError = false

    public init(record: WorkoutRecord) {
        self.record = record
    }

    public var body: some View {
        Group {
            if record.isSharedToStrava {
                sharedView
            } else if stravaManager.isConnected {
                shareButton
            } else {
                notConnectedView
            }
        }
        .alert(resultIsError ? "Upload Failed" : "Shared to Strava!", isPresented: $showingResult) {
            Button("OK") {
                showingResult = false
            }
            if !resultIsError, let url = record.stravaActivityURL {
                Link("View on Strava", destination: url)
            }
        } message: {
            Text(resultMessage)
        }
    }

    @ViewBuilder
    private var sharedView: some View {
        if let url = record.stravaActivityURL {
            Link(destination: url) {
                Label("View on Strava", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        } else {
            Label("Shared to Strava", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        Button {
            Task {
                await shareToStrava()
            }
        } label: {
            HStack {
                switch stravaManager.uploadStatus {
                case .idle:
                    Label("Share to Strava", systemImage: "square.and.arrow.up")
                        .foregroundStyle(stravaOrange)
                case .uploading:
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Uploading...")
                case .processing:
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing...")
                case .success:
                    Label("Shared!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .failed:
                    Label("Failed - Tap to retry", systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                }
            }
        }
        .disabled(!canShare)
    }

    @ViewBuilder
    private var notConnectedView: some View {
        HStack {
            Image(systemName: "link.badge.plus")
                .foregroundStyle(.secondary)
            Text("Connect Strava in Settings to share")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var canShare: Bool {
        guard record.hasRoute else { return false }

        switch stravaManager.uploadStatus {
        case .idle, .failed:
            return true
        case .uploading, .processing, .success:
            return false
        }
    }

    private var stravaOrange: Color {
        Color(red: 252/255, green: 76/255, blue: 2/255)
    }

    private func shareToStrava() async {
        do {
            let activityId = try await stravaManager.uploadWorkout(record)

            // Update the record with the Strava activity ID
            record.stravaActivityId = activityId
            try? modelContext.save()

            resultMessage = "Your workout has been shared to Strava!"
            resultIsError = false
            showingResult = true

            // Reset status after a delay
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            stravaManager.resetUploadStatus()
        } catch let error as StravaError {
            resultMessage = error.errorDescription ?? "Unknown error"
            resultIsError = true
            showingResult = true
        } catch {
            resultMessage = error.localizedDescription
            resultIsError = true
            showingResult = true
        }
    }
}

/// Compact version of the share button for list views
public struct StravaShareButtonCompact: View {
    @Environment(StravaManager.self) private var stravaManager

    let record: WorkoutRecord
    let onShare: () async -> Void

    public init(record: WorkoutRecord, onShare: @escaping () async -> Void) {
        self.record = record
        self.onShare = onShare
    }

    public var body: some View {
        if record.isSharedToStrava {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else if stravaManager.isConnected && record.hasRoute {
            Button {
                Task {
                    await onShare()
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Color(red: 252/255, green: 76/255, blue: 2/255))
            }
        }
    }
}

#Preview {
    let record = WorkoutRecord(
        startDate: Date(),
        endDate: Date().addingTimeInterval(1800),
        duration: 1800,
        runIntervals: 10,
        walkIntervals: 9,
        runIntervalDuration: 60,
        walkIntervalDuration: 60,
        caloriesBurned: 250,
        savedToHealthKit: true,
        routeData: nil,
        totalDistance: 3500,
        gpsTrackingEnabled: true
    )

    return Form {
        Section("Strava") {
            StravaShareButton(record: record)
        }
    }
    .environment(StravaManager())
}
