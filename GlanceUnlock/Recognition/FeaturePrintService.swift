import AppKit
import CoreGraphics
@preconcurrency import Vision

enum FeaturePrintError: Error { case unavailable, invalidArchive, normalizationFailed }

private final class UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

final class FeaturePrintService: @unchecked Sendable {
    private let queue = DispatchQueue(label: "GlanceUnlock.feature-print", qos: .userInitiated)
    private let normalizedSide = 320

    func makeFeaturePrint(from crop: CGImage) throws -> VNFeaturePrintObservation {
        let normalizedCrop = try normalizedFaceCrop(from: crop)
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = VNGenerateImageFeaturePrintRequestRevision2
        let handler = VNImageRequestHandler(cgImage: normalizedCrop, options: [:])
        try handler.perform([request])
        guard let print = request.results?.first else { throw FeaturePrintError.unavailable }
        return print
    }

    /// Produces a transient, predictable RGB square for Vision. Camera crops can
    /// be very small on a MacBook, and feature-print generation is less reliable
    /// with arbitrary camera pixel formats and tiny dimensions.
    private func normalizedFaceCrop(from crop: CGImage) throws -> CGImage {
        let side = CGFloat(normalizedSide)
        guard crop.width > 0, crop.height > 0,
              let context = CGContext(
                data: nil,
                width: normalizedSide,
                height: normalizedSide,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { throw FeaturePrintError.normalizationFailed }

        context.interpolationQuality = .high
        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        let scale = max(side / CGFloat(crop.width), side / CGFloat(crop.height))
        let size = CGSize(width: CGFloat(crop.width) * scale, height: CGFloat(crop.height) * scale)
        let rect = CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height)
        context.draw(crop, in: rect)
        guard let image = context.makeImage() else { throw FeaturePrintError.normalizationFailed }
        return image
    }

    func archive(_ prints: [VNFeaturePrintObservation]) throws -> Data {
        try NSKeyedArchiver.archivedData(withRootObject: prints, requiringSecureCoding: true)
    }

    func unarchive(_ data: Data) throws -> [VNFeaturePrintObservation] {
        guard let prints = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, VNFeaturePrintObservation.self], from: data) as? [VNFeaturePrintObservation] else { throw FeaturePrintError.invalidArchive }
        return prints
    }

    func distance(from current: VNFeaturePrintObservation, to enrolled: VNFeaturePrintObservation) throws -> Float {
        var value: Float = 0
        try current.computeDistance(&value, to: enrolled)
        return value
    }

    func makeFeaturePrintAsync(from crop: CGImage, completion: @escaping @MainActor @Sendable (Result<VNFeaturePrintObservation, Error>) -> Void) {
        queue.async { [weak self] in
            let result: Result<VNFeaturePrintObservation, Error>
            if let self { result = Result { try self.makeFeaturePrint(from: crop) } }
            else { result = .failure(FeaturePrintError.unavailable) }
            let box = UncheckedSendableBox(result)
            DispatchQueue.main.async { completion(box.value) }
        }
    }

    func distancesAsync(from crop: CGImage, to enrolled: [VNFeaturePrintObservation], completion: @escaping @MainActor @Sendable (Result<[Float], Error>) -> Void) {
        let enrolledBox = UncheckedSendableBox(enrolled)
        queue.async { [weak self] in
            let result = Result { () throws -> [Float] in
                guard let self else { throw FeaturePrintError.unavailable }
                let current = try self.makeFeaturePrint(from: crop)
                return try enrolledBox.value.map { try self.distance(from: current, to: $0) }
            }
            let box = UncheckedSendableBox(result)
            DispatchQueue.main.async { completion(box.value) }
        }
    }
}
