# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the iOS companion app for [project-resonance](https://github.com/minc-nice-100/project-resonance).

- **Bundle ID**: `app.lovable.projectresonance`
- **Platform**: iOS 15.0+
- **Framework**: UIKit with WKWebView

## Relationship with Main Project

The iOS app is designed to work alongside the main project-resonance monorepo:

```
project-resonance/
├── frontend/          # Capacitor React app (web + mobile)
├── worker/           # Cloudflare Workers API
│   └── src/
│       ├── handlers/  # API handlers (audio, asr, tts, logs, corpus)
│       └── services/ # COSYVOICE, WHISPER, MINIO VPC services
└── server/           # Go backend
```

### API Endpoints (from worker)
- `POST /api/audio/upload` - Audio file upload
- `POST /api/asr/jobs` - ASR job submission
- `POST /api/tts/jobs` - TTS job submission
- `POST /api/tts/voice-clone` - Voice cloning
- `GET /api/health` - Health check

### WebView Target
The WebView loads the frontend from the Capacitor build (`frontend/dist`), which is served via Cloudflare Workers.

## Build Commands

Since XcodeGen is not available on Windows (only macOS binaries provided), the project is structured for manual Xcode project creation or CI/CD with macOS runners.

### macOS Build (XcodeGen required)
```bash
xcodegen generate
xcodebuild -project Resonance.xcodeproj -scheme Resonance -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### GitHub Actions CI/CD
- **CI**: Pushes to `master`/`release` trigger automatic build
- **Release**: Manual workflow dispatch for IPA generation

## Architecture

### DNS Resolution Module (`Resonance/Modules/DNS/`)
- **DNSResolver.swift**: Core resolver with SRV/TXT lookup and fallback logic
- **HTTPDNSClient.swift**: HTTP DNS client supporting Cloudflare, Google, and domestic DNS servers
- **TLSDNSClient.swift**: DNS-over-TLS (DoT) client for secure DNS queries
- **DNSSECValidator.swift**: DNSSEC signature validation

### DNS Fallback Strategy
- **Domestic (China)**: HTTP DNS (primary) → TLS DNS (fallback) → Local DNS (final)
- **International**: Cloudflare HTTP DNS (1.1.1.1) → Google HTTP DNS (8.8.8.8) → Local DNS

### WebView Module (`Resonance/Modules/WebView/`)
- **MainWebViewController.swift**: WKWebView-based browser with JavaScript bridge
- Custom URL scheme handler (`resonance://`) for native interop
- Progress tracking and error handling

### Local Model Module (`Resonance/Modules/LocalModel/`)
- **LocalModelController.swift**: Model management UI with chat interface
- **ModelManager.swift**: Model download and storage management
- **ChatViewModel.swift**: Chat logic with local inference support
- Architecture supports CoreML, Metal Performance Shaders, and Transformers.js

### Services (`Resonance/Services/`)
- **ConfigurationService.swift**: Endpoint configuration caching
- **EndpointDiscovery.swift**: DNS-based service discovery coordinator

## Key Files
- `project.yml`: XcodeGen configuration
- `SPEC.md`: Full project specification
- `Resonance/App/AppDelegate.swift`: App entry point
- `Resonance/App/SceneDelegate.swift`: Scene management and tab bar setup

## Dependencies (SPM)
- DnsKit: DNS resolution utilities
- KeychainAccess: Secure storage
- SnapKit: Auto Layout DSL

##姊妹项目
- [project-resonance](https://github.com/minc-nice-100/project-resonance) - 主项目(前端+Worker API+Go后端)
