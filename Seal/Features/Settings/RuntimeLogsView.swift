import SwiftUI
import UIKit

struct RuntimeLogsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var confirmsClear = false
    @State private var copied = false
    @State private var isSharing = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                actionCard
                if viewModel.logs.isEmpty {
                    emptyCard
                } else {
                    logCard
                }
            }
            .padding(20)
        }
        .navigationTitle("运行日志")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.reloadLogs() }
        .refreshable { await viewModel.reloadLogs() }
        .confirmationDialog(
            "清除全部运行日志？",
            isPresented: $confirmsClear,
            titleVisibility: .visible
        ) {
            Button("清除日志", role: .destructive) {
                Task { await viewModel.clearLogs() }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("只会清除诊断日志，不会删除 Apple ID、证书、配对文件或已导入 IPA。")
        }
        .overlay(alignment: .bottom) {
            if copied {
                Text("日志已复制")
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .sheet(isPresented: $isSharing) {
            LegacyActivityShareSheet(activityItems: [viewModel.logExportText])
        }
        .sealScreenBackground()
    }

    private var actionCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = viewModel.logExportText
                    withAnimation { copied = true }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        await MainActor.run { withAnimation { copied = false } }
                    }
                } label: {
                    Label("复制日志", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .sealPrimaryAction(cornerRadius: 12)
                .disabled(viewModel.logExportText.isEmpty)

                Button {
                    isSharing = true
                } label: {
                    Label("分享日志", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .sealOutlineAction(cornerRadius: 12)
                .disabled(viewModel.logExportText.isEmpty)
            }

            Button(role: .destructive) {
                confirmsClear = true
            } label: {
                Label("清除日志", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .sealOutlineAction(cornerRadius: 12)
            .disabled(viewModel.logs.isEmpty)
        }
        .padding(16)
        .glassSurface(cornerRadius: 18)
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Color.sealTextSecondary)
            Text("暂无运行日志")
                .font(.headline)
            Text("Apple ID、签名、续签、安装与设备连接过程中的诊断信息会显示在这里。敏感凭据会自动脱敏。")
                .font(.footnote)
                .foregroundStyle(Color.sealTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .glassSurface(cornerRadius: 18)
    }

    private var logCard: some View {
        LazyVStack(spacing: 10) {
            ForEach(viewModel.logs) { entry in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.sealTextSecondary)
                        Spacer()
                        Text(levelTitle(entry.level))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(levelColor(entry.level))
                    }

                    HStack(spacing: 6) {
                        Text(categoryTitle(entry.category))
                            .font(.caption.weight(.semibold))
                        if let code = entry.code, !code.isEmpty {
                            Text(code)
                                .font(.caption.monospaced())
                                .foregroundStyle(Color.sealTextSecondary)
                        }
                    }

                    Text(entry.message)
                        .font(.footnote)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(Color.sealSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.sealHairline.opacity(0.55), lineWidth: 0.8)
                }
            }
        }
    }

    private func categoryTitle(_ category: SealLogEntry.Category) -> String {
        switch category {
        case .account: return "Apple ID"
        case .pairing: return "配对"
        case .signing: return "签名"
        case .installation: return "安装"
        case .renewal: return "续签"
        case .system: return "系统"
        }
    }

    private func levelTitle(_ level: SealLogEntry.Level) -> String {
        switch level {
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        }
    }

    private func levelColor(_ level: SealLogEntry.Level) -> Color {
        switch level {
        case .info: return .sealAccent
        case .warning: return .orange
        case .error: return .red
        }
    }
}
