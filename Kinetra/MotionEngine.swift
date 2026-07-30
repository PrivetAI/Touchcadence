import Foundation
import CoreGraphics

/// Pure, deterministic trajectory math. No UIKit / SwiftUI so it can be exercised headlessly.
struct MotionEngine {

    /// Parameters loaded from the bundled `movements.json`.
    struct MovementParameters: Codable {
        var movement: String
        /// Base cycles per second at speed 1.0.
        var frequency: Double
        /// Fraction of the field the path spans, 0...1.
        var amplitude: Double
        /// Extra phase offset in turns.
        var phase: Double
    }

    private let params: [MovementType: MovementParameters]

    init(parameters: [MovementParameters]) {
        var map: [MovementType: MovementParameters] = [:]
        for p in parameters {
            if let m = MovementType(rawValue: p.movement) { map[m] = p }
        }
        self.params = map
    }

    /// Fallback set used when the bundle resource is missing.
    static let fallback = MotionEngine(parameters: MovementType.allCases.map {
        MovementParameters(movement: $0.rawValue, frequency: 0.32, amplitude: 0.80, phase: 0)
    })

    func parameters(for movement: MovementType) -> MovementParameters {
        params[movement] ?? MovementParameters(movement: movement.rawValue, frequency: 0.32, amplitude: 0.80, phase: 0)
    }

    /// Normalized position in the unit square for a movement type.
    /// - Parameters:
    ///   - t: seconds since the target spawned
    ///   - speed: combined difficulty * settings speed factor
    ///   - seed: per-target seed so consecutive targets differ
    func normalizedPosition(movement: MovementType, t: Double, speed: Double, seed: Int) -> CGPoint {
        let p = parameters(for: movement)
        let amp = max(0.1, min(1.0, p.amplitude))
        let half = amp / 2
        let freq = max(0.02, p.frequency) * max(0.05, speed)
        let phase = p.phase * 2 * Double.pi + Double(seed % 360) * Double.pi / 180
        let u = t * freq                     // cycles completed
        let theta = u * 2 * Double.pi + phase

        // Seeded pseudo-random helpers (deterministic for a given seed).
        func rnd(_ index: Int) -> Double {
            var x = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ index &* 1442695040888963407))
            x ^= x >> 33; x = x &* 0xff51afd7ed558ccd
            x ^= x >> 33; x = x &* 0xc4ceb9fe1a85ec53
            x ^= x >> 33
            return Double(x % 100_000) / 100_000.0
        }

        switch movement {
        case .linear:
            // Constant-speed diagonal sweep, ping-ponged.
            let tri = MotionEngine.triangle(u)
            let tri2 = MotionEngine.triangle(u * 0.5 + 0.25)
            return CGPoint(x: 0.5 + (tri - 0.5) * amp, y: 0.5 + (tri2 - 0.5) * amp)

        case .circle:
            return CGPoint(x: 0.5 + cos(theta) * half, y: 0.5 + sin(theta) * half)

        case .sine:
            let tri = MotionEngine.triangle(u * 0.55)
            return CGPoint(x: 0.5 + (tri - 0.5) * amp,
                           y: 0.5 + sin(theta * 2.2) * half * 0.85)

        case .zigzag:
            let tri = MotionEngine.triangle(u * 0.55)
            let saw = MotionEngine.triangle(u * 2.4)
            return CGPoint(x: 0.5 + (tri - 0.5) * amp, y: 0.5 + (saw - 0.5) * amp)

        case .random:
            // Smoothly interpolated seeded waypoints.
            let step = u * 1.6
            let i = Int(floor(step))
            let f = step - floor(step)
            let e = f * f * (3 - 2 * f)
            let x0 = rnd(i * 2), y0 = rnd(i * 2 + 1)
            let x1 = rnd((i + 1) * 2), y1 = rnd((i + 1) * 2 + 1)
            let x = x0 + (x1 - x0) * e
            let y = y0 + (y1 - y0) * e
            return CGPoint(x: 0.5 + (x - 0.5) * amp, y: 0.5 + (y - 0.5) * amp)

        case .accelerate:
            // Same ping-pong path, but eased so it starts slow and ends fast.
            let raw = MotionEngine.triangle(u * 0.6)
            let eased = raw * raw
            let ty = MotionEngine.triangle(u * 0.6 + 0.33)
            return CGPoint(x: 0.5 + (eased - 0.5) * amp, y: 0.5 + (ty * ty - 0.5) * amp)

        case .decelerate:
            let raw = MotionEngine.triangle(u * 0.6)
            let eased = sqrt(raw)
            let ty = MotionEngine.triangle(u * 0.6 + 0.33)
            return CGPoint(x: 0.5 + (eased - 0.5) * amp, y: 0.5 + (sqrt(ty) - 0.5) * amp)

        case .dash:
            // Bursts: move fast for 40% of a beat, hold for 60%.
            let beat = u * 1.8
            let i = floor(beat)
            let f = beat - i
            let travel = min(1.0, f / 0.4)
            let sx = rnd(Int(i) * 2), sy = rnd(Int(i) * 2 + 1)
            let ex = rnd((Int(i) + 1) * 2), ey = rnd((Int(i) + 1) * 2 + 1)
            let x = sx + (ex - sx) * travel
            let y = sy + (ey - sy) * travel
            return CGPoint(x: 0.5 + (x - 0.5) * amp, y: 0.5 + (y - 0.5) * amp)

        case .pendulum:
            // Swings along an arc hanging from the top of the field.
            let swing = sin(theta) * (Double.pi / 3)
            let radius = half * 1.15
            return CGPoint(x: 0.5 + sin(swing) * radius,
                           y: 0.5 - half * 0.85 + cos(swing) * radius)

        case .spiral:
            let cyc = u.truncatingRemainder(dividingBy: 1.0)
            let r = half * (0.15 + 0.85 * cyc)
            let a = theta * 3.0
            return CGPoint(x: 0.5 + cos(a) * r, y: 0.5 + sin(a) * r)

        case .ellipse:
            return CGPoint(x: 0.5 + cos(theta) * half * 1.25,
                           y: 0.5 + sin(theta) * half * 0.45)

        case .eight:
            return CGPoint(x: 0.5 + sin(theta) * half,
                           y: 0.5 + sin(theta * 2) * half * 0.6)

        case .teleport:
            // Holds still, then jumps on a fixed beat.
            let beat = Int(floor(u * 2.2))
            return CGPoint(x: 0.5 + (rnd(beat * 2) - 0.5) * amp,
                           y: 0.5 + (rnd(beat * 2 + 1) - 0.5) * amp)

        case .reverse:
            // Orbit that flips direction every 1.5 turns.
            let block = floor(u / 0.75)
            let sign: Double = block.truncatingRemainder(dividingBy: 2) == 0 ? 1 : -1
            let local = (u - block * 0.75) * 2 * Double.pi
            let base = block * 0.75 * 2 * Double.pi
            let a = base + sign * local + phase
            return CGPoint(x: 0.5 + cos(a) * half, y: 0.5 + sin(a) * half)

        case .combined:
            // Chains circle -> zigzag -> eight -> teleport, one per beat.
            let leg = Int(floor(u / 0.9)) % 4
            let inner = t - Double(Int(floor(u / 0.9))) * 0.9 / max(0.02, freq)
            let chain: [MovementType] = [.circle, .zigzag, .eight, .teleport]
            return normalizedPosition(movement: chain[leg], t: inner, speed: speed, seed: seed &+ leg)
        }
    }

    /// Position in field points, inset so the whole target stays inside the field.
    /// `field` MUST be the size handed down from the parent geometry, never a Canvas closure size.
    func position(movement: MovementType, t: Double, speed: Double, seed: Int,
                  field: CGSize, radius: CGFloat) -> CGPoint {
        let n = normalizedPosition(movement: movement, t: t, speed: speed, seed: seed)
        let insetW = max(radius, min(field.width / 2 - 1, radius))
        let insetH = max(radius, min(field.height / 2 - 1, radius))
        let usableW = max(1, field.width - insetW * 2)
        let usableH = max(1, field.height - insetH * 2)
        let cx = insetW + CGFloat(min(1, max(0, n.x))) * usableW
        let cy = insetH + CGFloat(min(1, max(0, n.y))) * usableH
        return CGPoint(x: cx, y: cy)
    }

    /// 0...1 triangle wave with period 1.
    static func triangle(_ x: Double) -> Double {
        let f = x - floor(x)
        return f < 0.5 ? f * 2 : (1 - f) * 2
    }

    /// Samples a normalized path for headless comparison.
    func samplePath(movement: MovementType, samples: Int = 240, span: Double = 8.0,
                    speed: Double = 1.0, seed: Int = 7) -> [CGPoint] {
        (0..<samples).map { i in
            normalizedPosition(movement: movement, t: span * Double(i) / Double(samples - 1),
                               speed: speed, seed: seed)
        }
    }
}
