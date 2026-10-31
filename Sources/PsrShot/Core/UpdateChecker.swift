import Foundation

// MARK: - Models

public struct GitHubRelease: Decodable {
    public let tagName: String
    public let name: String?
    public let htmlUrl: String
    public let body: String?
    public let publishedAt: String?
    public let assets: [GitHubReleaseAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlUrl = "html_url"
        case body
        case publishedAt = "published_at"
        case assets
    }
}

public struct GitHubReleaseAsset: Decodable {
    public let name: String
    public let browserDownloadUrl: String
    public let size: Int?
    public let contentType: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
        case contentType = "content_type"
    }
}

public struct GitHubRepoInfo: Decodable {
    public let name: String
    public let fullName: String
    public let description: String?
    public let htmlUrl: String
    public let stargazersCount: Int?
    public let forksCount: Int?
    public let openIssuesCount: Int?
    public let license: GitHubLicense?
    
    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case description
        case htmlUrl = "html_url"
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case license
    }
}

public struct GitHubLicense: Decodable {
    public let name: String?
    public let spdxId: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case spdxId = "spdx_id"
    }
}

public enum UpdateCheckResult {
    case updateAvailable(latest: GitHubRelease, currentVersion: String)
    case upToDate(currentVersion: String)
    case skippedRecentlyChecked
}

public enum UpdateCheckerError: LocalizedError {
    case invalidURL
    case rateLimitExceeded
    case invalidResponse(statusCode: Int)
    case noReleaseFound
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitHub API URL."
        case .rateLimitExceeded:
            return "GitHub API rate limit exceeded. Please try again later."
        case .invalidResponse(let statusCode):
            return "GitHub API returned HTTP \(statusCode)."
        case .noReleaseFound:
            return "No releases found for this repository."
        }
    }
}

// MARK: - UpdateChecker

public final class UpdateChecker {
    public static let shared = UpdateChecker()
    
    public let repoOwner = "tonyzidc"
    public let repoName = "PsrShot"
    
    private let session: URLSession
    private let userDefaults: UserDefaults
    
    // UserDefaults Keys
    public static let autoCheckKey = "psrshot_auto_check_updates"
    public static let lastCheckKey = "psrshot_last_update_check_time"
    
    public var autoCheckOnLaunch: Bool {
        get {
            // Default to true if not set
            if userDefaults.object(forKey: Self.autoCheckKey) == nil {
                return true
            }
            return userDefaults.bool(forKey: Self.autoCheckKey)
        }
        set {
            userDefaults.set(newValue, forKey: Self.autoCheckKey)
        }
    }
    
    public var currentVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    public var currentBuild: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    public var repoWebURL: URL {
        return URL(string: "https://github.com/\(repoOwner)/\(repoName)")!
    }
    
    public var releasesWebURL: URL {
        return URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases")!
    }
    
    public init(session: URLSession = .shared, userDefaults: UserDefaults = .standard) {
        self.session = session
        self.userDefaults = userDefaults
    }
    
    /// Checks for updates against GitHub Releases.
    /// - Parameters:
    ///   - isUserInitiated: If false, checks can be throttled (e.g. skip if checked within 15 minutes).
    ///   - completion: Callback with result.
    public func checkForUpdates(
        isUserInitiated: Bool,
        completion: @escaping (Result<UpdateCheckResult, Error>) -> Void
    ) {
        if !isUserInitiated {
            guard autoCheckOnLaunch else {
                completion(.success(.skippedRecentlyChecked))
                return
            }
            
            // Check throttle: 15 minutes minimum between automatic startup checks
            let lastCheck = userDefaults.double(forKey: Self.lastCheckKey)
            let now = Date().timeIntervalSince1970
            if lastCheck > 0 && (now - lastCheck) < (15 * 60) {
                completion(.success(.skippedRecentlyChecked))
                return
            }
        }
        
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            completion(.failure(UpdateCheckerError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("PsrShot/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(UpdateCheckerError.invalidResponse(statusCode: 0)))
                }
                return
            }
            
            if httpResponse.statusCode == 403 || httpResponse.statusCode == 429 {
                DispatchQueue.main.async {
                    completion(.failure(UpdateCheckerError.rateLimitExceeded))
                }
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async {
                    completion(.failure(UpdateCheckerError.invalidResponse(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(UpdateCheckerError.noReleaseFound))
                }
                return
            }
            
            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                self.userDefaults.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)
                
                let curVerStr = self.currentVersion
                let curSem = SemanticVersion(curVerStr) ?? SemanticVersion(major: 1, minor: 0, patch: 0)
                let remoteSem = SemanticVersion(release.tagName) ?? SemanticVersion(major: 0, minor: 0, patch: 0)
                
                DispatchQueue.main.async {
                    if remoteSem > curSem {
                        completion(.success(.updateAvailable(latest: release, currentVersion: curVerStr)))
                    } else {
                        completion(.success(.upToDate(currentVersion: curVerStr)))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        task.resume()
    }
    
    /// Fetches repository metadata from GitHub.
    public func fetchRepositoryInfo(completion: @escaping (Result<GitHubRepoInfo, Error>) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)") else {
            completion(.failure(UpdateCheckerError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("PsrShot/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(UpdateCheckerError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)))
                }
                return
            }
            
            do {
                let repoInfo = try JSONDecoder().decode(GitHubRepoInfo.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(repoInfo))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        task.resume()
    }
}
