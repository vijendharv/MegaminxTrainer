import Foundation

@main struct ModelChecks {
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let cases = try JSONDecoder().decode([TrainerCase].self, from: Data(contentsOf: root.appendingPathComponent("MegaminxTrainer/Resources/cases.json")))
        precondition(cases.count == 178 && Set(cases.map(\.id)).count == 178)
        for item in cases {
            precondition(TrainerCase.inverse(item.solution) == item.setup)
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
        precondition(Set(pllCases.map(\.group)) == Set(1...26))
        precondition(pllCases.filter { $0.setup.isEmpty }.map(\.id) == [81])
        precondition(TrainerKind.pll.groupName(1) == "Group A" && TrainerKind.pll.groupName(26) == "Group Z")
        precondition(TrainerKind.oll.groupName(37) == "Group 37")
        for item in pllCases {
            precondition(TrainerCase.inverse(item.solution) == item.setup)
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
        print("Passed: 178 OLL and 152 PLL resources, inverse notation, recap, timer, interruption, statistics, OLL migration, independent trainer persistence")
    }
}
