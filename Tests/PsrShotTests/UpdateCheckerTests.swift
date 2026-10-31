import XCTest
import Foundation
@testable import PsrShot

final class UpdateCheckerTests: XCTestCase {
    
    func testSemanticVersionParsing() {
        let v1 = SemanticVersion("1.0.0")
        XCTAssertNotNil(v1)
        XCTAssertEqual(v1?.major, 1)
        XCTAssertEqual(v1?.minor, 0)
        XCTAssertEqual(v1?.patch, 0)
        XCTAssertNil(v1?.prerelease)
        XCTAssertEqual(v1?.description, "1.0.0")
        
        let v2 = SemanticVersion("v1.2.3")
        XCTAssertNotNil(v2)
        XCTAssertEqual(v2?.major, 1)
        XCTAssertEqual(v2?.minor, 2)
        XCTAssertEqual(v2?.patch, 3)
        XCTAssertEqual(v2?.description, "1.2.3")
        
        let vShort = SemanticVersion("2.5")
        XCTAssertNotNil(vShort)
        XCTAssertEqual(vShort?.major, 2)
        XCTAssertEqual(vShort?.minor, 5)
        XCTAssertEqual(vShort?.patch, 0)
        
        let vSingle = SemanticVersion("v3")
        XCTAssertNotNil(vSingle)
        XCTAssertEqual(vSingle?.major, 3)
        XCTAssertEqual(vSingle?.minor, 0)
        XCTAssertEqual(vSingle?.patch, 0)
        
        let vPre = SemanticVersion("v1.0.0-rc.1")
        XCTAssertNotNil(vPre)
        XCTAssertEqual(vPre?.major, 1)
        XCTAssertEqual(vPre?.minor, 0)
        XCTAssertEqual(vPre?.patch, 0)
        XCTAssertEqual(vPre?.prerelease, "rc.1")
        XCTAssertEqual(vPre?.description, "1.0.0-rc.1")
        
        let vInvalid = SemanticVersion("not_a_version")
        XCTAssertNil(vInvalid)
    }
    
    func testSemanticVersionComparison() {
        let v100 = SemanticVersion("1.0.0")!
        let v101 = SemanticVersion("1.0.1")!
        let v110 = SemanticVersion("1.1.0")!
        let v200 = SemanticVersion("2.0.0")!
        let v100v = SemanticVersion("v1.0.0")!
        let v100rc = SemanticVersion("1.0.0-rc.1")!
        
        XCTAssertTrue(v101 > v100)
        XCTAssertTrue(v110 > v101)
        XCTAssertTrue(v200 > v110)
        XCTAssertTrue(v100 == v100v)
        XCTAssertFalse(v100 < v100v)
        XCTAssertTrue(v100 > v100rc)
    }
    
    func testGitHubReleaseJSONDecoding() throws {
        let json = """
        {
          "tag_name": "v1.0.1",
          "name": "v1.0.1",
          "html_url": "https://github.com/tonyzidc/PsrShot/releases/tag/v1.0.1",
          "body": "Full Changelog: https://github.com/tonyzidc/PsrShot/compare/v1.0.0...v1.0.1",
          "published_at": "2026-10-31T08:28:51Z",
          "assets": [
            {
              "name": "PsrShot.dmg",
              "browser_download_url": "https://github.com/tonyzidc/PsrShot/releases/download/v1.0.1/PsrShot.dmg",
              "size": 1611965,
              "content_type": "application/x-apple-diskimage"
            },
            {
              "name": "PsrShot-macOS.zip",
              "browser_download_url": "https://github.com/tonyzidc/PsrShot/releases/download/v1.0.1/PsrShot-macOS.zip",
              "size": 1164468,
              "content_type": "application/zip"
            }
          ]
        }
        """.data(using: .utf8)!
        
        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        XCTAssertEqual(release.tagName, "v1.0.1")
        XCTAssertEqual(release.name, "v1.0.1")
        XCTAssertEqual(release.htmlUrl, "https://github.com/tonyzidc/PsrShot/releases/tag/v1.0.1")
        XCTAssertEqual(release.assets.count, 2)
        XCTAssertEqual(release.assets[0].name, "PsrShot.dmg")
        XCTAssertEqual(release.assets[0].browserDownloadUrl, "https://github.com/tonyzidc/PsrShot/releases/download/v1.0.1/PsrShot.dmg")
        XCTAssertEqual(release.assets[0].size, 1611965)
    }
    
    func testGitHubRepoInfoJSONDecoding() throws {
        let json = """
        {
          "name": "PsrShot",
          "full_name": "tonyzidc/PsrShot",
          "description": "Ultra-lightweight native macOS screenshot tool",
          "html_url": "https://github.com/tonyzidc/PsrShot",
          "stargazers_count": 42,
          "forks_count": 3,
          "open_issues_count": 0,
          "license": {
            "name": "MIT License",
            "spdx_id": "MIT"
          }
        }
        """.data(using: .utf8)!
        
        let repo = try JSONDecoder().decode(GitHubRepoInfo.self, from: json)
        XCTAssertEqual(repo.name, "PsrShot")
        XCTAssertEqual(repo.fullName, "tonyzidc/PsrShot")
        XCTAssertEqual(repo.description, "Ultra-lightweight native macOS screenshot tool")
        XCTAssertEqual(repo.htmlUrl, "https://github.com/tonyzidc/PsrShot")
        XCTAssertEqual(repo.stargazersCount, 42)
        XCTAssertEqual(repo.license?.name, "MIT License")
        XCTAssertEqual(repo.license?.spdxId, "MIT")
    }
    
    func testUpdateCheckerSettings() {
        let testDefaults = UserDefaults(suiteName: "test_update_checker_\(UUID().uuidString)")!
        let checker = UpdateChecker(userDefaults: testDefaults)
        
        // Default should be true
        XCTAssertTrue(checker.autoCheckOnLaunch)
        
        checker.autoCheckOnLaunch = false
        XCTAssertFalse(checker.autoCheckOnLaunch)
        
        checker.autoCheckOnLaunch = true
        XCTAssertTrue(checker.autoCheckOnLaunch)
        
        XCTAssertEqual(checker.repoOwner, "tonyzidc")
        XCTAssertEqual(checker.repoName, "PsrShot")
        XCTAssertEqual(checker.repoWebURL.absoluteString, "https://github.com/tonyzidc/PsrShot")
        XCTAssertEqual(checker.releasesWebURL.absoluteString, "https://github.com/tonyzidc/PsrShot/releases")
    }
    
    func testUpdateCheckerErrorDescriptions() {
        XCTAssertEqual(UpdateCheckerError.invalidURL.errorDescription, "Invalid GitHub API URL.")
        XCTAssertEqual(UpdateCheckerError.rateLimitExceeded.errorDescription, "GitHub API rate limit exceeded. Please try again later.")
        XCTAssertEqual(UpdateCheckerError.invalidResponse(statusCode: 404).errorDescription, "GitHub API returned HTTP 404.")
        XCTAssertEqual(UpdateCheckerError.noReleaseFound.errorDescription, "No releases found for this repository.")
    }
}
