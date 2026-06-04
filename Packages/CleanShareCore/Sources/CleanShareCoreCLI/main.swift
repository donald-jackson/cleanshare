import CleanShareCore
import Foundation
import UniformTypeIdentifiers

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

func detectKind(for url: URL) -> MediaKind? {
    if let type = UTType(filenameExtension: url.pathExtension.lowercased()) {
        return MediaKind(uti: type)
    }
    return nil
}

let kind: MediaKind
if let requestedKind, requestedKind != "auto" {
    guard let parsed = MediaKind(rawValue: requestedKind) else {
        fail("unsupported --kind: \(requestedKind)")
    }
    kind = parsed
} else if let detected = detectKind(for: inputURL) {
    kind = detected
} else {
    fail("could not detect media kind for \(inputURL.path); pass --kind=…")
}

let cleaner: any Cleaner
switch kind {
case .jpeg, .heic, .heif, .png, .gif, .webp, .tiff, .dng:
    cleaner = ImageIOCleaner()
case .mp4, .mov:
    cleaner = AVPassthroughCleaner()
case .livePhoto:
    fail("Live Photo cleaning requires a paired HEIC+MOV; not supported by the CLI")
}

let prefs = CleaningPreferences()

do {
    let receipt = try await cleaner.clean(input: inputURL, output: outputURL, prefs: prefs)
    print("OK \(receipt.outputURL.path) (\(receipt.bytesIn)→\(receipt.bytesOut) bytes, \(receipt.durationMS)ms)")
} catch {
    fail("clean failed for \(inputURL.path): \(error)")
}
