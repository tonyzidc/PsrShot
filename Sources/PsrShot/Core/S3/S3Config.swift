import Foundation

public struct S3Config: Codable, Equatable {
    public var endpoint: String
    public var region: String
    public var bucket: String
    public var accessKeyId: String
    public var secretAccessKey: String
    public var publicBaseURL: String
    public var pathPrefix: String
    public var autoUpload: Bool
    
    public init(
        endpoint: String = "",
        region: String = "us-east-1",
        bucket: String = "",
        accessKeyId: String = "",
        secretAccessKey: String = "",
        publicBaseURL: String = "",
        pathPrefix: String = "screenshots/",
        autoUpload: Bool = false
    ) {
        self.endpoint = endpoint
        self.region = region
        self.bucket = bucket
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
        self.publicBaseURL = publicBaseURL
        self.pathPrefix = pathPrefix
        self.autoUpload = autoUpload
    }
    
    public var isConfigured: Bool {
        return !bucket.trimmingCharacters(in: .whitespaces).isEmpty &&
               !accessKeyId.trimmingCharacters(in: .whitespaces).isEmpty &&
               !secretAccessKey.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private static let userDefaultsKey = "psrshot_s3_storage_configuration"
    
    public static func load() -> S3Config {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let config = try? JSONDecoder().decode(S3Config.self, from: data) else {
            return S3Config()
        }
        return config
    }
    
    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }
}
