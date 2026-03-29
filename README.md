# Claro – Phone Storage Cleaner

**Claro** is a premium iOS app that keeps your iPhone fast, clean, and organized. Built with SwiftUI and designed for iOS 17+.

---

## Features

| Feature | Description |
|---|---|
| 📷 Photo Cleaner | Detects and removes duplicate, blurry, and similar photos |
| ☁️ iCloud Manager | Analyzes iCloud storage usage by category |
| 👥 Contact Cleaner | Detects and merges duplicate contacts |
| 🔒 Private Vault | Encrypted, Face ID–protected local file storage |
| 📧 Email Breach Checker | Checks if your email was exposed in a data breach |
| ⚡ Device Optimizer | Real-time health score — battery, storage, temperature, brightness |
| 🗜️ Compression | Reduces photo and video file size without visible quality loss |
| 📬 Email Cleaner | Gmail OAuth integration to bulk-delete newsletters and promotions |

---

## Tech Stack

- **Language:** Swift 5.9
- **UI:** SwiftUI (iOS 17+)
- **Architecture:** `@Observable` services injected via `@Environment`
- **IAP:** StoreKit 2 (annual, monthly, lifetime)
- **Auth:** Face ID / Touch ID via LocalAuthentication
- **Crypto:** AES-GCM encryption via CryptoKit (Private Vault)
- **Email OAuth:** Gmail REST API via ASWebAuthenticationSession (PKCE)
- **Localization:** English + Hebrew (RTL support)
- **Build system:** XcodeGen (`project.yml`)

---

## Project Structure

```
Claro/
├── App/
│   ├── ClaroApp.swift          # Entry point, service injection
│   └── MainTabView.swift       # Tab bar navigation
├── Core/
│   ├── Components/             # Shared UI components
│   ├── Models/                 # Shared data models
│   ├── Services/               # App-wide services (StoreKit, Permissions, Settings)
│   └── Theme/                  # Design tokens, colors, fonts
├── Features/
│   ├── Photos/                 # Duplicate photo detection
│   ├── iCloud/                 # iCloud storage analysis
│   ├── Contacts/               # Contact deduplication
│   ├── Vault/                  # Encrypted private vault
│   ├── Optimizer/              # Device health score + tips
│   ├── Compression/            # Photo & video compression
│   ├── EmailChecker/           # Email breach lookup
│   ├── EmailCleaner/           # Gmail bulk cleanup
│   ├── Paywall/                # App Store compliant paywall
│   ├── Settings/               # App settings
│   └── Legal/                  # Terms of Service & Privacy Policy
└── Resources/
    ├── Assets.xcassets/        # App icon, colors
    ├── en.lproj/               # English localization
    ├── he.lproj/               # Hebrew localization (RTL)
    ├── Info.plist
    └── PrivacyInfo.xcprivacy   # Apple privacy manifest
```

---

## Getting Started

### Requirements
- Xcode 15.4+
- iOS 17.0+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed

### Setup

```bash
# Clone the repo
git clone https://github.com/esamuel/Claro.git
cd Claro

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open Claro.xcodeproj
```

### Build & Run
Select a simulator or device and press `Cmd+R`.

> **Note:** Some features require a real device:
> - Face ID (Private Vault)
> - Battery monitoring (Optimizer)
> - Photo library access

---

## In-App Purchases

Three StoreKit 2 products (configured in App Store Connect):

| Product ID | Type | Price |
|---|---|---|
| `com.samueleskenasy.claro.annual` | Auto-Renewable Subscription | ₪79.90/year |
| `com.samueleskenasy.claro.monthly` | Auto-Renewable Subscription | ₪14.90/month |
| `com.samueleskenasy.claro.lifetime` | Non-Consumable | ₪149.99 |

In `DEBUG` builds, `isPro` always returns `true` so all features are accessible without a purchase.

---

## Localization

The app fully supports **English** and **Hebrew** (RTL layout).

Localization keys are in:
- `Claro/Resources/en.lproj/Localizable.strings`
- `Claro/Resources/he.lproj/Localizable.strings`

After adding new keys, run the app with the Hebrew locale to verify RTL layout.

---

## Gmail Email Cleaner Setup

The Email Cleaner uses Gmail OAuth (PKCE) without any third-party SDK. To enable it:

1. Create a project in [Google Cloud Console](https://console.cloud.google.com)
2. Enable the Gmail API
3. Create an OAuth 2.0 Client ID (iOS app type)
4. Set `kGmailClientID` and `kGmailRedirectScheme` in `EmailCleanerService.swift`
5. Add the redirect URL scheme to `project.yml` under `CFBundleURLTypes`

---

## Privacy

Claro processes all data **locally on the device**. No photos, contacts, or personal files are uploaded to any server. See the full privacy policy at [claro-ai-clean.carrd.co](https://claro-ai-clean.carrd.co).

---

## License

Private — All rights reserved © 2026 Samuel Eskenasy
