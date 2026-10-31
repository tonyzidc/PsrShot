import Foundation
import CryptoKit

public struct S3SigV4Signer {
    
    public static func sign(
        method: String,
        url: URL,
        payload: Data,
        contentType: String,
        config: S3Config,
        date: Date = Date()
    ) -> [String: String] {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let amzDate = dateFormatter.string(from: date)
        
        let dayFormatter = DateFormatter()
        dayFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dayFormatter.dateFormat = "yyyyMMdd"
        let dateStamp = dayFormatter.string(from: date)
        
        let payloadHash = sha256Hex(payload)
        
        guard let host = url.host else { return [:] }
        let hostHeader = (url.port != nil && url.port != 80 && url.port != 443) ? "\(host):\(url.port!)" : host
        
        // Canonical Request
        let canonicalURI = url.path.isEmpty ? "/" : url.path
        let canonicalQuery = url.query ?? ""
        
        var canonicalHeaders = "host:\(hostHeader)\n"
        canonicalHeaders += "x-amz-content-sha256:\(payloadHash)\n"
        canonicalHeaders += "x-amz-date:\(amzDate)\n"
        
        let signedHeaders = "host;x-amz-content-sha256;x-amz-date"
        
        let canonicalRequest = """
        \(method)
        \(canonicalURI)
        \(canonicalQuery)
        \(canonicalHeaders)
        \(signedHeaders)
        \(payloadHash)
        """
        
        let canonicalRequestHash = sha256Hex(canonicalRequest.data(using: .utf8)!)
        
        // String To Sign
        let credentialScope = "\(dateStamp)/\(config.region)/s3/aws4_request"
        let stringToSign = """
        AWS4-HMAC-SHA256
        \(amzDate)
        \(credentialScope)
        \(canonicalRequestHash)
        """
        
        // Derive Signing Key
        let kSecret = "AWS4" + config.secretAccessKey
        let kDate = hmacSha256(key: kSecret.data(using: .utf8)!, data: dateStamp.data(using: .utf8)!)
        let kRegion = hmacSha256(key: kDate, data: config.region.data(using: .utf8)!)
        let kService = hmacSha256(key: kRegion, data: "s3".data(using: .utf8)!)
        let kSigning = hmacSha256(key: kService, data: "aws4_request".data(using: .utf8)!)
        
        // Calculate Signature
        let signatureData = hmacSha256(key: kSigning, data: stringToSign.data(using: .utf8)!)
        let signature = signatureData.map { String(format: "%02x", $0) }.joined()
        
        let authHeader = "AWS4-HMAC-SHA256 Credential=\(config.accessKeyId)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        
        return [
            "Authorization": authHeader,
            "x-amz-date": amzDate,
            "x-amz-content-sha256": payloadHash,
            "Content-Type": contentType
        ]
    }
    
    public static func sha256Hex(_ data: Data) -> String {
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    
    private static func hmacSha256(key: Data, data: Data) -> Data {
        let symKey = SymmetricKey(data: key)
        let auth = HMAC<SHA256>.authenticationCode(for: data, using: symKey)
        return Data(auth)
    }
}
