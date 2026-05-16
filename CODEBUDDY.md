# CODEBUDDY.md

This file provides guidance to CodeBuddy Code when working with code in this repository.

## Project Overview

AITokenMenubar is a macOS menu bar app (Swift Package Manager, SwiftUI) that displays AI token usage quotas from `aitoken.woa.com`. It runs as an accessory app (`LSUIElement = true`) — no Dock icon, just a menu bar extra showing the current usage percentage.

## Build & Run

```bash
# Debug build
swift build

# Release build + create .app bundle
./build.sh

# Run the .app
open AITokenMenubar.app
```

`build.sh` compiles a release binary via `swift build -c release`, then assembles a minimal `.app` bundle with an `Info.plist` (bundle ID: `com.aitoken.menubar`).

There are no tests or linting configured.

## Architecture

All source lives in `Sources/AITokenMenubar/` (single executable target, macOS 13+, Swift Tools 5.9).

### File Responsibilities

| File | Role |
|---|---|
| `AITokenMenubarApp.swift` | `@main` entry point. Sets up `MenuBarExtra` with `.window` style. `AppDelegate` sets activation policy to `.accessory`. Menu bar label shows usage `%` when authenticated, else a CPU icon. |
| `QuotaService.swift` | `@MainActor ObservableObject` — the central state + networking layer. Manages auth state, cookie persistence (UserDefaults), quota fetching via POST to `/yak.aitoken.MyQuota/GetQuota`, and a 5-minute auto-refresh timer. |
| `Models.swift` | Codable data models: `QuotaItem` (per-platform quota with computed `usagePercent`, `remaining`, `statusColor`), `GetQuotaResponse`, `QuotaUser`, `GetMyProfileResponse`. |
| `ContentView.swift` | SwiftUI popover UI: header (user name + last update time), segmented platform picker, quota card with progress bar, footer (refresh / open browser / re-login / quit). |
| `AuthWindowController.swift` | Opens an `NSWindow` containing a `WKWebView` pointed at the SSO login page. On successful navigation to `/profile/usage`, triggers cookie capture back into `QuotaService`. |

### Data Flow

1. On launch, `QuotaService.init()` loads persisted cookies from UserDefaults into `HTTPCookieStorage.shared`, then calls `checkAuth()` (GET `/yak.base.Base/getSession`).
2. If authenticated, `fetchQuota()` POSTs to the API and decodes `GetQuotaResponse`. Items with `quota > 0` are kept; the previously selected platform is restored from UserDefaults.
3. If not authenticated, the UI shows a login prompt. Clicking "登录" opens `AuthWindowController`, which loads the SSO page in a WKWebView. After login completes, cookies are captured from `WKWebsiteDataStore` → `HTTPCookieStorage` → UserDefaults.
4. `displayPercent` (from `selectedItem.usagePercent`) drives the menu bar label text.
5. A `Timer` fires every 300 seconds to re-fetch quota data.

### Key Details

- **Cookie bridge**: Auth cookies must flow between WKWebView's cookie store and URLSession's `HTTPCookieStorage`. `captureCookiesFromWebView()` handles this after SSO login.
- **Platform selection**: Stored in UserDefaults under key `selectedPlatform`; survives app restarts.
- **API base URL**: `https://aitoken.woa.com` — hardcoded in `QuotaService`.
- **UI language**: Chinese (Simplified) throughout the UI strings.
