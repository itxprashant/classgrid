# Changelog

All notable changes to the ClassGrid Android app are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]
### Added
- **Markdown Rendering in Changelogs** - added markdown rendering for changelogs.

## [1.2.0] - 2026-06-26

### Added
- **FCM broadcast notifications (Android)** — added remote notification support.

### Changed
- **Empty halls** uses the same building tabs as Rooms (**LHC** default, Blocks **I**–**VI**); LHC free/marked rooms are grouped by floor
- **Release signing** — production APKs use a fixed release keystore (fixes sideload “package conflicts” when updating; uninstall once if upgrading from older debug-signed builds)

## [1.1.9] - 2026-06-19

### Added
- **Campus room fallback** on Rooms (web and app): when the active catalog has no venue data yet, browse room names from the last room allotment chart with **Schedule pending** labels until catalog venues are imported
- **Previous offerings** on the current-semester course page — opens full semester history (Courses tab and web offering view)
- Student explorer under **Tools → Students**: search by name or kerberos, enrollments across semesters, hostel when known

### Changed
- **Rooms browse** uses building tabs below search (**LHC** default, Blocks **I**–**VI**) instead of a per-prefix dropdown; LHC rooms are grouped by floor (first digit after `LH`, e.g. `LH 121` → Floor 1)
- Course catalog opens the **current-semester offering** (schedule, roster, policy); use **Previous offerings** for archived terms
- Student kerberos matching includes both `aa1234567` and `abc123456` formats in explorer and rosters

## [1.1.8] - 2026-06-18

### Fixed
- Check for updates on the About screen (works from pushed routes)

## [1.1.7] - 2026-06-18

### Added
- In-app changelog, optional update prompts, and What's New after updating
- Check for updates and release history in About

## [1.1.6] - 2026-06-18

### Added
- Optional update prompts when a newer APK is available
- Release history and manual update check in About
- What's New sheet after updating to a new build

### Changed
- Force-update gate now uses a separate minimum version threshold
