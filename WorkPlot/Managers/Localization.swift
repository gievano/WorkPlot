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
            "fields.openEditor": "View Field Editor"
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
            "fields.openEditor": "Buka Field Editor"
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
            "fields.openEditor": "打开字段编辑器"
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
            "fields.openEditor": "フィールドエディタを開く"
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
            "fields.openEditor": "Открыть редактор полей"
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
            "fields.openEditor": "Mở trình soạn thảo trường"
        ]
    ]
}
