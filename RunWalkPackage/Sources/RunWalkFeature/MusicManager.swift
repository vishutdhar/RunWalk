import AVFoundation
import Observation

/// Manages background music playback for run/walk phases
/// Supports crossfading between tracks and mixing with other apps' audio
@Observable
@MainActor
final class MusicManager {
    // MARK: - Properties

    /// Whether music is enabled
    var isMusicEnabled: Bool = false {
        didSet {
            if isMusicEnabled {
                configureForAppMusic()
            } else {
                stopMusic()
                configureForMixing()
            }
        }
    }

    /// Current volume (0.0 to 1.0)
    var volume: Float = 0.7 {
        didSet {
            currentPlayer?.volume = volume
        }
    }

    /// Whether music is currently playing
    private(set) var isPlaying: Bool = false

    // MARK: - Private Properties

    private var currentPlayer: AVAudioPlayer?
    private var nextPlayer: AVAudioPlayer?
    private var crossfadeTask: Task<Void, Never>?

    /// Track lists for each phase
    private var runTracks: [URL] = []
    private var walkTracks: [URL] = []

    /// Current track index for each phase
    private var currentRunIndex: Int = 0
    private var currentWalkIndex: Int = 0

    /// Crossfade duration in seconds
    private let crossfadeDuration: TimeInterval = 1.5

    // MARK: - Initialization

    init() {
        loadTrackLists()
        configureForMixing()
    }

    // MARK: - Track Loading

    /// Loads the track lists from the app bundle
    private func loadTrackLists() {
        // Load run tracks
        runTracks = loadTracks(prefix: "run_")

        // Load walk tracks
        walkTracks = loadTracks(prefix: "walk_")

        // Shuffle for variety
        runTracks.shuffle()
        walkTracks.shuffle()
    }

    /// Loads tracks with a given prefix from the bundle
    private func loadTracks(prefix: String) -> [URL] {
        guard let resourceURL = Bundle.main.resourceURL else { return [] }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: resourceURL,
                includingPropertiesForKeys: nil
            )

            return contents.filter { url in
                let filename = url.lastPathComponent.lowercased()
                return filename.hasPrefix(prefix) &&
                       (filename.hasSuffix(".mp3") || filename.hasSuffix(".m4a"))
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            print("Failed to load tracks: \(error)")
            return []
        }
    }

    // MARK: - Audio Session Configuration

    /// Configures audio session to mix with other apps (music off mode)
    private func configureForMixing() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session for mixing: \(error)")
        }
    }

    /// Configures audio session for app's own music playback
    private func configureForAppMusic() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session for app music: \(error)")
        }
    }

    // MARK: - Playback Control

    /// Starts playing music for the given phase
    func playMusic(for phase: TimerPhase) {
        guard isMusicEnabled else { return }

        let tracks = phase == .run ? runTracks : walkTracks
        guard !tracks.isEmpty else { return }

        let index = phase == .run ? currentRunIndex : currentWalkIndex
        let trackURL = tracks[index % tracks.count]

        // Increment index for next time
        if phase == .run {
            currentRunIndex = (currentRunIndex + 1) % runTracks.count
        } else {
            currentWalkIndex = (currentWalkIndex + 1) % walkTracks.count
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: trackURL)
            newPlayer.numberOfLoops = -1 // Loop indefinitely
            newPlayer.volume = 0 // Start silent for crossfade
            newPlayer.prepareToPlay()

            crossfadeTo(newPlayer: newPlayer)
        } catch {
            print("Failed to create audio player: \(error)")
        }
    }

    /// Crossfades from current track to new track
    private func crossfadeTo(newPlayer: AVAudioPlayer) {
        // Cancel any existing crossfade
        crossfadeTask?.cancel()

        nextPlayer = newPlayer
        nextPlayer?.play()

        // Start async crossfade
        crossfadeTask = Task { @MainActor in
            await performCrossfade()
        }
    }

    /// Performs the actual crossfade animation
    private func performCrossfade() async {
        let steps = 30
        let stepDuration = crossfadeDuration / Double(steps)

        for step in 1...steps {
            let progress = Float(step) / Float(steps)

            // Fade out current
            currentPlayer?.volume = volume * (1 - progress)

            // Fade in next
            nextPlayer?.volume = volume * progress

            // Wait for next step
            try? await Task.sleep(for: .seconds(stepDuration))
        }

        // Crossfade complete
        currentPlayer?.stop()
        currentPlayer = nextPlayer
        nextPlayer = nil
        isPlaying = true
    }

    /// Switches music for a new phase with crossfade
    func switchPhase(to phase: TimerPhase) {
        guard isMusicEnabled else { return }
        playMusic(for: phase)
    }

    /// Stops all music playback
    func stopMusic() {
        crossfadeTask?.cancel()
        crossfadeTask = nil

        currentPlayer?.stop()
        currentPlayer = nil

        nextPlayer?.stop()
        nextPlayer = nil

        isPlaying = false
    }

    /// Pauses music playback
    func pause() {
        currentPlayer?.pause()
        isPlaying = false
    }

    /// Resumes music playback
    func resume() {
        guard isMusicEnabled else { return }
        currentPlayer?.play()
        isPlaying = currentPlayer?.isPlaying ?? false
    }

    // MARK: - Track Information

    /// Returns true if tracks are available for music playback
    var hasTracksAvailable: Bool {
        !runTracks.isEmpty && !walkTracks.isEmpty
    }

    /// Number of run tracks loaded
    var runTrackCount: Int {
        runTracks.count
    }

    /// Number of walk tracks loaded
    var walkTrackCount: Int {
        walkTracks.count
    }
}
