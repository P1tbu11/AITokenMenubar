import Foundation
import WebKit

@MainActor
class QuotaService: ObservableObject {
    @Published var quotaItems: [QuotaItem] = []
    @Published var userName: String = ""
    @Published var chineseName: String = ""
    @Published var isLoading = false
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var needsAuth = false
    @Published var isChecking = true
    @Published var selectedPlatform: String = ""

    private let baseURL = "https://aitoken.woa.com"
    private var refreshTimer: Timer?
    private var authWindowController: AuthWindowController?

    nonisolated private static let cookieStorageKey = "savedCookies_v2"
    nonisolated private static let selectedPlatformKey = "selectedPlatform"

    var selectedItem: QuotaItem? {
        quotaItems.first { $0.platform == selectedPlatform }
    }

    var displayPercent: Double {
        selectedItem?.usagePercent ?? 0
    }

    init() {
        loadCookies()
        selectedPlatform = UserDefaults.standard.string(forKey: Self.selectedPlatformKey) ?? ""
        Task {
            await checkAuth()
            if isAuthenticated {
                await fetchQuota()
            } else {
                needsAuth = true
            }
            isChecking = false
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isAuthenticated else { return }
                await self.fetchQuota()
            }
        }
    }

    func switchPlatform(to platform: String) {
        selectedPlatform = platform
        UserDefaults.standard.set(platform, forKey: Self.selectedPlatformKey)
    }

    func checkAuth() async {
        do {
            var req = URLRequest(url: URL(string: "\(baseURL)/yak.base.Base/getSession")!)
            req.httpMethod = "GET"
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let httpResp = resp as? HTTPURLResponse,
               httpResp.statusCode == 200,
               httpResp.url?.host == "aitoken.woa.com" {
                isAuthenticated = true
                needsAuth = false
                return
            }
        } catch {
            print("[AIToken] checkAuth error: \(error.localizedDescription)")
        }
        isAuthenticated = false
        needsAuth = true
    }

    func fetchQuota() async {
        let savedPlatform = selectedPlatform
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let body = try JSONEncoder().encode(["platform": "", "period": ""])
            var req = URLRequest(url: URL(string: "\(baseURL)/yak.aitoken.MyQuota/GetQuota")!)
            req.httpMethod = "POST"
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(baseURL, forHTTPHeaderField: "Origin")
            req.setValue("\(baseURL)/profile/usage", forHTTPHeaderField: "Referer")
            req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            let (data, resp) = try await URLSession.shared.data(for: req)

            if let httpResp = resp as? HTTPURLResponse {
                print("[AIToken] fetchQuota status: \(httpResp.statusCode), url: \(httpResp.url?.absoluteString ?? "?")")
                if httpResp.statusCode == 401 || httpResp.statusCode == 302 {
                    isAuthenticated = false
                    needsAuth = true
                    return
                }
                if httpResp.statusCode != 200 {
                    let body = String(data: data.prefix(200), encoding: .utf8) ?? ""
                    errorMessage = "HTTP \(httpResp.statusCode): \(body)"
                    return
                }
            }

            let decoded = try JSONDecoder().decode(GetQuotaResponse.self, from: data)
            let items = decoded.data.filter { $0.quota > 0 }

            // restore previous selection, or default to first
            if !savedPlatform.isEmpty, items.contains(where: { $0.platform == savedPlatform }) {
                selectedPlatform = savedPlatform
            } else {
                selectedPlatform = items.first?.platform ?? ""
            }

            quotaItems = items
            chineseName = decoded.user?.chinese_name ?? ""
            userName = decoded.user?.username ?? ""
            lastUpdated = Date()
            isAuthenticated = true
            needsAuth = false
        } catch {
            print("[AIToken] fetchQuota error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Auth

    func showAuthWindow() {
        authWindowController = AuthWindowController { [weak self] in
            Task { @MainActor [weak self] in
                await self?.captureCookiesFromWebView()
                await self?.checkAuth()
                if self?.isAuthenticated == true {
                    self?.authWindowController?.close()
                    self?.authWindowController = nil
                    await self?.fetchQuota()
                }
            }
        }
        authWindowController?.show()
    }

    private func captureCookiesFromWebView() async {
        let cookies = await withCheckedContinuation { (continuation: CheckedContinuation<[HTTPCookie], Never>) in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }

        print("[AIToken] Captured \(cookies.count) cookies from WebView")
        for c in cookies {
            print("[AIToken]   cookie: \(c.name) domain=\(c.domain) path=\(c.path) isSessionOnly=\(c.isSessionOnly)")
            HTTPCookieStorage.shared.setCookie(c)
        }

        saveCookies(cookies)
    }

    // MARK: - Cookie persistence

    private func saveCookies(_ cookies: [HTTPCookie]) {
        let props = cookies.compactMap { $0.properties }
        UserDefaults.standard.set(props, forKey: Self.cookieStorageKey)
    }

    private func loadCookies() {
        guard let props = UserDefaults.standard.array(forKey: Self.cookieStorageKey)
                as? [[HTTPCookiePropertyKey: Any]] else { return }

        for p in props {
            if let cookie = HTTPCookie(properties: p) {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
    }

    func clearAuth() {
        UserDefaults.standard.removeObject(forKey: Self.cookieStorageKey)
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)

        let store = WKWebsiteDataStore.default()
        store.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) {}
        }

        isAuthenticated = false
        needsAuth = true
        quotaItems = []
    }
}
