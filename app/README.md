# Adaptive VPN Flutter client

Shared UI for Android, iOS, Windows, macOS, and Linux.

## Run checks

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
```

## Native contract

The client calls the `dev.adaptivevpn/tunnel` MethodChannel:

- `capability`
- `connect`
- `disconnect`

Until a platform adapter implements this contract, the connection page reports that the adapter is
unavailable and keeps the Connect button disabled. Routing inspection and profile validation remain
usable in a configuration build.

Full architecture and platform status live in
`../docs/Project-Knowledge-Base/01-Architecture/`.
