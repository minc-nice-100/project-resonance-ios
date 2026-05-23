# Resonance iOS App Specification

## 1. Project Overview

- **Project Name**: Resonance
- **Bundle Identifier**: net.projectresonance.app
- **Core Functionality**: iOS app with WebView-based UI loading project-resonance.net, with intelligent DNS resolution for finding backend services and local LLM model execution capability.
- **Target Users**: Users requiring secure, privacy-preserving AI interactions with fallback to local models
- **iOS Version**: iOS 15.0+
- **UI Framework**: UIKit with WKWebView

## 2. DNS Resolution Architecture

### 2.1 SRV Record Based Discovery
- Query SRV record for `_resonance._tcp.project-resonance.net` to get endpoint base
- Fallback to TXT record lookup if SRV fails

### 2.2 TXT Record Resolution
- Query TXT record to find JSON configuration file URL
- JSON file contains network interface definitions and API endpoints

### 2.3 DNS Fallback Strategy

#### Domestic (China)
1. HTTP DNS (DNSSEC-compatible) - Primary
2. TLS DNS - Fallback
3. Local DNS (system resolver) - Final fallback

#### International
1. Cloudflare HTTP DNS (1.1.1.1) - Primary
2. Google HTTP DNS (8.8.8.8) - Secondary
3. Local DNS (system resolver) - Final fallback

### 2.4 Supported DNS Services
- HTTP DNS: `https://cloudflare-dns.com/dns-query`
- TLS DNS: `https://dns.google/dns-query` (DoT)
- Local DNS: System resolver via `resolv.conf`

## 3. UI/UX Specification

### 3.1 Screen Structure
1. **SplashScreen**: App launch with logo animation
2. **MainWebViewController**: Primary WKWebView loading project-resonance.net
3. **LocalModelController**: Local model management and chat interface
4. **SettingsController**: App settings and DNS configuration

### 3.2 Navigation Structure
- UITabBarController with 3 tabs:
  - Web (MainWebViewController)
  - Local (LocalModelController)
  - Settings (SettingsController)

### 3.3 Visual Design
- **Primary Color**: #007AFF (iOS Blue)
- **Secondary Color**: #5856D6 (Purple)
- **Background**: #F2F2F7 (Light Gray)
- **Dark Background**: #1C1C1E
- **Text Primary**: #000000 / #FFFFFF (dark mode)
- **Text Secondary**: #8E8E93
- **Tab Bar**: White/Dark gray with blur effect
- **Navigation Bar**: Large title style

### 3.4 Typography
- **Title**: SF Pro Display, 34pt Bold
- **Headline**: SF Pro Display, 17pt Semibold
- **Body**: SF Pro Text, 17pt Regular
- **Caption**: SF Pro Text, 12pt Regular

### 3.5 Spacing
- 8pt grid system
- Standard margins: 16pt
- Section spacing: 24pt
- Cell padding: 12pt vertical, 16pt horizontal

## 4. Functionality Specification

### 4.1 Core Features

#### DNS Resolution Module
- SRV record querying viadns library
- TXT record resolution
- HTTP DNS with DNSSEC validation
- TLS DNS (DoT) support
- Automatic fallback logic based on region
- Response caching (5 minute TTL)

#### WebView Module
- WKWebView with custom WKURLSchemeHandler for local assets
- JavaScript interop for native functionality
- Cookie persistence
- Error handling with retry logic
- Offline capability detection

#### Local Model Module
- LLM interface using CoreML where available
- Model download management
- Chat interface for local inference
- Support for transformers.js or similar WASM-based models

### 4.2 Data Handling
- UserDefaults for settings and preferences
- FileManager for model storage
- URLSession for network requests
- Keychain for sensitive data

### 4.3 Architecture Pattern
- **MVVM** with Coordinators for navigation
- Protocol-oriented design for testability
- Combine for reactive bindings

## 5. Technical Specification

### 5.1 Dependencies (Swift Package Manager)
- **DnsKit**: DNS resolution (SRV/TXT/HTTP DNS)
- **MistralSDK/MobileCoreML**: Local model inference (optional)
- **Alamofire**: Networking (if needed beyond URLSession)
- **KeychainAccess**: Secure storage

### 5.2 Project Structure
```
Resonance/
├── App/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   └── Info.plist
├── Modules/
│   ├── DNS/
│   │   ├── DNSResolver.swift
│   │   ├── HTTPDNSClient.swift
│   │   ├── TLS DNSClient.swift
│   │   └── DNSSECValidator.swift
│   ├── WebView/
│   │   ├── MainWebViewController.swift
│   │   ├── WebViewCoordinator.swift
│   │   └── URLSchemeHandler.swift
│   ├── LocalModel/
│   │   ├── LocalModelController.swift
│   │   ├── ModelManager.swift
│   │   └── ChatViewModel.swift
│   └── Settings/
│       ├── SettingsController.swift
│       └── SettingsViewModel.swift
├── Services/
│   ├── EndpointDiscovery.swift
│   └── ConfigurationService.swift
├── Common/
│   ├── Extensions/
│   ├── Protocols/
│   └── Utilities/
└── Resources/
    ├── Assets.xcassets
    └── LaunchScreen.storyboard
```

### 5.3 Info.plist Requirements
- `NSAppTransportSecurity`: Allow arbitrary loads for WebView
- `UIBackgroundModes`: (none required)
- `CFBundleURLTypes`: Custom URL scheme `resonance://`

### 5.4 Capabilities
- App Groups (for shared container)
- Keychain Sharing

## 6. Configuration JSON Schema

The JSON file found via TXT record should follow this schema:

```json
{
  "version": "1.0",
  "endpoints": {
    "api": "https://api.project-resonance.net",
    "ws": "wss://ws.project-resonance.net"
  },
  "features": {
    "localModel": true,
    "voiceSupport": false
  },
  "model": {
    "defaultModel": "resonance-7b",
    "availableModels": ["resonance-7b", "resonance-3b"]
  }
}
```

## 7. Error Handling

### Network Errors
- Timeout: 10 seconds for HTTP DNS, 15 seconds for TLS DNS
- Retry: 3 attempts with exponential backoff
- Fallback: Automatic fallback to next DNS method

### WebView Errors
- Load failure: Show error page with retry button
- JavaScript errors: Log and continue

### Local Model Errors
- Model not found: Prompt to download
- Inference failure: Show error with retry option
