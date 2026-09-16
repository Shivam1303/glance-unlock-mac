@preconcurrency import CoreImage
@preconcurrency import Vision

private final class AnalysisBox: @unchecked Sendable {
    let value: AnalyzedFace
    init(_ value: AnalyzedFace) { self.value = value }
}

private final class SampleBufferBox: @unchecked Sendable {
    let value: CMSampleBuffer
    init(_ value: CMSampleBuffer) { self.value = value }
}

final class FaceAnalyzer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "GlanceUnlock.face.analysis", qos: .userInitiated)
    private let context = CIContext()
    private var lastAnalysis = Date.distantPast
    private let interval: TimeInterval

    init(interval: TimeInterval = 0.20) {
        self.interval = interval
    }

    func analyze(_ sampleBuffer: CMSampleBuffer, completion: @escaping @MainActor @Sendable (AnalyzedFace) -> Void) {
        let bufferBox = SampleBufferBox(sampleBuffer)
        queue.async { [weak self] in
            guard let self else { return }
            guard Date().timeIntervalSince(self.lastAnalysis) >= self.interval else { return }
            self.lastAnalysis = Date()
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(bufferBox.value) else { return }
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
            do {
                // Rectangle detection is more tolerant than the landmark request
                // on the small, low-noise frames from a laptop camera. Landmarks
                // are requested only after exactly one face is found.
                let rectangleRequest = VNDetectFaceRectanglesRequest()
                try handler.perform([rectangleRequest])
                let detectedFaces = rectangleRequest.results ?? []
                var faces = detectedFaces
                if detectedFaces.count == 1 {
                    let landmarksRequest = VNDetectFaceLandmarksRequest()
                    landmarksRequest.inputFaceObservations = detectedFaces
                    try? handler.perform([landmarksRequest])
                    if let landmarkFace = landmarksRequest.results?.first { faces = [landmarkFace] }
                }
                let result = self.result(for: faces, pixelBuffer: pixelBuffer)
                let resultBox = AnalysisBox(result)
                DispatchQueue.main.async { completion(resultBox.value) }
            } catch {
                let resultBox = AnalysisBox(AnalyzedFace(guidance: .poorQuality, crop: nil, eyeOpenness: nil))
                DispatchQueue.main.async { completion(resultBox.value) }
            }
        }
    }

    private func result(for faces: [VNFaceObservation], pixelBuffer: CVPixelBuffer) -> AnalyzedFace {
        guard faces.count == 1, let face = faces.first else {
            return AnalyzedFace(guidance: faces.isEmpty ? .noFace : .multipleFaces, crop: nil, eyeOpenness: nil)
        }
        let box = face.boundingBox
        // A laptop camera normally sees a smaller face than a hand-held phone.
        // Keep the threshold conservative enough to produce a useful crop without
        // forcing the user uncomfortably close to the display.
        guard box.width >= 0.07, box.height >= 0.07 else { return AnalyzedFace(guidance: .tooSmall, crop: nil, eyeOpenness: nil) }
        let center = CGPoint(x: box.midX, y: box.midY)
        guard abs(center.x - 0.5) < 0.42, abs(center.y - 0.5) < 0.42 else { return AnalyzedFace(guidance: .offCenter, crop: nil, eyeOpenness: nil) }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let padded = paddedRect(for: box, imageExtent: image.extent)
        guard let crop = context.createCGImage(image.cropped(to: padded), from: padded) else {
            return AnalyzedFace(guidance: .poorQuality, crop: nil, eyeOpenness: nil)
        }
        return AnalyzedFace(guidance: .valid, crop: crop, eyeOpenness: eyeOpenness(in: face))
    }

    private func paddedRect(for box: CGRect, imageExtent: CGRect) -> CGRect {
        let rect = CGRect(x: imageExtent.minX + box.minX * imageExtent.width, y: imageExtent.minY + box.minY * imageExtent.height, width: box.width * imageExtent.width, height: box.height * imageExtent.height)
        return rect.insetBy(dx: -rect.width * 0.18, dy: -rect.height * 0.18).intersection(imageExtent).integral
    }

    private func eyeOpenness(in face: VNFaceObservation) -> Double? {
        guard let landmarks = face.landmarks, let left = landmarks.leftEye, let right = landmarks.rightEye else { return nil }
        let values = [left, right].compactMap { region -> Double? in
            let points = region.normalizedPoints
            guard points.count >= 4 else { return nil }
            let xs = points.map(\.x), ys = points.map(\.y)
            guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max(), maxX > minX else { return nil }
            return Double((maxY - minY) / (maxX - minX))
        }
        guard values.count == 2 else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

}
