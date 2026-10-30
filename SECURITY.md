# Kıpır — Privacy and security

Kıpır makes no network requests and includes no third-party dependencies, accounts, analytics, cloud, webviews or remote update logic. CoreGraphics provides only aggregate seconds since input. No keystrokes, mouse positions, screenshots, active-app names, window contents or browsing history are read or stored.

UserDefaults stores preferences, confirmed session progress and current-day aggregate active seconds/completed countdowns. These are ordinary local preferences, not encrypted secrets. Reset Session preserves today's aggregate; removing the application's defaults while it is closed erases local state. No export or external synchronization exists.

Notifications are optional and require explicit authorization. No Accessibility, Input Monitoring, Screen Recording or administrator permission is requested. Launch at Login is optional through SMAppService and may be restricted by macOS or device management; failures are shown without bypass. Screen lock uses notification names with a conservative heartbeat fallback; real-device verification is required.

The target uses App Sandbox and no network entitlements. Direct local unsigned builds are for development. Distribution may require Developer ID signing, hardened runtime and notarization. Never disable Gatekeeper, change signing identities or bypass MDM. Self-developed software still requires an employer's approval on corporate devices. Report security defects privately to the repository owner; no external reporting service is configured.
