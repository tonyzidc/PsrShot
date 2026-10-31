import Cocoa

public final class AboutWindowController: NSWindowController {
    public static let shared = AboutWindowController()
    
    // UI Elements
    private let iconImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "PsrShot")
    private let versionLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(labelWithString: "")
    
    // GitHub Info Box
    private let githubBox = NSBox()
    private let githubRepoButton = NSButton()
    private let githubMetaLabel = NSTextField(labelWithString: "")
    
    // Update Checker UI
    private let updateStatusLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private let checkUpdatesButton = NSButton()
    private let downloadUpdateButton = NSButton()
    
    // State
    private var latestReleaseURL: URL?
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About PsrShot"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        
        // Refresh version & fetch live repo metadata
        refreshAppVersionInfo()
        loadGitHubMetadata()
    }
    
    // MARK: - View Layout
    
    private func setupViews() {
        guard let contentView = window?.contentView else { return }
        
        // App Icon
        iconImageView.frame = NSRect(x: (440 - 64) / 2, y: 330, width: 64, height: 64)
        if let appIcon = NSApp.applicationIconImage, appIcon.isValid {
            iconImageView.image = appIcon
        } else if let iconImg = NSImage(named: "AppIcon") {
            iconImageView.image = iconImg
        } else if let sfImg = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "PsrShot") {
            let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
            iconImageView.image = sfImg.withSymbolConfiguration(config)
        }
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(iconImageView)
        
        // Title
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 20, y: 298, width: 400, height: 26)
        contentView.addSubview(titleLabel)
        
        // Version
        versionLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        versionLabel.frame = NSRect(x: 20, y: 278, width: 400, height: 18)
        contentView.addSubview(versionLabel)
        
        // Description
        descriptionLabel.font = NSFont.systemFont(ofSize: 12)
        descriptionLabel.textColor = .labelColor
        descriptionLabel.alignment = .center
        descriptionLabel.maximumNumberOfLines = 3
        descriptionLabel.cell?.wraps = true
        descriptionLabel.stringValue = "Ultra-lightweight native macOS screenshot & annotation tool.\nBuilt natively with Swift & AppKit with zero external dependencies."
        descriptionLabel.frame = NSRect(x: 30, y: 232, width: 380, height: 38)
        contentView.addSubview(descriptionLabel)
        
        // GitHub Info Box
        githubBox.title = "Project & Open Source"
        githubBox.boxType = .primary
        githubBox.frame = NSRect(x: 20, y: 128, width: 400, height: 96)
        contentView.addSubview(githubBox)
        
        setupGitHubBoxContent()
        
        // Progress Spinner
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.frame = NSRect(x: 24, y: 78, width: 16, height: 16)
        contentView.addSubview(progressIndicator)
        
        // Update Status Label
        updateStatusLabel.font = NSFont.systemFont(ofSize: 11)
        updateStatusLabel.textColor = .secondaryLabelColor
        updateStatusLabel.stringValue = "Click below to check for new releases."
        updateStatusLabel.frame = NSRect(x: 46, y: 76, width: 374, height: 20)
        contentView.addSubview(updateStatusLabel)
        
        // Action Buttons Row
        checkUpdatesButton.title = "Check for Updates"
        checkUpdatesButton.bezelStyle = .rounded
        checkUpdatesButton.target = self
        checkUpdatesButton.action = #selector(checkUpdatesClicked)
        checkUpdatesButton.frame = NSRect(x: 20, y: 30, width: 150, height: 32)
        contentView.addSubview(checkUpdatesButton)
        
        downloadUpdateButton.title = "Download Update"
        downloadUpdateButton.bezelStyle = .rounded
        downloadUpdateButton.target = self
        downloadUpdateButton.action = #selector(downloadUpdateClicked)
        downloadUpdateButton.frame = NSRect(x: 176, y: 30, width: 140, height: 32)
        downloadUpdateButton.isHidden = true
        contentView.addSubview(downloadUpdateButton)
        
        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeClicked))
        closeButton.bezelStyle = .rounded
        closeButton.frame = NSRect(x: 322, y: 30, width: 98, height: 32)
        contentView.addSubview(closeButton)
        
        // Copyright
        let copyrightLabel = NSTextField(labelWithString: "MIT License • Created by tonyzidc")
        copyrightLabel.font = NSFont.systemFont(ofSize: 10)
        copyrightLabel.textColor = .tertiaryLabelColor
        copyrightLabel.alignment = .center
        copyrightLabel.frame = NSRect(x: 20, y: 8, width: 400, height: 16)
        contentView.addSubview(copyrightLabel)
        
        refreshAppVersionInfo()
    }
    
    private func setupGitHubBoxContent() {
        let boxView = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 74))
        
        githubRepoButton.title = "GitHub: tonyzidc/PsrShot"
        githubRepoButton.bezelStyle = .inline
        githubRepoButton.isBordered = false
        githubRepoButton.contentTintColor = .linkColor
        githubRepoButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        githubRepoButton.target = self
        githubRepoButton.action = #selector(openGitHubClicked)
        githubRepoButton.frame = NSRect(x: 12, y: 44, width: 356, height: 20)
        boxView.addSubview(githubRepoButton)
        
        githubMetaLabel.font = NSFont.systemFont(ofSize: 11)
        githubMetaLabel.textColor = .secondaryLabelColor
        githubMetaLabel.stringValue = "Repository: https://github.com/tonyzidc/PsrShot\nLicense: MIT License"
        githubMetaLabel.maximumNumberOfLines = 2
        githubMetaLabel.frame = NSRect(x: 12, y: 6, width: 356, height: 34)
        boxView.addSubview(githubMetaLabel)
        
        githubBox.contentView = boxView
    }
    
    private func refreshAppVersionInfo() {
        let version = UpdateChecker.shared.currentVersion
        let build = UpdateChecker.shared.currentBuild
        versionLabel.stringValue = "Version \(version) (Build \(build))"
    }
    
    // MARK: - Actions
    
    @objc private func openGitHubClicked() {
        NSWorkspace.shared.open(UpdateChecker.shared.repoWebURL)
    }
    
    @objc private func closeClicked() {
        window?.close()
    }
    
    @objc private func downloadUpdateClicked() {
        let url = latestReleaseURL ?? UpdateChecker.shared.releasesWebURL
        NSWorkspace.shared.open(url)
    }
    
    @objc public func checkUpdatesClicked() {
        progressIndicator.startAnimation(nil)
        progressIndicator.frame.origin.x = 24
        updateStatusLabel.frame.origin.x = 46
        updateStatusLabel.textColor = .secondaryLabelColor
        updateStatusLabel.stringValue = "Checking GitHub for updates..."
        checkUpdatesButton.isEnabled = false
        downloadUpdateButton.isHidden = true
        
        UpdateChecker.shared.checkForUpdates(isUserInitiated: true) { [weak self] result in
            guard let self = self else { return }
            self.progressIndicator.stopAnimation(nil)
            self.checkUpdatesButton.isEnabled = true
            self.progressIndicator.frame.origin.x = 24
            
            switch result {
            case .success(let checkResult):
                switch checkResult {
                case .updateAvailable(let release, let currentVersion):
                    self.latestReleaseURL = URL(string: release.htmlUrl)
                    self.updateStatusLabel.textColor = .systemGreen
                    self.updateStatusLabel.stringValue = "🎉 New version \(release.tagName) available! (Current: \(currentVersion))"
                    self.downloadUpdateButton.title = "Download \(release.tagName)"
                    self.downloadUpdateButton.isHidden = false
                    
                case .upToDate(let currentVersion):
                    self.updateStatusLabel.textColor = .secondaryLabelColor
                    self.updateStatusLabel.stringValue = "✅ PsrShot v\(currentVersion) is currently the newest version."
                    self.downloadUpdateButton.isHidden = true
                    
                case .skippedRecentlyChecked:
                    self.updateStatusLabel.textColor = .secondaryLabelColor
                    self.updateStatusLabel.stringValue = "Checked recently. Up to date."
                }
                
            case .failure(let error):
                self.updateStatusLabel.textColor = .systemRed
                self.updateStatusLabel.stringValue = "❌ Error: \(error.localizedDescription)"
                self.downloadUpdateButton.isHidden = true
            }
        }
    }
    
    private func loadGitHubMetadata() {
        UpdateChecker.shared.fetchRepositoryInfo { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let info):
                var meta = "GitHub Stars: \(info.stargazersCount ?? 0) ★"
                if let lic = info.license?.name {
                    meta += " • License: \(lic)"
                }
                if let desc = info.description, !desc.isEmpty {
                    self.descriptionLabel.stringValue = desc
                }
                self.githubMetaLabel.stringValue = "Repository: \(info.htmlUrl)\n\(meta)"
            case .failure:
                // Keep default metadata on failure
                break
            }
        }
    }
}
