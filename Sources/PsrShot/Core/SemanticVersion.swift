import Foundation

/// Lightweight Semantic Versioning representation (Major.Minor.Patch)
public struct SemanticVersion: Comparable, Equatable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: String?
    
    public var description: String {
        let base = "\(major).\(minor).\(patch)"
        if let prerelease = prerelease, !prerelease.isEmpty {
            return "\(base)-\(prerelease)"
        }
        return base
    }
    
    public init(major: Int, minor: Int, patch: Int, prerelease: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
    }
    
    public init?(_ versionString: String) {
        var clean = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.lowercased().hasPrefix("v") {
            clean = String(clean.dropFirst())
        }
        
        let prereleaseParts = clean.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let mainPart = String(prereleaseParts[0])
        let prereleasePart = prereleaseParts.count > 1 ? String(prereleaseParts[1]) : nil
        
        let components = mainPart.split(separator: ".").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard !components.isEmpty else { return nil }
        
        self.major = components.count > 0 ? components[0] : 0
        self.minor = components.count > 1 ? components[1] : 0
        self.patch = components.count > 2 ? components[2] : 0
        self.prerelease = prereleasePart
    }
    
    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        if lhs.patch != rhs.patch {
            return lhs.patch < rhs.patch
        }
        // If versions are equal, a version without prerelease tag is higher than one with prerelease tag
        if lhs.prerelease == nil && rhs.prerelease != nil {
            return false
        }
        if lhs.prerelease != nil && rhs.prerelease == nil {
            return true
        }
        if let lp = lhs.prerelease, let rp = rhs.prerelease {
            return lp < rp
        }
        return false
    }
    
    public static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        return lhs.major == rhs.major &&
               lhs.minor == rhs.minor &&
               lhs.patch == rhs.patch &&
               lhs.prerelease == rhs.prerelease
    }
}
