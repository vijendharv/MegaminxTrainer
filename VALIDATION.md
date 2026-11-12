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
