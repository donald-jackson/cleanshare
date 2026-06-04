import CleanShareCore
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func usage() -> Never {
    fail("usage: cleanshare-cli clean <input> <output> [--kind=auto|jpeg|heic|…]")
}

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else { usage() }
guard command == "clean" else { fail("unknown command: \(command)") }

var positional: [String] = []
var requestedKind: String?
for arg in args.dropFirst() {
    if arg.hasPrefix("--kind=") {
        requestedKind = String(arg.dropFirst("--kind=".count))
    } else if arg.hasPrefix("--") {
        fail("unknown option: \(arg)")
    } else {
        positional.append(arg)
    }
}

guard positional.count == 2 else { usage() }
let inputURL = URL(fileURLWithPath: positional[0])
let outputURL = URL(fileURLWithPath: positional[1])

if let requestedKind, requestedKind != "auto", MediaKind(rawValue: requestedKind) == nil {
    fail("unsupported --kind: \(requestedKind)")
}

let prefs = CleaningPreferences()
let cleaner = ImageIOCleaner()

do {
    let receipt = try await cleaner.clean(input: inputURL, output: outputURL, prefs: prefs)
    print("OK \(receipt.outputURL.path) (\(receipt.bytesIn)→\(receipt.bytesOut) bytes, \(receipt.durationMS)ms)")
} catch {
    fail("clean failed for \(inputURL.path): \(error)")
}
