function getTranslation(key, language) {
    const translations = {
        "Network": {
            "ru": "Сеть",
            "cs": "Síť",
            "en": "Network"
        },
        "On": {
            "ru": "Вкл",
            "cs": "Zapnuto",
            "en": "On"
        },
        "Off": {
            "ru": "Выкл",
            "cs": "Vypnuto",
            "en": "Off"
        },
        "Not Connected": {
            "ru": "Не подключено",
            "cs": "Nepřipojeno",
            "en": "Not Connected"
        },
        "Bluetooth": {
            "ru": "Bluetooth",
            "cs": "Bluetooth",
            "en": "Bluetooth"
        },
        "Screenshot": {
            "ru": "Снимок экрана",
            "cs": "Snímek obrazovky",
            "en": "Screenshot"
        },
        "Night Light": {
            "ru": "Ночной режим",
            "cs": "Noční osvětlení",
            "en": "Night Light"
        },
        "Unmute": {
            "ru": "Включить звук",
            "cs": "Zapnout zvuk",
            "en": "Unmute"
        },
        "Mute": {
            "ru": "Выключить звук",
            "cs": "Ztlumit zvuk",
            "en": "Mute"
        },
        "Terminal": {
            "ru": "Терминал",
            "cs": "Terminál",
            "en": "Terminal"
        },
        "No media playing": {
            "ru": "Ничего не воспроизводится...",
            "cs": "Žádné přehrávání médií...",
            "en": "No media playing..."
        }
    };
    
    return translations[key]?.[language] || translations[key]?.["en"] || key;
}