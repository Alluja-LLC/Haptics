import Foundation
import CoreHaptics

public typealias EngineResetHandler = (CHHapticEngine?) -> Void
public typealias EngineStopHandler = (CHHapticEngine?, CHHapticEngine.StoppedReason) -> Void
public typealias PlayersFinishedHandler = (CHHapticEngine?, Error?) -> CHHapticEngine.FinishedAction

public final class Haptics {

    public enum HapticsError: LocalizedError {
        case engineNil
        case emptyPattern
    }

    public final class GeneratedHapticPattern {
        fileprivate init(pattern: CHHapticPattern, generatePlayer: Bool) throws {
            self.pattern = pattern
            if generatePlayer {
                try createPlayer()
            }
        }

        private let pattern: CHHapticPattern
        private var player: CHHapticPatternPlayer!

        var duration: TimeInterval {
            pattern.duration
        }

        public func play() throws {
            guard let engine = Haptics.shared.engine else { throw HapticsError.engineNil }
            if player == nil {
                try createPlayer()
            }
            try engine.start()
            try player.start(atTime: 0)
        }

        private func createPlayer() throws {
            guard let engine = Haptics.shared.engine else { throw HapticsError.engineNil }
            player = try engine.makePlayer(with: pattern)
        }
    }

    public static private(set) var shared: Haptics!

    private let engine: CHHapticEngine?
    public let deviceSupportsHaptics: Bool

    private init(withEngineResetHandler engineReset: @escaping EngineResetHandler, withAutoShutdown autoShutdown: Bool, withStopHandler stopHandler: @escaping EngineStopHandler, withPlayersFinishedHandler playersFinished: @escaping PlayersFinishedHandler) throws {
        deviceSupportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if deviceSupportsHaptics {
            engine = try CHHapticEngine()

            try completeEngineSetup(withEngineResetHandler: engineReset, withAutoShutdown: autoShutdown, withStopHandler: stopHandler, withPlayersFinishedHandler: playersFinished)
        } else {
            engine = nil
        }
    }
    
    public static func initialize(withEngineResetHandler engineReset: @escaping EngineResetHandler = { try? $0?.start() }, withAutoShutdown autoShutdown: Bool = false, withStopHandler stopHandler: @escaping EngineStopHandler = { _,_  in }, withPlayersFinishedHandler playersFinished: @escaping PlayersFinishedHandler = { $1 != nil ? .stopEngine : .leaveEngineRunning }) throws {
        shared = try .init(withEngineResetHandler: engineReset, withAutoShutdown: autoShutdown, withStopHandler: stopHandler, withPlayersFinishedHandler: playersFinished)
    }

    deinit {
        engine?.stop(completionHandler: nil)
    }

    func restartEngine() throws {
        try engine?.start()
    }

    public enum HapticPatternSharpness {
        case dull
        case sharp
        case custom(Float)
        
        var value: Float {
            switch self {
            case .dull:
                return 0
            case .sharp:
                return 1
            case .custom(let float):
                return float
            }
        }
    }
    
    public enum HapticPatternStrength {
        case hard
        case soft
        case custom(Float)
        
        var value: Float {
            switch self {
            case .hard:
                return 1
            case .soft:
                return 0.6
            case .custom(let float):
                return float
            }
        }
    }

    public enum HapticPatternComponent {
        case delay(TimeInterval)
        case impact(HapticPatternStrength, HapticPatternSharpness)
    }

    /// Generates a haptic pattern from the given components
    /// - `components`: The components to create the haptic pattern from
    /// - `generatePlayer`: Whether to immediately generate a haptic player, may be disabled if the haptic won't be used immediately as there is a performance penalty to creating one
    public static func generateHaptic(fromComponents components: [HapticPatternComponent],
                               generatePlayer: Bool = true) throws -> GeneratedHapticPattern {
        if components.isEmpty {
            throw HapticsError.emptyPattern
        }

        var hapticArray: [CHHapticEvent] = []

        for (index, component) in components.enumerated() {
            let time = Double(index) / 10.0

            switch component {
            case .delay(let delay):
                let params = [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0)]
                hapticArray.append(CHHapticEvent(eventType: .hapticTransient, parameters: params,
                                                 relativeTime: time, duration: delay))
            case .impact(let strength, let sharpness):
                let params = [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: strength.value),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness.value)
                ]
                hapticArray.append(CHHapticEvent(eventType: .hapticTransient, parameters: params, relativeTime: time))
            }
        }

        return try GeneratedHapticPattern(pattern: try CHHapticPattern(events: hapticArray, parameters: []),
                                          generatePlayer: generatePlayer)
    }

    private func completeEngineSetup(withEngineResetHandler engineReset: @escaping EngineResetHandler, withAutoShutdown autoShutdown: Bool, withStopHandler stopHandler: @escaping EngineStopHandler, withPlayersFinishedHandler playersFinished: @escaping PlayersFinishedHandler) throws { // swiftlint:disable:this cyclomatic_complexity
        engine!.resetHandler = {
            engineReset(self.engine)
        }

        engine!.isAutoShutdownEnabled = autoShutdown

        engine!.stoppedHandler = { reason in
            stopHandler(self.engine, reason)
        }

        engine!.notifyWhenPlayersFinished { error in
            playersFinished(self.engine, error)
        }

        // Try to prestart engine
        try engine!.start()
    }
}

public struct DefaultHapticPatterns {
    private init() {}

    static let click = try? Haptics.generateHaptic(fromComponents: [.impact(.soft, .sharp)], generatePlayer: true)
    static let doubleClick = try? Haptics.generateHaptic(fromComponents: [.impact(.soft, .sharp), .impact(.hard, .sharp)], generatePlayer: true)
    static let destructiveClick = try? Haptics.generateHaptic(fromComponents: [.impact(.soft, .sharp), .impact(.hard, .dull)], generatePlayer: true)
    static let success = try? Haptics.generateHaptic(fromComponents: [.delay(0.2), .impact(.hard, .sharp), .impact(.hard, .sharp), .impact(.hard, .sharp)], generatePlayer: true)
    static let fail = try? Haptics.generateHaptic(fromComponents: [.delay(0.2), .impact(.hard, .sharp), .impact(.hard, .sharp), .impact(.hard, .dull)], generatePlayer: true)
}
