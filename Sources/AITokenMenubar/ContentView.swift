import SwiftUI

struct ContentView: View {
    @ObservedObject var service: QuotaService

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            if service.isChecking {
                placeholder(text: "检查登录状态...")
            } else if service.needsAuth && !service.isAuthenticated {
                loginPrompt
            } else if service.isLoading, service.quotaItems.isEmpty {
                placeholder(text: "加载中...")
            } else if let error = service.errorMessage, service.quotaItems.isEmpty {
                errorView(error)
            } else if let item = service.selectedItem {
                platformPicker
                quotaCard(item)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            } else {
                placeholder(text: "暂无数据")
            }

            Divider()
            footerSection
        }
        .frame(width: 250)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 4) {
            if !service.chineseName.isEmpty {
                Text(service.chineseName)
                    .font(.system(size: 12, weight: .semibold))
                Text(service.userName)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } else {
                Text("AI Token")
                    .font(.system(size: 12, weight: .semibold))
            }

            if service.isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 10, height: 10)
            }

            Spacer()

            if let updated = service.lastUpdated {
                Text(formattedTime(updated))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    // MARK: - Platform Picker

    private var platformPicker: some View {
        Picker("平台", selection: Binding(
            get: { service.selectedPlatform },
            set: { service.switchPlatform(to: $0) }
        )) {
            ForEach(service.quotaItems) { item in
                Text(item.platform_label).tag(item.platform)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: - Quota Card

    private func quotaCard(_ item: QuotaItem) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "$%.2f", item.usage))
                        .font(.system(size: 28, weight: .thin, design: .monospaced))
                    Text("已用 / 总额 $\(String(format: "%.0f", item.quota))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(String(format: "%.1f%%", item.usagePercent))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(barColor(for: item.usagePercent))
            }

            // progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 4)

                    Capsule()
                        .fill(barColor(for: item.usagePercent))
                        .frame(width: max(geo.size.width * item.usagePercent / 100, 4), height: 4)
                }
            }
            .frame(height: 4)

            HStack {
                Text("剩余")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("$\(String(format: "%.2f", item.remaining))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func barColor(for percent: Double) -> Color {
        if percent < 70 {
            Color.accentColor
        } else if percent < 90 {
            Color.orange
        } else {
            Color.red
        }
    }

    // MARK: - States

    private var loginPrompt: some View {
        VStack(spacing: 8) {
            Text("需要登录")
                .font(.system(size: 12, weight: .medium))
            Text("通过 SSO 登录以查看 Token 用量")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button {
                service.showAuthWindow()
            } label: {
                Text("登录")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 100)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 36)
    }

    private func placeholder(text: String) -> some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.5)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 36)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Text("加载失败")
                .font(.system(size: 12, weight: .medium))
            Text(msg)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 12)

            Button("重试") {
                Task { await service.fetchQuota() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 28)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 6) {
            if service.isAuthenticated {
                Button {
                    Task { await service.fetchQuota() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain)

                Button {
                    NSWorkspace.shared.open(URL(string: "https://aitoken.woa.com/profile/usage")!)
                } label: {
                    Image(systemName: "safari")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    service.clearAuth()
                } label: {
                    Text("重登")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("退出")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
