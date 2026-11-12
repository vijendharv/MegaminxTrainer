import Combine
import Foundation
import SwiftUI

struct OLLCase: Codable, Identifiable {
    let id: Int
    let name: String
    let group: Int
    let setup: String
    var solution: String { Self.inverse(setup) }
    static func inverse(_ sequence: String) -> String {
        sequence.split(separator: " ").reversed().map { token in
            token.hasSuffix("'") ? String(token.dropLast()) : String(token) + "'"
        }.joined(separator: " ")
    }
}
struct Solve: Codable, Identifiable {
    var id = UUID()
    let caseID: Int
    let seconds: Double
    let date: Date
}
struct SavedState: Codable {
    var selected: Set<Int>
    var solves: [Solve]
    var appearances: [Int: Int]
    var weighted: Bool
}

@MainActor final class TrainerModel: ObservableObject {
    let cases: [OLLCase]
    @Published var selected: Set<Int> = []
    @Published var solves: [Solve] = []
    @Published var appearances: [Int: Int] = [:]
    @Published var weighted = true
    @Published var current: OLLCase?
    @Published var running = false
    @Published var elapsed = 0.0
    @Published var reveal = false
    @Published var recap = false
    @Published var complete = false
    @Published var practiced = 0
    @Published var total = 0
    @Published var storageError: String?
    private var queue: [OLLCase] = []
    private var start: TimeInterval?
    private let key = "megaminx.state.v1"
    private let defaults: UserDefaults
    var recapPosition: Int { total - queue.count }
    init(catalog: [OLLCase]? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let catalog { cases = catalog }
        else if let url = Bundle.main.url(forResource: "cases", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([OLLCase].self, from: data) {
            cases = decoded
        } else { cases = [] }
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode(SavedState.self, from: data) {
            selected = saved.selected.intersection(Set(cases.map(\.id)))
            solves = saved.solves; appearances = saved.appearances; weighted = saved.weighted
        } else { selected = Set(cases.prefix(2).map(\.id)) }
    }
    func save() {
        do {
            let state = SavedState(selected: selected, solves: solves, appearances: appearances, weighted: weighted)
            defaults.set(try JSONEncoder().encode(state), forKey: key)
        } catch { storageError = "Your progress could not be saved." }
    }
    func toggle(_ ids: Set<Int>) {
        if ids.isSubset(of: selected) { selected.subtract(ids) } else { selected.formUnion(ids) }
        save()
    }
    func begin(recap: Bool) {
        guard !selected.isEmpty else { return }
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
    func tapTimer() {
        guard let current else { return }
        if running {
            tick(); running = false; start = nil
            solves.insert(Solve(caseID: current.id, seconds: elapsed, date: Date()), at: 0)
            practiced += 1; save()
        } else if elapsed == 0 {
            reveal = false; start = ProcessInfo.processInfo.systemUptime; running = true
        }
    }
    func tick() {
        if let start { elapsed = ProcessInfo.processInfo.systemUptime - start }
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
