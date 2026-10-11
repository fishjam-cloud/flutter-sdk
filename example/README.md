# fishjam_example

A minimal Fishjam room built with `fishjam_client`: it publishes the camera and microphone, renders the
other peers' video, has mute toggles, a chat over the reliable data channel, and a leave button.

## Run

```sh
mise exec -- flutter run   # pick an iOS simulator / device or an Android device
```

On the join screen choose one of:

- **Peer token**: enter your Fishjam ID (or the URL of your Fishjam server) and a peer token created by your
  backend with a Fishjam server SDK. This is how production apps join. The ID is turned into a URL with
  `fishjamUrlFromId`.
- **Sandbox API**: enter your Fishjam ID, the Sandbox API URL from the Fishjam dashboard, a room name and your name. The
  Sandbox API is an unauthenticated test backend: **use it for prototyping only, never in production.**

The iOS simulator has no camera; use a device to publish video. Android emulators decode only VP8, so create
rooms for them with the VP8 video codec.

Platform setup used here (copy it into your app): camera and microphone usage strings in
`ios/Runner/Info.plist`, camera/microphone/network permissions in `android/app/src/main/AndroidManifest.xml`
and `minSdk` 23 or newer in `android/app/build.gradle.kts`.

For an Android release build with code shrinking, keep the WebRTC classes in your ProGuard / R8 rules
(`android/app/proguard-rules.pro`):

```
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class org.webrtc.** { *; }
```
