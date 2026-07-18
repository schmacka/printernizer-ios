import SwiftUI
import UIKit

/// Renders an MJPEG (multipart JPEG) camera stream. Frames are parsed
/// from the byte stream via JPEG start/end markers, which works
/// regardless of the exact multipart boundary format.
struct MJPEGStreamView: View {
    let url: URL

    @StateObject private var player = MJPEGStreamPlayer()

    var body: some View {
        ZStack {
            if let image = player.currentFrame {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if player.failed {
                VStack(spacing: 8) {
                    Image(systemName: "video.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Stream unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 200)
            } else {
                ProgressView()
                    .frame(height: 200)
            }
        }
        .onAppear {
            player.start(url: url)
        }
        .onDisappear {
            player.stop()
        }
    }
}

/// Incremental MJPEG parser on a URLSession data task.
final class MJPEGStreamPlayer: NSObject, ObservableObject, URLSessionDataDelegate {
    @Published var currentFrame: UIImage?
    @Published var failed = false

    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var buffer = Data()

    private static let jpegStart = Data([0xFF, 0xD8])
    private static let jpegEnd = Data([0xFF, 0xD9])

    func start(url: URL) {
        stop()
        failed = false

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = .infinity

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session
        task = session.dataTask(with: url)
        task?.resume()
    }

    func stop() {
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        buffer.removeAll()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)

        // Extract every complete JPEG frame currently in the buffer;
        // keep only the newest to avoid falling behind the stream.
        var newestFrame: UIImage?
        while let start = buffer.range(of: Self.jpegStart),
              let end = buffer.range(of: Self.jpegEnd, in: start.upperBound..<buffer.endIndex) {
            let frameData = buffer.subdata(in: start.lowerBound..<end.upperBound)
            buffer.removeSubrange(buffer.startIndex..<end.upperBound)
            if let image = UIImage(data: frameData) {
                newestFrame = image
            }
        }

        // Prevent unbounded growth on malformed streams.
        if buffer.count > 5_000_000 {
            buffer.removeAll()
        }

        if let frame = newestFrame {
            DispatchQueue.main.async { [weak self] in
                self?.currentFrame = frame
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard error != nil, (error as? URLError)?.code != .cancelled else { return }
        DispatchQueue.main.async { [weak self] in
            if self?.currentFrame == nil {
                self?.failed = true
            }
        }
    }
}
