import Combine
import Foundation
import SwiftUI

enum TrainerKind: String, CaseIterable, Identifiable {
    case oll, pll
    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
    var catalogName: String { self == .oll ? "cases" : "pll-cases" }
    var diagramDirectory: String { self == .oll ? "Cases" : "PLLCases" }
    // Keep the original key so existing OLL selections and history are preserved.
    var storageKey: String { self == .oll ? "megaminx.state.v1" : "megaminx.pll.state.v1" }
    var detail: String { self == .oll ? "Orient the last layer" : "Permute the last layer" }
    var instructions: String {
        self == .oll
            ? "Choose cases to practice orienting the last-layer pieces."
            : "Choose cases to practice moving the oriented last-layer pieces into place."
    }
    func groupName(_ group: Int) -> String {
        let label = self == .pll ? String(UnicodeScalar(64 + group)!) : String(group)
        return "Group \(label)"
    }
}

struct TrainerCase: Codable, Identifiable {
    let id: Int
    let name: String
    let group: Int
    let setup: String
    var algorithms: [String] = []
    var groupDescription: String = ""
    var solution: String { Self.inverse(setup) }
    static func inverse(_ sequence: String) -> String {
        sequence.split(separator: " ").reversed().map { token in
            token.hasSuffix("'") ? String(token.dropLast()) : String(token) + "'"
        }.joined(separator: " ")
    }
}
enum AlgorithmNotation {
    /// For display only. Keep the original sequence intact for rendering and copying.
    static func leadingRotations(in sequence: String) -> String? {
        let rotations = sequence.split(whereSeparator: { $0.isWhitespace }).prefix { token in
            let move = token.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            return move.range(of: "^[xyz](2|3)?['′]?$", options: .regularExpression) != nil
        }.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "()")) }
        return rotations.isEmpty ? nil : rotations.joined(separator: " ")
    }
}

struct Solve: Codable, Identifiable, Sendable {
    var id = UUID()
    let caseID: Int
    let seconds: Double
    let date: Date
}
struct SavedState: Codable, Sendable {
    var selected: Set<Int>
    var solves: [Solve]
    var appearances: [Int: Int]
    var weighted: Bool
}

/// All reads and writes pass through one serial queue. This also makes a new
/// model wait for an earlier model's pending save before restoring its state.
private final class TrainerStateStore: @unchecked Sendable {
    private static let queue = DispatchQueue(label: "megaminx.persistence", qos: .utility)
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults, key: String) {
        self.defaults = defaults
        self.key = key
    }
    func load() -> Data? { Self.queue.sync { defaults.data(forKey: key) } }
    func save(_ state: SavedState) throws {
        try Self.queue.sync { try write(state) }
    }
    func saveInBackground(_ state: SavedState, completion: @escaping @Sendable (Bool) -> Void) {
        Self.queue.async { [self] in
            do { try write(state); completion(true) }
            catch { completion(false) }
        }
    }
    private func write(_ state: SavedState) throws {
        defaults.set(try JSONEncoder().encode(state), forKey: key)
    }
}

@MainActor final class TrainerModel: ObservableObject {
    let kind: TrainerKind
    let cases: [TrainerCase]
    @Published var selected: Set<Int> = []
    @Published var solves: [Solve] = []
    @Published var appearances: [Int: Int] = [:]
    @Published var weighted = true
    @Published var current: TrainerCase?
    @Published var running = false
    @Published var elapsed = 0.0
    @Published var reveal = false
    @Published var recap = false
    @Published var complete = false
    @Published var practiced = 0
    @Published var total = 0
    @Published var storageError: String?
    private var queue: [TrainerCase] = []
    private var start: TimeInterval?
    var timerStartedAt: TimeInterval? { start }
    private let store: TrainerStateStore
    var recapPosition: Int { total - queue.count }
    init(kind: TrainerKind = .oll, catalog: [TrainerCase]? = nil, defaults: UserDefaults = .standard) {
        self.kind = kind
        self.store = TrainerStateStore(defaults: defaults, key: kind.storageKey)
        if let catalog { cases = catalog }
        else if let url = Bundle.main.url(forResource: kind.catalogName, withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([TrainerCase].self, from: data) {
            cases = decoded
        } else { cases = [] }
        if let data = store.load(),
           let saved = try? JSONDecoder().decode(SavedState.self, from: data) {
            selected = saved.selected.intersection(Set(cases.map(\.id)))
            solves = saved.solves; appearances = saved.appearances; weighted = saved.weighted
        } else { selected = Set(cases.prefix(2).map(\.id)) }
    }
    private var snapshot: SavedState {
        SavedState(selected: selected, solves: solves, appearances: appearances, weighted: weighted)
    }
    func save() {
        do { try store.save(snapshot) }
        catch { storageError = "Your progress could not be saved." }
    }
    private func saveAfterSolve() {
        store.saveInBackground(snapshot) { [weak self] success in
            guard !success else { return }
            Task { @MainActor [weak self] in
                self?.storageError = "Your progress could not be saved."
            }
        }
    }
    func toggle(_ ids: Set<Int>) {
        if ids.isSubset(of: selected) { selected.subtract(ids) } else { selected.formUnion(ids) }
        save()
    }
    func begin(recap: Bool) {
        guard !selected.isEmpty else { return }
        cancelTiming()
        self.recap = recap; complete = false; practiced = 0
        queue = cases.filter { selected.contains($0.id) }.shuffled()
        total = queue.count
        next()
    }
    func next() {
        running = false; start = nil; elapsed = 0; reveal = false
        if recap {
            guard !queue.isEmpty else { complete = true; current = nil; return }
            current = queue.removeFirst()
        } else {
            let candidates = cases.filter { selected.contains($0.id) }
            guard !candidates.isEmpty else { current = nil; return }
            if weighted {
                let weights = candidates.map { 1.0 / Double(1 + (appearances[$0.id] ?? 0)) }
                var ticket = Double.random(in: 0..<weights.reduce(0, +))
                current = candidates.last
                for (item, weight) in zip(candidates, weights) {
                    ticket -= weight
                    if ticket < 0 { current = item; break }
                }
            } else { current = candidates.randomElement() }
        }
        if let current { appearances[current.id, default: 0] += 1 }
        save()
    }
    func tapTimer(at timestamp: TimeInterval? = nil) {
        guard let current else { return }
        // UITouch timestamps and systemUptime share the monotonic uptime clock.
        // Rendering cadence must never determine the recorded solve time.
        let now = timestamp ?? ProcessInfo.processInfo.systemUptime
        if running, let start {
            elapsed = max(0, now - start)
            running = false
            self.start = nil
            solves.insert(Solve(caseID: current.id, seconds: elapsed, date: Date()), at: 0)
            practiced += 1
            saveAfterSolve()
        } else if elapsed == 0 {
            reveal = false
            start = now
            running = true
        }
    }
    func cancelTiming() {
        if running { running = false; start = nil; elapsed = 0 }
    }
    var mean: Double? { solves.isEmpty ? nil : solves.map(\.seconds).reduce(0, +) / Double(solves.count) }
    var best: Double? { solves.map(\.seconds).min() }
    var ao5: Double? {
        guard solves.count >= 5 else { return nil }
        return solves.prefix(5).map(\.seconds).sorted().dropFirst().dropLast().reduce(0, +) / 3
    }
}
func timeString(_ seconds: Double?) -> String {
    guard let seconds else { return "—" }
    if seconds >= 60 { return String(format: "%d:%05.2f", Int(seconds) / 60, seconds.truncatingRemainder(dividingBy: 60)) }
    return String(format: "%.2f", seconds)
}
