import Foundation

@main struct ModelChecks {
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let cases = try JSONDecoder().decode([OLLCase].self, from: Data(contentsOf: root.appendingPathComponent("MegaminxTrainer/Resources/cases.json")))
        precondition(cases.count == 178 && Set(cases.map(\.id)).count == 178)
        for item in cases {
            precondition(OLLCase.inverse(item.solution) == item.setup)
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
        print("Passed: 178 case resources, inverse notation, recap, timer, interruption, statistics, persistence")
    }
}
