# Local ShopHop development

The web and mobile apps must use the same Laravel server and database.
The mobile app defaults to `https://shop-hop.site/api/mobile`; a local run
requires a compile-time `API_BASE_URL` override. Restart the run when changing it.

## Physical Android phone over USB (recommended)

Enable USB debugging, connect the phone, and approve the computer on the phone.
In the web project, keep the Laravel server running:

```powershell
php artisan serve --host=127.0.0.1 --port=8000
```

In the mobile project:

```powershell
.\scripts\run-local-mobile.ps1
```

The script checks the local API, selects the connected physical phone, adds
`adb reverse tcp:8000 tcp:8000`, and launches Flutter with the correct API URL.
Use the ADB serial from `adb devices`, not the model name, for `-DeviceId` when
multiple phones are connected. It also accepts `-Port` for a different API port.

To connect the currently installed debug app without launching another Flutter run:

```powershell
.\scripts\run-local-mobile.ps1 -ConnectOnly
```

The USB reverse mapping lasts only while the phone's ADB connection remains active.
Run the script again after reconnecting. It does not change the production URL,
release network security settings, firewall rules, or Laravel data.

## Chrome on the development PC

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/mobile
```

## Android emulator

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/mobile
```

`10.0.2.2` is the emulator's route to the PC, not a physical-phone address.
Without USB reverse, `127.0.0.1` on a phone points back to the phone itself.

## Physical phone over Wi-Fi

Keep the PC and phone on the same network. Bind Laravel to the LAN and substitute
the PC's current IPv4 address (check `ipconfig`; it can change):

```powershell
php artisan serve --host=0.0.0.0 --port=8000
flutter run -d <adb-serial> --dart-define=API_BASE_URL=http://<pc-ipv4>:8000/api/mobile
```

Check that `http://<pc-ipv4>:8000/up` opens from the phone. The firewall/network
must allow the connection. The existing Android debug manifest allows local HTTP;
release builds continue to require HTTPS.

## After a structural UI change

A hot reload preserves old State instances and is insufficient after changing
State fields or adding font assets. Press uppercase `R` in the Flutter terminal
for a full hot restart. If changing API defines or native manifests, quit and run
again. Red error cards are Flutter exceptions, not ordinary missing-photo states.

The Buyer Home layout key changes for the marketplace redesign so pre-redesign
Home state is replaced. Public product images use Flutter web's HTML fallback
when the image server does not supply cross-origin headers. Native Android/iOS
image loading and ordinary unavailable-photo placeholders stay intact.
