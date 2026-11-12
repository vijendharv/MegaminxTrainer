# Validation — November 11, 2026

- Xcode 26.6: iOS Simulator Debug build passed for arm64 and x86_64 without signing.
- Unsigned iPhone/iPad arm64 Release build passed using the iPhoneOS SDK.
- Executable model checks passed: 178 case records and PNG resources, setup/solution inverse round-trip, recap uniqueness and completion, timer start/stop, interruption handling, best/mean/average-of-five, and saved-state restoration.
- Xcode project property-list validation passed.
- iPhone and iPad visual checks were attempted, but Simulator first-run migration did not finish during validation. Layout, VoiceOver, and device interactions still need manual testing.
- Physical-puzzle correctness of source setups and diagrams has not been independently verified.
- No signed device installation or App Store upload has been performed.

## iOS and iPadOS 16 compatibility update

- Lowered Debug and Release deployment targets to 16.0; device families remain iPhone and iPad.
- Replaced iOS 17 empty-state views, button initializers, and change handlers with iOS 16-compatible equivalents; changed the Recap symbol to one available on iOS 16.
- All app Swift sources passed type checking against the iPhoneOS SDK with an explicit arm64-apple-ios16.0 target.
- Executable model checks passed again, and the Xcode project property list passed validation.
- Full unsigned build was attempted but asset compilation failed because CoreSimulator has no available simulator runtimes in this environment. No iOS 16 device or simulator interaction testing was completed.

## Combined OLL and PLL trainer

- Added a persistent OLL/PLL selector above the tabs. Switching keeps the current tab and cancels an active timer.
- Added 152 PLL entries in groups A–Z, including the solved/skip entry, with offline diagrams and setups. Solutions reverse the setup moves.
- Existing OLL v1 saved data is retained. Each trainer has its own case selections, frequency counts, weighting preference, and solve history.
- Expanded model checks passed for all 330 diagrams, valid setup notation, inverse round trips, PLL recap, timer interruption, separate persistence, and preservation of OLL progress.
- All app sources passed type checking for arm64-apple-ios16.0.
- Unsigned iPhone/iPad simulator build passed. Built-bundle checks confirmed minimum OS 16.0, both device families, both JSON catalogs, and all 330 diagrams.
- Interactive simulator layout checks were not completed because the simulator UI session stalled. Physical-puzzle validation remains unverified.
