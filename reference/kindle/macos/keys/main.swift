// Streamdeckify Keys: a tiny app that presses one key combination and quits.
// The server starts it with `open -W -n -a "Streamdeckify Keys.app" --args <code> [mods] [result-file]`,
// so macOS sees an app of its own and the Accessibility permission belongs to
// "Streamdeckify Keys". Given to the Python that runs the server, it didn't stick.
// code: a macOS virtual key code (49 is space). mods: command, option, control
// and shift, separated by commas. The result, "ok" or why it failed, goes to the result file.
import ApplicationServices
import Cocoa

func finish(_ resultFile: String?, _ text: String, _ code: Int32) -> Never {
    if let file = resultFile {
        try? text.write(toFile: file, atomically: true, encoding: .utf8)
    }
    FileHandle.standardError.write((text + "\n").data(using: .utf8)!)
    exit(code)
}

let args = CommandLine.arguments
guard args.count >= 2, let keyCode = UInt16(args[1]) else {
    finish(nil, "usage: keys <code> [mods] [result-file]", 2)
}
let mods = args.count > 2 ? args[2].split(separator: ",").map(String.init) : []
let resultFile = args.count > 3 ? args[3] : nil

// Asks for the Accessibility permission. The first time, macOS shows its prompt and lists the app.
let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
if !AXIsProcessTrustedWithOptions(options) {
    finish(resultFile, "Streamdeckify Keys has no Accessibility permission yet", 3)
}

var flags = CGEventFlags()
for mod in mods {
    switch mod {
    case "command": flags.insert(.maskCommand)
    case "option": flags.insert(.maskAlternate)
    case "control": flags.insert(.maskControl)
    case "shift": flags.insert(.maskShift)
    default: finish(resultFile, "unknown modifier: \(mod)", 2)
    }
}
let source = CGEventSource(stateID: .hidSystemState)
guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
      let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
    finish(resultFile, "can't create the keyboard event", 1)
}
down.flags = flags
up.flags = flags
down.post(tap: .cghidEventTap)
usleep(40_000)
up.post(tap: .cghidEventTap)
usleep(40_000)
finish(resultFile, "ok", 0)
