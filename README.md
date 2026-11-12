# Megaminx Lab — iPhone & iPad

Native SwiftUI prototype for iOS/iPadOS 16 or later, inspired by [Reinier Schippers’s OLL trainer](https://reinierschippers.nl/oll_trainer-master/).

## Run on your iPhone or iPad

1. Open `MegaminxTrainer.xcodeproj` in Xcode.
2. Select the MegaminxTrainer target → Signing & Capabilities. Choose your Apple development team and a unique bundle identifier.
3. Connect your device, enable Developer Mode if prompted, select it as the run destination, and click Run. A free Apple ID can be used for personal device testing with Apple's provisioning restrictions.

For simulator use, select an installed iPhone or iPad simulator and Run. No account or backend is needed. The project has no external dependencies.

## Included

- 178 bundled case diagrams and setup sequences across 37 groups, with search and group selection.
- Weighted random practice and a shuffled, one-pass recap.
- Tap-to-start/stop timer using a monotonic clock; interruptions cancel an unfinished time.
- Revealable solutions derived by reversing setup moves. These return to the exact initial state; they are not optimized OLL algorithms.
- Local selection, frequency, and solve-history persistence; best, mean, and trimmed average of five.
- Custom Megaminx app icon for iPhone and iPad.
- Adaptive case grid, system dark/light appearance, Dynamic Type, and accessible control labels.

Start each setup from a solved Megaminx. The app does not simulate the puzzle or verify a physical solve. Times are recorded as raw durations; inspection, +2 and DNF are not implemented. Recap skips are not counted as timed solves. Frequency weighting uses how often a case was presented.

## Sources and distribution

The reference credits Reinier Schippers, Roman Strakhov, and James’s Megaminx OLL document:
https://docs.google.com/spreadsheets/d/1lVODoMORbDdVXwTG4RUZPWCSrx8uPx2bvwvXg5tuQYE/edit#gid=165427832

Case names, diagrams (`Resources/Cases`) and setup sequences (`Resources/cases.json`) were retrieved from the reference on November 11, 2026. The reference's algorithm-hint table contains apparent placeholders, so it is intentionally not used. Setup sequences are preserved and hints are their mechanical inverses. Case/diagram correctness still needs a physical-puzzle review.

The downloaded artwork's reuse license has not been established. Obtain permission or replace it with independently produced diagrams before distributing this prototype. This project is not an App Store submission: it still needs signing, physical-device QA, rights clearance, and release/privacy metadata. No Apple account settings or publishing actions were performed.

## Validation

Build without signing:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project MegaminxTrainer.xcodeproj -scheme MegaminxTrainer \
  -sdk iphonesimulator -derivedDataPath /tmp/MegaminxBuild \
  CODE_SIGNING_ALLOWED=NO build
```

Run the model checks from this directory on macOS with Xcode:

```sh
xcrun swiftc -module-cache-path /tmp/MegaminxSwiftCache \
  MegaminxTrainer/TrainerModel.swift Tests/ModelChecks.swift \
  -o /tmp/megaminx-model-checks
/tmp/megaminx-model-checks "$PWD"
```

These validate all resource files, inverse notation, recap uniqueness/completion, timer state, interrupted solve handling, statistics, and persistence. Inverse checks establish notation round-tripping, not physical puzzle correctness.
