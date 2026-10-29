import AppKit

/// ノッチ付きディスプレイの検出。
///
/// 内蔵ディスプレイにノッチがあると、メニューバー右側のステータスアイコンがノッチの陰へ
/// 回り込んで操作不能になることがある（本アプリの ⌘ 起動リセットはその救済策）。
/// この判定を使い、ノッチ環境では表示モード「メニューバーのみ」を無効化する。
enum NotchDetector {

    /// いま接続中のいずれかの画面にノッチがあるか。
    ///
    /// - `safeAreaInsets.top > 0` … ノッチ／カメラハウジングのぶんだけ非ゼロになる。
    ///   外部ディスプレイや旧来の内蔵ディスプレイは 0 を返すため、ノッチ固有の信号として使える。
    /// - `auxiliaryTopLeftArea != nil` … ノッチ左右の領域を返す macOS 12+ の専用 API。ノッチが
    ///   無ければ nil。片方でも成立すればノッチありとみなす（取りこぼし防止）。
    /// - クラムシェル（蓋を閉じ外部ディスプレイのみ）では内蔵画面が `NSScreen.screens` に
    ///   含まれず false になる。この状態ではノッチの陰問題が起きないため、望ましい判定と一致する。
    static var hasNotchedDisplay: Bool {
        NSScreen.screens.contains { $0.hasNotch }
    }
}

extension NSScreen {
    /// この画面にノッチがあるか（macOS 13.5 以降が対象なので API 可用性ガードは不要）。
    var hasNotch: Bool {
        safeAreaInsets.top > 0 || auxiliaryTopLeftArea != nil
    }
}
