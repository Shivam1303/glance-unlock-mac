import CoreGraphics
import XCTest
@testable import GlanceUnlock

final class FaceProfileStoreTests: XCTestCase {
    func testFeaturePrintRoundTripsThroughKeychain() throws {
        let featurePrintService = FeaturePrintService()
        let service = "com.glanceunlock.tests.\(UUID().uuidString)"
        let store = FaceProfileStore(
            featurePrintService: featurePrintService,
            service: service,
            account: "round-trip"
        )
        defer { try? store.delete() }

        let image = try XCTUnwrap(makeTestImage())
        let featurePrint = try featurePrintService.makeFeaturePrint(from: image)

        try store.save([featurePrint])
        let loaded = try XCTUnwrap(store.load())

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].elementType, featurePrint.elementType)
        XCTAssertEqual(loaded[0].elementCount, featurePrint.elementCount)
    }

    private func makeTestImage() -> CGImage? {
        let side = 64
        guard let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.setFillColor(CGColor(red: 0.18, green: 0.32, blue: 0.58, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.setFillColor(CGColor(red: 0.86, green: 0.68, blue: 0.42, alpha: 1))
        context.fillEllipse(in: CGRect(x: 12, y: 8, width: 40, height: 48))
        return context.makeImage()
    }
}
