# AllujaHaptics

A simple haptics library derived from an internal library that Alluja uses in its projects.

## Usage

First initialize the haptics system. This only has to be done once, but it can be done as many times as you want:

```swift
try Haptics.initialize()
```

Then you're free to generate your own haptic patterns using `Haptics.generatePattern()` or use premade patterns in `DefaultHapticPatterns`.
