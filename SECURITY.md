# Security Policy

## Reporting

Open an [issue](../../issues). Say what you did, what happened, and which macOS and
OpenSide versions you are on (click the menu bar icon and choose About).

## What the app can reach

- **No network access.** The app opens no sockets and sends no telemetry, crash
  reports or usage data. Nothing leaves the machine.
- **No sandbox.** The app ships without entitlements. Sandboxing is incompatible with
  the private framework it calls and with reconfiguring displays.
- **It stores two preferences**, the chosen language and the last arrangement preset,
  in the app's own `UserDefaults` domain.
- **It writes to `com.apple.sidecar.display`**, the domain macOS itself uses for the
  Sidecar screen options, to change the same settings System Settings changes.
- **It calls `SidecarCore`**, a private Apple framework, through `dlopen` and
  `NSClassFromString`. A future macOS release may change or remove it.

## Checking a download

Builds on the Releases page are signed with a Developer ID certificate and notarised
by Apple, with the ticket stapled to the app.

```sh
spctl -a -vv OpenSide.app
xcrun stapler validate OpenSide.app
```

A build that does not report `source=Notarized Developer ID` did not come from here.
