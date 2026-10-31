import Cocoa

public final class S3Uploader {
    public static let shared = S3Uploader()
    
    private init() {}
    
    public func upload(
        imageData: Data,
        mimeType: String,
        fileExtension: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let config = S3Config.load()
        guard config.isConfigured else {
            let error = NSError(domain: "PsrShot.S3", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cấu hình S3 chưa hoàn chỉnh. Vui lòng vào Cài đặt (Preferences) để cấu hình S3 Storage."])
            completion(.failure(error))
            return
        }
        
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: now)
        let randomSuffix = UUID().uuidString.prefix(6).lowercased()
        
        var prefix = config.pathPrefix.trimmingCharacters(in: .whitespaces)
        if !prefix.isEmpty && !prefix.hasSuffix("/") {
            prefix += "/"
        }
        // Remove leading slash if any
        if prefix.hasPrefix("/") {
            prefix.removeFirst()
        }
        
        let objectKey = "\(prefix)\(timestamp)_\(randomSuffix).\(fileExtension)"
        
        guard let uploadURL = makeUploadURL(config: config, key: objectKey) else {
            let error = NSError(domain: "PsrShot.S3", code: 401, userInfo: [NSLocalizedDescriptionKey: "URL S3 Endpoint không hợp lệ."])
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.httpBody = imageData
        
        let headers = S3SigV4Signer.sign(
            method: "PUT",
            url: uploadURL,
            payload: imageData,
            contentType: mimeType,
            config: config,
            date: now
        )
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    NotificationManager.shared.postUploadFailure(error: error)
                    completion(.failure(error))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200...204).contains(httpResponse.statusCode) {
                    let viewURL = self.makePublicViewURL(config: config, key: objectKey, uploadURL: uploadURL)
                    DispatchQueue.main.async {
                        // Copy link to clipboard
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(viewURL, forType: .string)
                        
                        NotificationManager.shared.postUploadSuccess(viewURL: viewURL)
                        completion(.success(viewURL))
                    }
                } else {
                    let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    let error = NSError(domain: "PsrShot.S3", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Upload lên S3 thất bại (HTTP \(httpResponse.statusCode)): \(responseBody)"
                    ])
                    DispatchQueue.main.async {
                        NotificationManager.shared.postUploadFailure(error: error)
                        completion(.failure(error))
                    }
                }
            }
        }
        task.resume()
    }
    
    public func testConnection(config: S3Config, completion: @escaping (Result<String, Error>) -> Void) {
        guard config.isConfigured else {
            completion(.failure(NSError(domain: "PsrShot.S3", code: 400, userInfo: [NSLocalizedDescriptionKey: "Vui lòng nhập đầy đủ Bucket, Access Key và Secret Key."])))
            return
        }
        
        let testKey = ".psrshot_probe_\(UUID().uuidString.prefix(8))"
        guard let url = makeUploadURL(config: config, key: testKey) else {
            completion(.failure(NSError(domain: "PsrShot.S3", code: 401, userInfo: [NSLocalizedDescriptionKey: "Endpoint không hợp lệ."])))
            return
        }
        
        let probeData = "probe".data(using: .utf8)!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = probeData
        
        let headers = S3SigV4Signer.sign(
            method: "PUT",
            url: url,
            payload: probeData,
            contentType: "text/plain",
            config: config,
            date: Date()
        )
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            if let http = response as? HTTPURLResponse {
                if (200...204).contains(http.statusCode) {
                    DispatchQueue.main.async {
                        completion(.success("Kết nối thành công! Bucket đã sẵn sàng lưu trữ."))
                    }
                } else {
                    let msg = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Mã phản hồi: \(http.statusCode)"
                    let err = NSError(domain: "PsrShot.S3", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
                    DispatchQueue.main.async { completion(.failure(err)) }
                }
            }
        }
        task.resume()
    }
    
    private func makeUploadURL(config: S3Config, key: String) -> URL? {
        let endpointStr = config.endpoint.trimmingCharacters(in: .whitespaces)
        if endpointStr.isEmpty {
            // Standard AWS S3 URL
            let host = "\(config.bucket).s3.\(config.region).amazonaws.com"
            return URL(string: "https://\(host)/\(key)")
        } else {
            // Custom S3 endpoint (Cloudflare R2, MinIO, etc.)
            var base = endpointStr
            if !base.hasPrefix("http://") && !base.hasPrefix("https://") {
                base = "https://" + base
            }
            if !base.hasSuffix("/") {
                base += "/"
            }
            // Standard path-style for custom endpoints: https://endpoint/bucket/key
            return URL(string: "\(base)\(config.bucket)/\(key)")
        }
    }
    
    private func makePublicViewURL(config: S3Config, key: String, uploadURL: URL) -> String {
        let publicBase = config.publicBaseURL.trimmingCharacters(in: .whitespaces)
        if !publicBase.isEmpty {
            var base = publicBase
            if !base.hasPrefix("http://") && !base.hasPrefix("https://") {
                base = "https://" + base
            }
            if !base.hasSuffix("/") {
                base += "/"
            }
            return "\(base)\(key)"
        }
        return uploadURL.absoluteString
    }
}
