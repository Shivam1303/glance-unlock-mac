import AVFoundation
import SwiftUI

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    func makeNSView(context: Context) -> PreviewView { let view = PreviewView(); view.videoPreviewLayer.session = session; return view }
    func updateNSView(_ nsView: PreviewView, context: Context) { nsView.videoPreviewLayer.session = session }
}

final class PreviewView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = AVCaptureVideoPreviewLayer()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override func layout() {
        super.layout()
        videoPreviewLayer.videoGravity = .resizeAspectFill
        if let connection = videoPreviewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}
