// =============================================================================
// os/defaults/display-mode.swift -- built-in display "More Space" scaler
//
// Purpose:      Drive the built-in (laptop) panel to its "More Space" preset --
//               the largest 2x HiDPI mode the Displays panel exposes -- and
//               verify/show that state. Uses only public CoreGraphics CGDisplay*
//               API; no third-party tool and no background agent.
// Depends on:   CoreGraphics (system framework); the `swift` interpreter from
//               the Xcode Command Line Tools (already required by Homebrew).
// Side effects: `apply` permanently reconfigures the built-in display mode via
//               CGCompleteDisplayConfiguration(.permanently); `verify` and
//               `show` are read-only. Exit codes: 0 ok/converged, 1 drift or
//               apply failure, 2 no built-in display / no HiDPI mode, 64 usage.
// =============================================================================

import CoreGraphics
import Foundation

func die(_ message: String, _ code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

// First active display reporting as built-in. On a laptop this is the panel.
func builtinDisplay() -> CGDirectDisplayID? {
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return nil }
    return ids.first { CGDisplayIsBuiltin($0) != 0 }
}

// 2x HiDPI modes usable for the desktop GUI, sorted largest-first by point
// size. These are exactly the named presets in the Displays panel; the largest
// is "More Space". The kCGDisplayShowDuplicateLowResolutionModes option is what
// surfaces the GPU-scaled HiDPI modes (point size != pixel size).
func hiDPIModes(_ display: CGDirectDisplayID) -> [CGDisplayMode] {
    let options: [CFString: Any] = [kCGDisplayShowDuplicateLowResolutionModes: true]
    let modes = (CGDisplayCopyAllDisplayModes(display, options as CFDictionary) as? [CGDisplayMode]) ?? []
    return modes
        .filter { $0.pixelWidth == $0.width * 2 && $0.pixelHeight == $0.height * 2 }
        .filter { $0.isUsableForDesktopGUI() }
        .sorted { ($0.width, $0.height) > ($1.width, $1.height) }
}

// Largest HiDPI mode = "More Space". Among equal-width candidates, prefer one
// whose refresh rate matches the current mode so ProMotion is not dropped.
func moreSpaceMode(_ display: CGDirectDisplayID) -> CGDisplayMode? {
    let modes = hiDPIModes(display)
    guard let maxWidth = modes.first?.width else { return nil }
    let widest = modes.filter { $0.width == maxWidth }
    let currentHz = CGDisplayCopyDisplayMode(display)?.refreshRate ?? 0
    return widest.first { $0.refreshRate == currentHz }
        ?? widest.max { $0.refreshRate < $1.refreshRate }
        ?? widest.first
}

func describe(_ mode: CGDisplayMode) -> String {
    "\(mode.width)x\(mode.height) (\(mode.pixelWidth)x\(mode.pixelHeight) px)"
}

func matches(_ lhs: CGDisplayMode, _ rhs: CGDisplayMode) -> Bool {
    lhs.width == rhs.width && lhs.height == rhs.height && lhs.pixelWidth == rhs.pixelWidth
}

let action = CommandLine.arguments.dropFirst().first ?? ""

guard let display = builtinDisplay() else { die("no built-in display found", 2) }
guard let target = moreSpaceMode(display) else { die("no HiDPI 'More Space' mode available", 2) }
let current = CGDisplayCopyDisplayMode(display)

switch action {
case "apply":
    if let current, matches(current, target) {
        print(describe(target))  // already converged -- no reconfiguration
        exit(0)
    }
    var config: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&config) == .success else { die("CGBeginDisplayConfiguration failed", 1) }
    guard CGConfigureDisplayWithDisplayMode(config, display, target, nil) == .success else {
        CGCancelDisplayConfiguration(config)
        die("CGConfigureDisplayWithDisplayMode failed", 1)
    }
    guard CGCompleteDisplayConfiguration(config, .permanently) == .success else {
        die("CGCompleteDisplayConfiguration failed", 1)
    }
    print(describe(target))
    exit(0)

case "verify":
    guard let current else { die("cannot read current display mode", 1) }
    print("current=\(describe(current)) target=\(describe(target))")
    exit(matches(current, target) ? 0 : 1)

case "show":
    print("built-in display id=\(display)")
    if let current { print("current=\(describe(current)) @\(current.refreshRate)Hz") }
    print("target (More Space)=\(describe(target)) @\(target.refreshRate)Hz")
    print("available HiDPI modes (largest first):")
    for mode in hiDPIModes(display) { print("  \(describe(mode)) @\(mode.refreshRate)Hz") }
    exit(0)

default:
    die("usage: display-mode.swift {apply|verify|show}", 64)
}
