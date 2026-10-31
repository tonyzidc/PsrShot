import Foundation
import UniformTypeIdentifiers

public enum ImageExportFormat: String, CaseIterable, Codable {
    case png = "PNG"
    case jpeg = "JPEG"
    case webp = "WebP"
    case heic = "HEIC"
    
    public var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .webp: return "webp"
        case .heic: return "heic"
        }
    }
    
    public var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .webp: return .webP
        case .heic: return .heic
        }
    }
    
    public var mimeType: String {
        switch self {
        case .png: return "image/png"
        case .jpeg: return "image/jpeg"
        case .webp: return "image/webp"
        case .heic: return "image/heic"
        }
    }
}

public struct ImageCompressionSettings: Codable {
    public var format: ImageExportFormat
    public var isCompressionEnabled: Bool
    public var quality: Float // 0.1 to 1.0 (default 0.8)
    
    public static let `default` = ImageCompressionSettings(
        format: .png,
        isCompressionEnabled: false,
        quality: 0.8
    )
    
    private static let userDefaultsKey = "psrshot_image_compression_settings"
    
    public static func load() -> ImageCompressionSettings {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let settings = try? JSONDecoder().decode(ImageCompressionSettings.self, from: data) else {
            return .default
        }
        return settings
    }
    
    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }
}
