import SwiftUI
import ServiceManagement

/// 設定ウインドウ。SwiftUI の標準フォーム（`Form`＋`.formStyle(.grouped)`）＝白い地に薄いグレーの角丸カード。
/// macOS 26 でウインドウの地がほぼ白になり、旧来のフラットレイアウト（区切り線で分ける）ではまとまりが
/// 分からなくなったため、OS 純正の設定画面と同じ部品へ移した
/// （共有資料「設定ウインドウ_macOS26のカード型レイアウト.md」・ステップ4）。
/// カードは上から「ログイン時に起動」／「表示モード」／「機能」（クリーンペーストの組と、全体表示・ズームの2枚）。オン／オフはスイッチ。
/// 項目は1画面に収まるのでスクロールを止め、内容の高さをそのままウインドウの高さにする。
struct SettingsView: View {
    static let width: CGFloat = 400

    var body: some View {
        Form {
            LaunchAtLoginSettingsView()
            DisplayModeSettingsView()
            FeaturesSettingsView()
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - ログイン時に起動

struct LaunchAtLoginSettingsView: View {
    @State private var launchAtLogin = (SMAppService.mainApp.status == .enabled)

    var body: some View {
        Section {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in setLaunchAtLogin(newValue) }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        // 失敗して元の値へ戻したときの再入を避ける
        guard enabled != (SMAppService.mainApp.status == .enabled) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("[FILL Id] Failed to change login item: %@", error.localizedDescription)
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }
}

// MARK: - 表示モード

struct DisplayModeSettingsView: View {
    @AppStorage(DisplayModeStore.key) private var rawMode: String = DisplayModeStore.defaultValue.rawValue
    /// ノッチ付きディスプレイがあるか。ディスプレイ構成の変化に追従して更新する。
    @State private var hasNotch = NotchDetector.hasNotchedDisplay

    private var displayMode: Binding<DisplayMode> {
        Binding(
            get: {
                let stored = DisplayMode(rawValue: rawMode) ?? DisplayModeStore.defaultValue
                // ノッチ環境では「メニューバーのみ」を選べない → 実効モード（両方表示）を選択表示する。
                if stored == .menuBar && hasNotch { return DisplayModeStore.defaultValue }
                return stored
            },
            set: { newValue in
                rawMode = newValue.rawValue
                NotificationCenter.default.post(name: .displayModeChanged, object: nil)
            }
        )
    }

    var body: some View {
        // ラジオはボタンがラベルの左に縦並び（システム設定と同じ）。1つのカード行にまとめる。
        // Picker(.radioGroup) は1項目だけ .disabled にしても文字が薄くならないので、自前の RadioRow を使う。
        Section("Display Mode") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(DisplayMode.allCases) { mode in
                    // ノッチ環境では「メニューバーのみ」を無効化（アイコンがノッチの陰に隠れるため）。
                    RadioRow(title: mode.label,
                             isSelected: displayMode.wrappedValue == mode,
                             isDisabled: mode == .menuBar && hasNotch) {
                        displayMode.wrappedValue = mode
                    }
                }
            }

            if hasNotch {
                Text("“Menu Bar Only” is unavailable on this Mac because the built-in display has a notch, where the menu bar icon could become hidden.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // ⌘ キーを押しながら起動して表示モードを戻す注記は画面から外した（ヘルプの「ヒント」に記載。ステップ4）
        }
        // ディスプレイ構成が変わったらノッチ判定を更新（メニューバーのみの有効/無効に反映）。
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            hasNotch = NotchDetector.hasNotchedDisplay
        }
    }
}

/// ラジオ1行。ボタン（円）をラベルの左に置く。無効時はグレーアウトして選択不可にする。
private struct RadioRow: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                Text(title)
                    .foregroundStyle(.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)   // .plain スタイルは自動で薄くならないため明示的にグレーアウト
    }
}

// MARK: - 機能

/// ホットキー機能の個別 ON/OFF。
/// 見出し「機能」の下にカードを2枚並べる。1枚目はクリーンペーストとその従属設定（字下げ）、2枚目は全体表示とズーム。
/// 従属設定を他の機能と同列の行にすると、クリーンペーストの設定だと伝わらないため（ユーザー指摘 2026-11-10）。
struct FeaturesSettingsView: View {
    @AppStorage(PrefKey.textPaste) private var textPaste = true
    @AppStorage(PrefKey.viewFit)   private var viewFit = true
    @AppStorage(PrefKey.zoom)      private var zoom = true
    @AppStorage(PrefKey.pasteFlash) private var pasteFlash = true

    var body: some View {
        Section("Features") {
            Toggle("Clean paste (⌥V / ⌥⇧V)", isOn: $textPaste)
                .onChange(of: textPaste) { _ in postPrefsChanged() }
            // クリーンペーストの従属設定。字下げして示す。クリーンペーストが OFF のときは無効
            Toggle("Briefly dim the screen on paste", isOn: $pasteFlash)
                .padding(.leading, 20)
                .disabled(!textPaste)
        }
        Section {
            Toggle("Fit page / spread (⌘0 / ⌥⌘0)", isOn: $viewFit)
                .onChange(of: viewFit) { _ in postPrefsChanged() }
            Toggle("Zoom in / out (⌘± / ⇧⌘±)", isOn: $zoom)
                .onChange(of: zoom) { _ in postPrefsChanged() }
        }
    }

    private func postPrefsChanged() {
        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
    }
}
