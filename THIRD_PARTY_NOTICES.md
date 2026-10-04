# 来源与许可说明 / Source and license notices

## LifeLedger

- Original project: https://github.com/mrlingan/LifeLedger
- Source revision used for the port: `fd3829b`.
- Copyright (c) 2026 mrlingan.
- License: MIT; the full notice is retained in [LICENSE](LICENSE).
- Reused material: preset achievement JSON, English catalog translations adapted from Android resources, the completion sound, and product/data-format conventions.
- This repository implements a separate native SwiftUI application and keeps the Android backup import format for migration.

## EarthOnline-Achievement

- Project: https://github.com/LKlingkong/EarthOnline-Achievement
- The upstream README declares MIT licensing.
- Achievement titles, descriptions, stories, categories, and completion-rate data are incorporated through LifeLedger's preset catalog. The iOS application retains the 109-entry LifeLedger dataset and derives five rarity tiers from its rates.
- Attribution to LKlingkong and the upstream project is retained here and in the READMEs.

## Apple frameworks and system artwork

The app uses SwiftUI, UIKit, Charts, PhotosUI, AVKit, CryptoKit, Security, LocalAuthentication, UserNotifications, system symbols, and system-rendered Emoji. Apple frameworks and system artwork are provided by the SDK and OS, rather than redistributed as third-party packages. The app icon and documented simulator screenshots are included as repository assets.
