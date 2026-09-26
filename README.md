# WebToApp

WebToApp is a reusable website-to-Android application builder.

## Goal

Provide two companion tools:

- **Windows Builder (.exe)** — configure a website, branding, orientation and optional native features, then generate an Android project.
- **Android Builder (.apk)** — mobile companion for creating and editing compatible WebToApp project configurations.

Generated Android apps are designed for:
- portrait and landscape
- phones and tablets
- adaptive screen sizes and densities
- WebView navigation
- uploads/downloads
- camera and microphone permissions
- location
- fullscreen video
- pull-to-refresh
- offline handling
- sharing
- optional native modules

## Repository layout

- `android-builder/` — Android companion application
- `windows-builder/` — Windows desktop builder
- `android-template/` — reusable Android WebView application template
- `shared/` — shared configuration schema and examples
- `.github/workflows/` — CI builds for APK and EXE

The project is being developed incrementally, starting with a stable buildable foundation before advanced modules are enabled.
