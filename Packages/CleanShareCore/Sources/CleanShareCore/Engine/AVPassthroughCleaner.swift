import AVFoundation
import CoreMedia
import Foundation

/// Strips container- and track-level metadata from MP4/MOV video by copying the
/// compressed elementary streams sample-by-sample through `AVAssetWriter` with
/// `outputSettings: nil` (passthrough). No pixel/audio re-encode happens, so the
/// operation is lossless and near-native in throughput. Metadata-only tracks are
/// dropped, and writer/track metadata is reset to empty, which removes `udta`,
/// `meta`, GPS atoms, and the Live Photo content identifier. See PLAN.md §4.3.
public struct AVPassthroughCleaner: Cleaner {
    public init() {}

    /// A reader-output / writer-input pair confined to a single pump Task.
    /// AVFoundation's reader outputs and writer inputs are not `Sendable`, but
    /// each pair is only ever touched from its own pump and never shared across
    /// isolation domains, so the `@unchecked Sendable` is sound. See PLAN.md §7.2.
    private struct TrackPump: @unchecked Sendable {
        let output: AVAssetReaderTrackOutput
        let input: AVAssetWriterInput
    }

    public func clean(input: URL, output: URL, prefs _: CleaningPreferences) async throws -> CleanReceipt {
        let start = DispatchTime.now()

        let asset = AVURLAsset(url: input, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ])
        let tracks = try await asset.load(.tracks)

        let isMOV = output.pathExtension.lowercased() == "mov"
        let fileType: AVFileType = isMOV ? .mov : .mp4
        let writer = try AVAssetWriter(outputURL: output, fileType: fileType)
        writer.shouldOptimizeForNetworkUse = true
        writer.metadata = []

        let reader = try AVAssetReader(asset: asset)
        var pairs: [TrackPump] = []

        for track in tracks {
            if track.mediaType == .metadata || track.mediaType == .text { continue }

            let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            readerOutput.alwaysCopiesSampleData = false
            reader.add(readerOutput)

            let formatDescs = try await track.load(.formatDescriptions)
            guard let hint = formatDescs.first else { continue }

            let writerInput = AVAssetWriterInput(
                mediaType: track.mediaType,
                outputSettings: nil,
                sourceFormatHint: hint
            )
            writerInput.expectsMediaDataInRealTime = false
            writerInput.metadata = []
            writer.add(writerInput)
            pairs.append(TrackPump(output: readerOutput, input: writerInput))
        }

        guard reader.startReading(), writer.startWriting() else {
            throw CleanerError.avFailed(reason: (reader.error ?? writer.error)?.localizedDescription)
        }
        writer.startSession(atSourceTime: .zero)

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for pair in pairs {
                    group.addTask { try await Self.pump(pair) }
                }
                try await group.waitForAll()
            }
        } catch {
            writer.cancelWriting()
            reader.cancelReading()
            try? FileManager.default.removeItem(at: output)
            throw error
        }

        await writer.finishWriting()
        guard writer.status == .completed else {
            throw CleanerError.avFailed(reason: writer.error?.localizedDescription)
        }

        // Fail closed: verify the cleaned container carries no residual metadata.
        // Passthrough builds a fresh container with empty writer/track metadata,
        // so a clean output has none — but we never certify without checking.
        let leaked = try await MetadataAuditor.auditVideo(url: output, allowing: [])
        guard leaked.isEmpty else {
            try? FileManager.default.removeItem(at: output)
            throw CleanerError.leakDetected(keys: leaked)
        }

        let kind: MediaKind = isMOV ? .mov : .mp4
        let elapsedMS = Int((DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)

        return CleanReceipt(
            inputURL: input,
            outputURL: output,
            kind: kind,
            bytesIn: self.fileSize(at: input),
            bytesOut: self.fileSize(at: output),
            durationMS: elapsedMS,
            reencoded: false,
            leakedKeys: []
        )
    }

    private static func pump(_ pair: TrackPump) async throws {
        try Task.checkCancellation()
        let queue = DispatchQueue(label: "solutions.ddj.cleanshare.av.pump")
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            pair.input.requestMediaDataWhenReady(on: queue) {
                while pair.input.isReadyForMoreMediaData {
                    if Task.isCancelled {
                        pair.input.markAsFinished()
                        cont.resume(throwing: CleanerError.cancelled)
                        return
                    }
                    if let sample = pair.output.copyNextSampleBuffer() {
                        if !pair.input.append(sample) {
                            pair.input.markAsFinished()
                            cont.resume(throwing: CleanerError.appendFailed)
                            return
                        }
                    } else {
                        pair.input.markAsFinished()
                        cont.resume()
                        return
                    }
                }
            }
        }
    }

    private func fileSize(at url: URL) -> Int {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize ?? 0
    }
}
