import Foundation

/// Minimal multipart/form-data body builder for file uploads.
struct MultipartFormData {
    let boundary = "printernizer-\(UUID().uuidString)"
    private var body = Data()

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    mutating func addField(name: String, value: String) {
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
        body.append(Data("\(value)\r\n".utf8))
    }

    mutating func addFile(name: String, filename: String, data: Data, mimeType: String = "application/octet-stream") {
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n".utf8))
    }

    func finalized() -> Data {
        var data = body
        data.append(Data("--\(boundary)--\r\n".utf8))
        return data
    }
}
