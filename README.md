# KDE Material Quick Settings

A ChromeOS-inspired Quick Settings Menu for KDE Plasma 6, designed to provide a modern and functional alternative to the default system tray experience.

You know how it goes - I was using KDE Plasma 6 and really missed having a slick quick settings menu. Looked around but couldn't find anything that hit the spot. So I thought "hey, why not make one myself?" And here we are! Built this to be super clean and easy to use, with all the controls you need right at your fingertips.

![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-KDE%20Plasma%206-blue.svg)
![License](https://img.shields.io/badge/license-GPL--3.0-green.svg)

## 🌟 Features

- Modern Material Design-inspired interface
- Media player controls with seek functionality
- Volume and brightness controls
- WiFi and Bluetooth toggles
- Night Light mode
- Screenshot tool
- Terminal launcher with multiple terminal support
- Power management controls
- Multi-language support (English, Russian, Czech)

## 📋 Requirements

- KDE Plasma 6
- Qt 6
- The following packages:
  - `wireplumber` (for volume control)
  - `brightnessctl` (for brightness control)
  - Optional terminals:
    - `konsole` (default)
    - `kitty`
    - `waveterm`


## ⚠️ Known Issues

1. Night Light Toggle:
   - The Night Light status might not always sync correctly with system state
   - Sometimes requires manual toggle to match system state
   - Might need multiple clicks to activate/deactivate

2. Volume/Brightness Sliders:
   - Occasional desync with system values
   - Might not always reflect external changes immediately
   - May require manual adjustment to sync

## 🤝 Contributing

Feel free to contribute to this project! Whether it's:
- Reporting bugs
- Suggesting new features
- Improving documentation
- Submitting pull requests

All contributions are welcome!

## ⭐ Support

If you find this widget useful, please consider giving it a star on GitHub! Your support helps make this project better and motivates further development.

## 📄 License

This project is licensed under the GPL-3.0 License.