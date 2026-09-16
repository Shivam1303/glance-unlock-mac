import CoreGraphics

enum FaceGuidance: Equatable {
    case noFace, multipleFaces, tooSmall, offCenter, poorQuality, valid

    var message: String {
        switch self {
        case .noFace: "Looking for a face"
        case .multipleFaces: "One person at a time"
        case .tooSmall: "Move a little closer"
        case .offCenter: "Center your face in the guide"
        case .poorQuality: "Improve lighting and hold still"
        case .valid: "Face found"
        }
    }
}

struct AnalyzedFace {
    let guidance: FaceGuidance
    let crop: CGImage?
    let eyeOpenness: Double?
}
