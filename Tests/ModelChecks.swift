import Foundation

@main struct ModelChecks {
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let cases = try JSONDecoder().decode([TrainerCase].self, from: Data(contentsOf: root.appendingPathComponent("MegaminxTrainer/Resources/cases.json")))
        precondition(cases.count == 178 && Set(cases.map(\.id)).count == 178)
        precondition(cases.reduce(0) { $0 + $1.algorithms.count } == 302)
        precondition(cases.first!.algorithms.first == "(L R U R' U' R' F R F' L')")
        let fourB = cases.first { $0.name == "4B" }!
        precondition(fourB.algorithms == [
            "(R' U2' R U R' U' R U R' U R)",
            "y2' (R U2 R' U' R U R' U' R U' R')",
            "y' (BL R' U2' R U R' U R BL')"
        ])
        precondition(AlgorithmNotation.leadingRotations(in: fourB.algorithms[0]) == nil)
        precondition(AlgorithmNotation.leadingRotations(in: fourB.algorithms[1]) == "y2'")
        precondition(AlgorithmNotation.leadingRotations(in: fourB.algorithms[2]) == "y'")
        precondition(AlgorithmNotation.leadingRotations(in: "(y2') (R U R')") == "y2'")
        precondition(AlgorithmNotation.leadingRotations(in: "x' y2 (R U R')") == "x' y2")
        precondition(AlgorithmNotation.leadingRotations(in: "(R U R')x3") == nil)
        for item in cases {
            precondition(TrainerCase.inverse(item.solution) == item.setup)
            precondition(!item.groupDescription.isEmpty)
            precondition(item.setup.isEmpty ? item.algorithms.isEmpty : !item.algorithms.isEmpty)
            precondition(item.algorithms.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            precondition(item.setup.split(separator: " ").allSatisfy { $0.range(of: "^[RUF](2)?(')?$", options: .regularExpression) != nil })
            let image = try Data(contentsOf: root.appendingPathComponent("MegaminxTrainer/Resources/Cases/\(item.id).png"))
            precondition(image.starts(with: [137,80,78,71]))
        }
        let suite = "megaminx-tests-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = TrainerModel(catalog: cases, defaults: defaults)
        model.selected = [1, 2, 3]; model.begin(recap: true)
        var visited: Set<Int> = []
        for position in 1...3 {
            precondition(model.recapPosition == position)
            precondition(visited.insert(model.current!.id).inserted)
            model.tapTimer(); model.tapTimer()
            precondition(!model.running && model.solves.count == position)
            model.next()
        }
        precondition(model.complete && model.current == nil && visited == [1,2,3])
        model.begin(recap: false)
        model.tapTimer(); model.cancelTiming()
        precondition(model.solves.count == 3 && model.elapsed == 0)
        model.solves = [1.0, 2, 3, 4, 100].map { Solve(caseID: 1, seconds: $0, date: Date()) }
        precondition(model.ao5 == 3 && model.best == 1 && model.mean == 22)
        model.save()
        let restored = TrainerModel(catalog: cases, defaults: defaults)
        precondition(restored.selected == [1,2,3] && restored.solves.count == 5)
        restored.selected = []; restored.begin(recap: false)
        precondition(!restored.running)
        // Existing OLL v1 data must load unchanged when adding PLL.
        precondition(defaults.data(forKey: "megaminx.state.v1") != nil)
        let pllCases = try JSONDecoder().decode([TrainerCase].self, from: Data(contentsOf: root.appendingPathComponent("MegaminxTrainer/Resources/pll-cases.json")))
        precondition(pllCases.count == 152 && Set(pllCases.map(\.id)).count == 152)
        precondition(pllCases.reduce(0) { $0 + $1.algorithms.count } == 239)
        let q1 = pllCases.first { $0.id == 90 }!
        precondition(q1.name == "Q1+" && q1.algorithms.count == 3)
        precondition(q1.algorithms.first == "(R2' U2 R2 U R2' U2 R2 U' R2' U2 R2 U R2' U2 R2)")
        precondition(Set(pllCases.map(\.name)).count == 152)
        precondition(Set(pllCases.map(\.group)) == Set(1...26))
        precondition(pllCases.filter { $0.setup.isEmpty }.map(\.id) == [81])
        precondition(TrainerKind.pll.groupName(1) == "Group A" && TrainerKind.pll.groupName(26) == "Group Z")
        precondition(TrainerKind.oll.groupName(37) == "Group 37")
        for item in pllCases {
            precondition(TrainerCase.inverse(item.solution) == item.setup)
            precondition(!item.groupDescription.isEmpty)
            precondition(item.setup.isEmpty ? item.algorithms.isEmpty : !item.algorithms.isEmpty)
            precondition(item.algorithms.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            precondition(item.setup.split(separator: " ").allSatisfy { $0.range(of: "^[RU](2)?(')?$", options: .regularExpression) != nil })
            let image = try Data(contentsOf: root.appendingPathComponent("MegaminxTrainer/Resources/PLLCases/\(item.id).png"))
            precondition(image.starts(with: [137,80,78,71]))
        }
        let pll = TrainerModel(kind: .pll, catalog: pllCases, defaults: defaults)
        precondition(pll.solves.isEmpty && pll.appearances.isEmpty && pll.selected == [1,2])
        pll.selected = [4,5,81]; pll.weighted = false; pll.begin(recap: true)
        var pllVisited: Set<Int> = []
        for position in 1...3 {
            precondition(pllVisited.insert(pll.current!.id).inserted)
            pll.tapTimer(); pll.tapTimer()
            precondition(pll.solves.count == position)
            pll.next()
        }
        precondition(pll.complete && pllVisited == [4,5,81])
        let pllRestored = TrainerModel(kind: .pll, catalog: pllCases, defaults: defaults)
        precondition(pllRestored.selected == [4,5,81] && pllRestored.solves.count == 3 && !pllRestored.weighted)
        let ollAfterPLL = TrainerModel(catalog: cases, defaults: defaults)
        precondition(ollAfterPLL.selected == [1,2,3] && ollAfterPLL.solves.count == 5 && ollAfterPLL.weighted)
        precondition(ollAfterPLL.appearances == restored.appearances)
        pllRestored.begin(recap: false); pllRestored.tapTimer(); pllRestored.cancelTiming()
        precondition(!pllRestored.running && pllRestored.elapsed == 0 && pllRestored.solves.count == 3)
        // Clearing one trainer must leave the other trainer's history intact.
        pllRestored.solves = []; pllRestored.save()
        precondition(TrainerModel(catalog: cases, defaults: defaults).solves.count == 5)
        precondition(TrainerModel(kind: .pll, catalog: pllCases, defaults: defaults).solves.isEmpty)
        // Exact input timestamps determine the result without display ticks.
        let timing = TrainerModel(catalog: cases, defaults: defaults)
        timing.selected = [1]; timing.begin(recap: false)
        let priorSolves = timing.solves.count
        timing.tapTimer(at: 100)
        precondition(timing.running && timing.timerStartedAt == 100 && timing.elapsed == 0)
        timing.tapTimer(at: 112.345)
        precondition(!timing.running && timing.timerStartedAt == nil)
        precondition(abs(timing.elapsed - 12.345) < 0.000001)
        precondition(abs(timing.solves.first!.seconds - 12.345) < 0.000001)
        timing.tapTimer(at: 113) // A saved solve cannot be stopped/saved again.
        precondition(timing.solves.count == priorSolves + 1)
        timing.save() // Flushes the ordered background stop write.
        precondition(TrainerModel(catalog: cases, defaults: defaults).solves.count == priorSolves + 1)
        timing.next(); timing.tapTimer(at: 200); timing.cancelTiming()
        precondition(timing.timerStartedAt == nil && !timing.running && timing.elapsed == 0)
        // A later preference save must never be overwritten by an older stop save.
        timing.tapTimer(at: 300); timing.tapTimer(at: 301)
        timing.weighted = false; timing.save()
        let timingRestored = TrainerModel(catalog: cases, defaults: defaults)
        precondition(!timingRestored.weighted && timingRestored.solves.count == priorSolves + 2)
        print("Passed: 178 OLL and 152 PLL resources, inverse notation, recap, timer, interruption, statistics, OLL migration, independent trainer persistence, 541 imported algorithms, group descriptions, Q1+ mapping, event-timestamp timing, ordered background saves")
    }
}
