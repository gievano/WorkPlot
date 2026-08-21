//
//  Localization.swift
//  WorkPlot
//
//  In-app language switcher (EN/ID/ZH/JA/RU/VI) and appearance preference.
//  Falls back to English when a key is missing in the selected language.
//

import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case indonesian
    case chinese
    case japanese
    case russian
    case vietnamese

    var id: String { rawValue }

    var label: String {
        switch self {
        case .english: "English"
        case .indonesian: "Bahasa Indonesia"
        case .chinese: "中文"
        case .japanese: "日本語"
        case .russian: "Русский"
        case .vietnamese: "Tiếng Việt"
        }
    }

    var stringsCode: String {
        switch self {
        case .chinese: "zh-Hans"
        default: rawValue
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var labelKey: String {
        switch self {
        case .system: "appearance.system"
        case .light: "appearance.light"
        case .dark: "appearance.dark"
        }
    }
}

final class L10n: ObservableObject {
    static let shared = L10n()
    private static let storageKey = "appLanguage"

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey) }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        language = AppLanguage(rawValue: raw ?? "") ?? .indonesian
    }

    func tr(_ key: String) -> String {
        // Primary source: WorkPlot/Resources/<lang>.lproj/Localizable.strings
        if let path = Bundle.main.path(forResource: language.stringsCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let localized = bundle.localizedString(forKey: key, value: nil, table: nil)
            if localized != key { return localized }
        }
        // Fallback until the resource bundles are verified on-device.
        return Self.table[language]?[key] ?? Self.table[.english]?[key] ?? key
    }

    private static let table: [AppLanguage: [String: String]] = [
        .english: [
            "tab.status": "Status",
            "tab.gestalt": "Gestalt",
            "tab.fields": "Fields",
            "tab.siriai": "Siri AI",
            "tab.liquidglass": "Liquid Glass",
            "tab.posterboard": "PosterBoard",
            "tab.backups": "Backups",
            "settings.title": "Settings",
            "settings.language": "Language",
            "settings.appearance": "Appearance",
            "appearance.system": "System",
            "appearance.light": "Light",
            "appearance.dark": "Dark",
            "siriai.title": "Siri AI Tweaks",
            "siriai.toggle": "Enable New Siri AI (CacheData)",
            "siriai.toggle.detail": "Patches the CacheData blob automatically (Toto method).",
            "siriai.spoof": "Spoof Device to:",
            "siriai.spoof.none": "No Spoofing",
            "siriai.warning": "Spoofing may break Face ID. Use at your own risk.",
            "siriai.ai.toggle": "Enable Apple Intelligence",
            "siriai.apply": "Apply Changes",
            "siriai.restart.title": "Restart Required",
            "siriai.restart.message": "The new Siri AI becomes active after the device restarts.",
            "siriai.restart.respring": "Respring",
            "siriai.restart.later": "Later",
            "posterboard.import": "Import .tendies Wallpaper",
            "fields.openEditor": "View Field Editor",
            "credits.disclaimer": "This app uses sandbox escape & bad_query (github.com/forcequitOS/bad_query).",
            "common.done": "Done",
            "credits.header": "Credits",
            "credits.owner": "Owner",
            "credits.projects": "Projects",
            "credits.thanks": "Special Thanks",
            "credits.exploit.detail": "Exploit - bad_query by forcequitOS",
            "credits.sandbox.detail": "iOS 27 Sandbox Escape (MCM bug class)",
            "home.info": "System Information",
            "icon.menu": "App Icon",
            "icon.confirm.title": "Change App Icon?",
            "icon.confirm.change": "Change",
            "icon.confirm.message": "iOS applies the new icon immediately and relaunches the app.",
            "pb.installed": "Installed Wallpapers",
            "pb.empty": "No wallpapers installed yet.",
            "pb.apply": "Apply",
            "pb.remove": "Remove",
            "pb.remove.confirm": "Remove this wallpaper?",
            "pb.wrongext": "Only .tendies files are supported.",
            "restart.rec.title": "Restart Recommended",
            "restart.rec.message": "Changes take effect after a respring. You can respring later from the Home tab.",
            "status.checkaccess": "Check System Access",
            "status.rdarfix": "Fix RDAR",
            "status.lg.disable": "Disable Liquid Glass",
            "status.respring.refresh": "Respring (Refresh UI)",
            "tab.files": "Files",
            "tab.home": "Home",
            "tab.more": "More",
            "preset.title": "Preset Lab",
            "preset.footer": "A preset writes a fixed set of MobileGestalt CacheExtra keys in one pass. A backup is created automatically before each apply.",
            "preset.builtinHeader": "Built-in Presets",
            "preset.userHeader": "My Presets",
            "preset.userEmpty": "No presets yet. Import a .json preset file or open a workplot://preset link.",
            "preset.author": "by %@",
            "preset.keysCount": "%d keys",
            "preset.applyFailed": "Failed to apply preset.",
            "preset.importFile": "Import Preset File...",
            "preset.importOk": "Preset imported: %@.",
            "preset.importFail": "Failed to import preset.",
            "preset.confirm.title": "Apply Risky Preset?",
            "preset.confirm.message": "This preset changes identity-related keys and can break Face ID or other services. A backup is created before applying."
        ],
        .indonesian: [
            "tab.status": "Status",
            "tab.gestalt": "Gestalt",
            "tab.fields": "Fields",
            "tab.siriai": "Siri AI",
            "tab.liquidglass": "Liquid Glass",
            "tab.posterboard": "PosterBoard",
            "tab.backups": "Backups",
            "settings.title": "Pengaturan",
            "settings.language": "Bahasa",
            "settings.appearance": "Tampilan",
            "appearance.system": "Sistem",
            "appearance.light": "Terang",
            "appearance.dark": "Gelap",
            "siriai.title": "Siri AI Tweaks",
            "siriai.toggle": "Aktifkan Siri AI Baru (CacheData)",
            "siriai.toggle.detail": "Patch blob CacheData otomatis (metode Toto).",
            "siriai.spoof": "Spoof Device ke:",
            "siriai.spoof.none": "Tanpa Spoofing",
            "siriai.warning": "Spoofing dapat merusak Face ID. Gunakan dengan risiko sendiri.",
            "siriai.ai.toggle": "Aktifkan Apple Intelligence",
            "siriai.apply": "Apply Changes",
            "siriai.restart.title": "Restart Diperlukan",
            "siriai.restart.message": "Siri AI baru aktif setelah perangkat direstart.",
            "siriai.restart.respring": "Respring",
            "siriai.restart.later": "Nanti",
            "posterboard.import": "Impor Wallpaper .tendies",
            "fields.openEditor": "Buka Field Editor",
            "common.done": "Selesai",
            "credits.header": "Kredit",
            "credits.owner": "Pemilik",
            "credits.projects": "Proyek",
            "credits.thanks": "Terima Kasih Khusus",
            "credits.exploit.detail": "Exploit - bad_query oleh forcequitOS",
            "credits.sandbox.detail": "iOS 27 Sandbox Escape (kelas bug MCM)",
            "home.info": "Informasi Sistem",
            "icon.menu": "Icon Aplikasi",
            "icon.confirm.title": "Ganti Icon Aplikasi?",
            "icon.confirm.change": "Ganti",
            "icon.confirm.message": "iOS langsung menerapkan icon baru dan me-restart aplikasi.",
            "pb.installed": "Wallpaper Terpasang",
            "pb.empty": "Belum ada wallpaper terpasang.",
            "pb.apply": "Terapkan",
            "pb.remove": "Hapus",
            "pb.remove.confirm": "Hapus wallpaper ini?",
            "pb.wrongext": "Hanya file .tendies yang didukung.",
            "restart.rec.title": "Restart Disarankan",
            "restart.rec.message": "Perubahan aktif setelah respring. Bisa respring nanti dari tab Home.",
            "status.checkaccess": "Periksa Akses Sistem",
            "status.rdarfix": "Perbaiki RDAR",
            "status.lg.disable": "Matikan Liquid Glass",
            "status.respring.refresh": "Respring (Segarkan UI)",
            "tab.files": "File",
            "tab.home": "Home",
            "tab.more": "Lainnya",
            "preset.title": "Preset Lab",
            "preset.footer": "Preset menulis sekumpulan key CacheExtra MobileGestalt sekaligus. Backup dibuat otomatis sebelum setiap penerapan.",
            "preset.builtinHeader": "Preset Bawaan",
            "preset.userHeader": "Preset Saya",
            "preset.userEmpty": "Belum ada preset. Impor file preset .json atau buka link workplot://preset.",
            "preset.author": "oleh %@",
            "preset.keysCount": "%d key",
            "preset.applyFailed": "Gagal menerapkan preset.",
            "preset.importFile": "Impor File Preset...",
            "preset.importOk": "Preset diimpor: %@.",
            "preset.importFail": "Gagal mengimpor preset.",
            "preset.confirm.title": "Terapkan Preset Berisiko?",
            "preset.confirm.message": "Preset ini mengubah key identitas perangkat dan bisa merusak Face ID atau layanan lain. Backup dibuat sebelum diterapkan."
        ],
        .chinese: [
            "tab.status": "状态",
            "tab.gestalt": "Gestalt",
            "tab.fields": "字段",
            "tab.siriai": "Siri AI",
            "tab.liquidglass": "液态玻璃",
            "tab.posterboard": "海报板",
            "tab.backups": "备份",
            "settings.title": "设置",
            "settings.language": "语言",
            "settings.appearance": "外观",
            "appearance.system": "跟随系统",
            "appearance.light": "浅色",
            "appearance.dark": "深色",
            "siriai.title": "Siri AI 调整",
            "siriai.toggle": "启用新版 Siri AI (CacheData)",
            "siriai.toggle.detail": "自动修改 CacheData 数据块（Toto 方法）。",
            "siriai.spoof": "伪装设备为：",
            "siriai.spoof.none": "不伪装",
            "siriai.warning": "伪装可能导致面容 ID 失效，风险自负。",
            "siriai.ai.toggle": "启用 Apple 智能",
            "siriai.apply": "应用更改",
            "siriai.restart.title": "需要重新启动",
            "siriai.restart.message": "新版 Siri AI 将在设备重新启动后生效。",
            "siriai.restart.respring": "Respring",
            "siriai.restart.later": "稍后",
            "posterboard.import": "导入 .tendies 壁纸",
            "fields.openEditor": "打开字段编辑器",
            "common.done": "完成",
            "credits.header": "致谢",
            "credits.owner": "所有者",
            "credits.projects": "项目",
            "credits.thanks": "特别感谢",
            "credits.exploit.detail": "漏洞 - forcequitOS 的 bad_query",
            "credits.sandbox.detail": "iOS 27 沙盒逃逸（MCM 漏洞类）",
            "home.info": "系统信息",
            "icon.menu": "应用图标",
            "icon.confirm.title": "更换应用图标？",
            "icon.confirm.change": "更换",
            "icon.confirm.message": "iOS 将立即应用新图标并重启应用。",
            "pb.installed": "已安装壁纸",
            "pb.empty": "尚未安装壁纸。",
            "pb.apply": "应用",
            "pb.remove": "移除",
            "pb.remove.confirm": "移除此壁纸？",
            "pb.wrongext": "仅支持 .tendies 文件。",
            "restart.rec.title": "建议重启",
            "restart.rec.message": "更改将在 Respring 后生效。可稍后在主页标签中执行。",
            "status.checkaccess": "检查系统访问",
            "status.rdarfix": "修复 RDAR",
            "status.lg.disable": "关闭 Liquid Glass",
            "status.respring.refresh": "Respring（刷新界面）",
            "tab.files": "文件",
            "tab.home": "主页",
            "tab.more": "更多",
            "preset.title": "预设实验室",
            "preset.footer": "预设会一次性写入一组 MobileGestalt CacheExtra 键。每次应用前都会自动创建备份。",
            "preset.builtinHeader": "内置预设",
            "preset.userHeader": "我的预设",
            "preset.userEmpty": "暂无预设。导入 .json 预设文件或打开 workplot://preset 链接。",
            "preset.author": "作者：%@",
            "preset.keysCount": "%d 个键",
            "preset.applyFailed": "应用预设失败。",
            "preset.importFile": "导入预设文件...",
            "preset.importOk": "预设已导入：%@。",
            "preset.importFail": "导入预设失败。",
            "preset.confirm.title": "应用高风险预设？",
            "preset.confirm.message": "该预设会修改设备标识相关的键，可能导致面容 ID 或其他服务失效。应用前会先创建备份。"
        ],
        .japanese: [
            "tab.status": "ステータス",
            "tab.gestalt": "Gestalt",
            "tab.fields": "フィールド",
            "tab.siriai": "Siri AI",
            "tab.liquidglass": "リキッドグラス",
            "tab.posterboard": "ポスターボード",
            "tab.backups": "バックアップ",
            "settings.title": "設定",
            "settings.language": "言語",
            "settings.appearance": "外観",
            "appearance.system": "システムに従う",
            "appearance.light": "ライト",
            "appearance.dark": "ダーク",
            "siriai.title": "Siri AI 設定",
            "siriai.toggle": "新しい Siri AI を有効化 (CacheData)",
            "siriai.toggle.detail": "CacheData を自動でパッチします（Toto 方式）。",
            "siriai.spoof": "デバイスの偽装先:",
            "siriai.spoof.none": "偽装しない",
            "siriai.warning": "偽装により Face ID が動作しなくなる可能性があります。自己責任でお願いします。",
            "siriai.ai.toggle": "Apple Intelligence を有効化",
            "siriai.apply": "変更を適用",
            "siriai.restart.title": "再起動が必要です",
            "siriai.restart.message": "新しい Siri AI はデバイスの再起動後に有効になります。",
            "siriai.restart.respring": "Respring",
            "siriai.restart.later": "後で",
            "posterboard.import": ".tendies 壁紙を読み込む",
            "fields.openEditor": "フィールドエディタを開く",
            "common.done": "完了",
            "credits.header": "クレジット",
            "credits.owner": "オーナー",
            "credits.projects": "プロジェクト",
            "credits.thanks": "スペシャルサンクス",
            "credits.exploit.detail": "エクスプロイト - forcequitOS の bad_query",
            "credits.sandbox.detail": "iOS 27 サンドボックス脱出（MCM バグクラス）",
            "home.info": "システム情報",
            "icon.menu": "アプリアイコン",
            "icon.confirm.title": "アプリアイコンを変更しますか？",
            "icon.confirm.change": "変更",
            "icon.confirm.message": "iOS は新しいアイコンを即座に適用し、アプリを再起動します。",
            "pb.installed": "インストール済み壁紙",
            "pb.empty": "壁紙はまだありません。",
            "pb.apply": "適用",
            "pb.remove": "削除",
            "pb.remove.confirm": "この壁紙を削除しますか？",
            "pb.wrongext": ".tendies ファイルのみ対応しています。",
            "restart.rec.title": "再起動推奨",
            "restart.rec.message": "変更は Respring 後に有効になります。後でホームタブから実行できます。",
            "status.checkaccess": "システムアクセスを確認",
            "status.rdarfix": "RDAR を修正",
            "status.lg.disable": "Liquid Glass を無効化",
            "status.respring.refresh": "Respring（UI 更新）",
            "tab.files": "ファイル",
            "tab.home": "ホーム",
            "tab.more": "その他",
            "preset.title": "プリセットラボ",
            "preset.footer": "プリセットは MobileGestalt の CacheExtra キー群を一括で書き込みます。適用前に自動でバックアップが作成されます。",
            "preset.builtinHeader": "内蔵プリセット",
            "preset.userHeader": "マイプリセット",
            "preset.userEmpty": "プリセットはまだありません。.json プリセットファイルを読み込むか、workplot://preset リンクを開いてください。",
            "preset.author": "作成者: %@",
            "preset.keysCount": "%d 個のキー",
            "preset.applyFailed": "プリセットの適用に失敗しました。",
            "preset.importFile": "プリセットファイルを読み込む...",
            "preset.importOk": "プリセットをインポートしました: %@。",
            "preset.importFail": "プリセットのインポートに失敗しました。",
            "preset.confirm.title": "危険なプリセットを適用しますか？",
            "preset.confirm.message": "このプリセットは識別情報関連のキーを変更するため、Face ID などが動作しなくなる可能性があります。適用前にバックアップを作成します。"
        ],
        .russian: [
            "tab.status": "Статус",
            "tab.gestalt": "Gestalt",
            "tab.fields": "Поля",
            "tab.siriai": "Siri AI",
            "tab.liquidglass": "Liquid Glass",
            "tab.posterboard": "PosterBoard",
            "tab.backups": "Резервные копии",
            "settings.title": "Настройки",
            "settings.language": "Язык",
            "settings.appearance": "Оформление",
            "appearance.system": "Системная",
            "appearance.light": "Светлая",
            "appearance.dark": "Тёмная",
            "siriai.title": "Настройки Siri AI",
            "siriai.toggle": "Включить новый Siri AI (CacheData)",
            "siriai.toggle.detail": "Автоматически изменяет блок CacheData (метод Toto).",
            "siriai.spoof": "Подменить устройство на:",
            "siriai.spoof.none": "Без подмены",
            "siriai.warning": "Подмена может сломать Face ID. Используйте на свой риск.",
            "siriai.ai.toggle": "Включить Apple Intelligence",
            "siriai.apply": "Применить изменения",
            "siriai.restart.title": "Требуется перезагрузка",
            "siriai.restart.message": "Новый Siri AI активируется после перезагрузки устройства.",
            "siriai.restart.respring": "Respring",
            "siriai.restart.later": "Позже",
            "posterboard.import": "Импортировать обои .tendies",
            "fields.openEditor": "Открыть редактор полей",
            "common.done": "Готово",
            "credits.header": "Авторы",
            "credits.owner": "Владельцы",
            "credits.projects": "Проекты",
            "credits.thanks": "Особая благодарность",
            "credits.exploit.detail": "Эксплойт - bad_query от forcequitOS",
            "credits.sandbox.detail": "Побег из песочницы iOS 27 (класс багов MCM)",
            "home.info": "Информация о системе",
            "icon.menu": "Иконка приложения",
            "icon.confirm.title": "Сменить иконку приложения?",
            "icon.confirm.change": "Сменить",
            "icon.confirm.message": "iOS сразу применит новую иконку и перезапустит приложение.",
            "pb.installed": "Установленные обои",
            "pb.empty": "Обои пока не установлены.",
            "pb.apply": "Применить",
            "pb.remove": "Удалить",
            "pb.remove.confirm": "Удалить эти обои?",
            "pb.wrongext": "Поддерживаются только файлы .tendies.",
            "restart.rec.title": "Рекомендуется перезапуск",
            "restart.rec.message": "Изменения вступят в силу после respring. Можно позже на вкладке Главная.",
            "status.checkaccess": "Проверить доступ к системе",
            "status.rdarfix": "Исправить RDAR",
            "status.lg.disable": "Отключить Liquid Glass",
            "status.respring.refresh": "Respring (обновить интерфейс)",
            "tab.files": "Файлы",
            "tab.home": "Главная",
            "tab.more": "Ещё",
            "preset.title": "Лаборатория пресетов",
            "preset.footer": "Пресет записывает набор ключей CacheExtra MobileGestalt за один проход. Перед каждым применением создаётся резервная копия.",
            "preset.builtinHeader": "Встроенные пресеты",
            "preset.userHeader": "Мои пресеты",
            "preset.userEmpty": "Пресетов пока нет. Импортируйте файл пресета .json или откройте ссылку workplot://preset.",
            "preset.author": "автор: %@",
            "preset.keysCount": "Ключей: %d",
            "preset.applyFailed": "Не удалось применить пресет.",
            "preset.importFile": "Импортировать файл пресета...",
            "preset.importOk": "Пресет импортирован: %@.",
            "preset.importFail": "Не удалось импортировать пресет.",
            "preset.confirm.title": "Применить рискованный пресет?",
            "preset.confirm.message": "Этот пресет меняет ключи идентификации устройства и может сломать Face ID и другие сервисы. Перед применением создаётся резервная копия."
        ],
        .vietnamese: [
            "tab.status": "Trạng thái",
            "tab.gestalt": "Gestalt",
            "tab.fields": "Trường dữ liệu",
            "tab.siriai": "Siri AI",
            "tab.liquidglass": "Liquid Glass",
            "tab.posterboard": "PosterBoard",
            "tab.backups": "Sao lưu",
            "settings.title": "Cài đặt",
            "settings.language": "Ngôn ngữ",
            "settings.appearance": "Giao diện",
            "appearance.system": "Theo hệ thống",
            "appearance.light": "Sáng",
            "appearance.dark": "Tối",
            "siriai.title": "Tinh chỉnh Siri AI",
            "siriai.toggle": "Bật Siri AI mới (CacheData)",
            "siriai.toggle.detail": "Tự động vá khối CacheData (phương pháp Toto).",
            "siriai.spoof": "Giả lập thiết bị thành:",
            "siriai.spoof.none": "Không giả lập",
            "siriai.warning": "Việc giả lập có thể làm hỏng Face ID. Hãy tự chịu rủi ro.",
                    "siriai.ai.toggle": "Bật Apple Intelligence",
            "siriai.apply": "Áp dụng thay đổi",
            "siriai.restart.title": "Cần khởi động lại",
            "siriai.restart.message": "Siri AI mới sẽ hoạt động sau khi khởi động lại thiết bị.",
            "siriai.restart.respring": "Respring",
            "siriai.restart.later": "Để sau",
            "posterboard.import": "Nhập hình nền .tendies",
            "fields.openEditor": "Mở trình soạn thảo trường",
            "common.done": "Xong",
            "credits.header": "Ghi công",
            "credits.owner": "Chủ sở hữu",
            "credits.projects": "Dự án",
            "credits.thanks": "Cảm ơn đặc biệt",
            "credits.exploit.detail": "Khai thác - bad_query bởi forcequitOS",
            "credits.sandbox.detail": "Thoát sandbox iOS 27 (lỗi lớp MCM)",
            "home.info": "Thông tin hệ thống",
            "icon.menu": "Biểu tượng ứng dụng",
            "icon.confirm.title": "Đổi biểu tượng ứng dụng?",
            "icon.confirm.change": "Đổi",
            "icon.confirm.message": "iOS sẽ áp dụng biểu tượng mới ngay lập tức và khởi động lại ứng dụng.",
            "pb.installed": "Hình nền đã cài",
            "pb.empty": "Chưa có hình nền nào.",
            "pb.apply": "Áp dụng",
            "pb.remove": "Xóa",
            "pb.remove.confirm": "Xóa hình nền này?",
            "pb.wrongext": "Chỉ hỗ trợ tệp .tendies.",
            "restart.rec.title": "Nên khởi động lại",
            "restart.rec.message": "Thay đổi có hiệu lực sau khi respring. Có thể làm sau ở tab Trang chủ.",
            "status.checkaccess": "Kiểm tra quyền truy cập hệ thống",
            "status.rdarfix": "Sửa RDAR",
            "status.lg.disable": "Tắt Liquid Glass",
            "status.respring.refresh": "Respring (làm mới giao diện)",
            "tab.files": "Tệp",
            "tab.home": "Trang chủ",
            "tab.more": "Khác",
            "preset.title": "Thư viện Preset",
            "preset.footer": "Preset ghi một bộ khóa CacheExtra của MobileGestalt trong một lần. Bản sao lưu được tạo tự động trước mỗi lần áp dụng.",
            "preset.builtinHeader": "Preset có sẵn",
            "preset.userHeader": "Preset của tôi",
            "preset.userEmpty": "Chưa có preset nào. Nhập tệp preset .json hoặc mở liên kết workplot://preset.",
            "preset.author": "bởi %@",
            "preset.keysCount": "%d khóa",
            "preset.applyFailed": "Không thể áp dụng preset.",
            "preset.importFile": "Nhập tệp preset...",
            "preset.importOk": "Đã nhập preset: %@.",
            "preset.importFail": "Không thể nhập preset.",
            "preset.confirm.title": "Áp dụng preset rủi ro?",
            "preset.confirm.message": "Preset này thay đổi các khóa định danh thiết bị và có thể làm hỏng Face ID hoặc dịch vụ khác. Bản sao lưu sẽ được tạo trước khi áp dụng."
        ]
    ]
}

