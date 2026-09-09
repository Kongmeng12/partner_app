# Runs the app - a thin wrapper kept around only because it's shorter to
# type than `flutter run`, and because plain `flutter run` is wrong for a
# real device: lib/core/network/api_client.dart defaults Android to
# `10.0.2.2`, the emulator-only loopback, which a physical phone can never
# reach and just times out against. Every run here goes through the public
# API instead (the same origin the live site uses), so it works the same
# whether the target is an emulator, a real phone, or a browser.
#
# Usage: .\run.ps1            (asks which connected device)
#        .\run.ps1 chrome     (equivalent to flutter run -d chrome)
#        .\run.ps1 windows

param([string]$Device)

$apiBaseUrl = '--dart-define=API_BASE_URL=https://phaphak.com/api'

# Chrome is a browser origin, so the backend's CORS_ORIGIN allow-list has to
# name its exact port — left to Flutter's default (a new random port every
# run) it would never match and every API call would be blocked by CORS.
# :5175 is this app's fixed slot (:5173 admin, :5174 guest webapp, :5176 the
# customer Flutter app also on Chrome — see backend/backend/src/main.ts).
if ($Device -eq 'chrome') {
    flutter run -d chrome --web-port=5175 $apiBaseUrl
} elseif ($Device) {
    flutter run -d $Device $apiBaseUrl
} else {
    flutter run $apiBaseUrl
}
