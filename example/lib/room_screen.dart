import 'dart:async';
import 'dart:io';

import 'package:fishjam_client/fishjam_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'sandbox.dart';

/// A minimal room: publishes camera and microphone, renders remote video,
/// mute toggles, camera switch, picture-in-picture and leave.
class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.credentials,
    required this.displayName,
  });

  final RoomCredentials credentials;
  final String displayName;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RemoteVideo {
  _RemoteVideo(this.stream, this.label);

  final MediaStream? stream;
  final String label;
}

/// Keeps the local camera running on iOS while picture-in-picture is up
/// (it needs the `voip` background mode).
const _pipOptions = PictureInPictureOptions(allowsCameraInBackground: true);

/// iOS does not start picture-in-picture on its own when the app goes to
/// the background while more than one view offers it. Like the React Native
/// example, only the first remote video does. Your own camera does not:
/// it may be off.
const _noPip = PictureInPictureOptions(enabled: false);

class _RoomScreenState extends State<RoomScreen> {
  // Tracks are published again after a reconnection, with new ids
  // (`ReconnectConfig.addTracksOnReconnect`, on by default).
  final _client = FishjamClient();
  final _remote = <String, _RemoteVideo>{};
  // The picture-in-picture button always starts the first remote tile. Keep
  // its controller when that peer reconnects: Flutter does not rebuild tiles
  // while the app is hidden, but the controller can update the native window.
  final _remotePip = PictureInPictureController();
  final _localPip = PictureInPictureController();
  final _subscriptions = <StreamSubscription<Object?>>[];

  MediaStream? _localStream;
  MediaStreamTrack? _camera;
  MediaStreamTrack? _microphone;
  String? _cameraTrackId;
  String? _microphoneTrackId;
  bool _cameraOn = true;
  bool _microphoneOn = true;
  bool _frontCamera = true;
  String _status = 'Connecting…';
  final _audioOutput = AudioOutputManager.instance;
  final _callKit = CallKit.instance;
  AudioOutputChangedInfo _audio = const AudioOutputChangedInfo(
    currentAudioOutput: null,
    availableAudioOutputs: [],
  );

  @override
  void initState() {
    super.initState();
    _subscriptions.add(
      _audioOutput.onAudioOutputChanged.listen(
        (info) => setState(() => _audio = info),
      ),
    );
    _subscriptions.add(_callKit.actions.listen(_onCallKitAction));
    unawaited(_refreshAudioOutputs());
    unawaited(_start());
  }

  /// The system call UI can end the call or mute the microphone.
  void _onCallKitAction(CallKitAction action) {
    switch (action) {
      case CallKitEnded():
        unawaited(_leave());
      case CallKitMuted(:final isMuted) when isMuted == _microphoneOn:
        unawaited(_toggleMicrophone());
      default:
        break;
    }
  }

  Future<void> _refreshAudioOutputs() async {
    try {
      final current = await _audioOutput.getCurrentAudioOutput();
      final available = await _audioOutput.getAvailableAudioOutputs();
      if (!mounted) return;
      setState(
        () => _audio = AudioOutputChangedInfo(
          currentAudioOutput: current,
          availableAudioOutputs: available,
        ),
      );
    } on Object catch (e) {
      _setStatus('Audio output: $e');
    }
  }

  Future<void> _chooseAudioOutput() async {
    await _refreshAudioOutputs();
    if (!mounted) return;
    final current = _audio.currentAudioOutput;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        void run(Future<void> Function() action) {
          Navigator.of(sheetContext).pop();
          unawaited(
            action().catchError((Object e) {
              if (e case AudioOutputException(
                code: AudioOutputErrorCode.superseded,
              )) {
                return;
              }
              _setStatus('Audio output: $e');
            }),
          );
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: Platform.isIOS
                ? [
                    ListTile(
                      leading: const Icon(Icons.volume_up),
                      title: const Text('Speaker'),
                      onTap: () => run(
                        () => _audioOutput.ios.overrideAudioOutput(
                          IosAudioOutputOverride.speaker,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.phone_in_talk),
                      title: const Text('Default (receiver or headset)'),
                      onTap: () => run(
                        () => _audioOutput.ios.overrideAudioOutput(
                          IosAudioOutputOverride.none,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: const Text('Choose device…'),
                      subtitle: Text('Now: ${current?.name ?? 'unknown'}'),
                      onTap: () => run(_audioOutput.ios.showAudioRoutePicker),
                    ),
                  ]
                : [
                    for (final device in _audio.availableAudioOutputs)
                      ListTile(
                        leading: Icon(_audioIcon(device.type)),
                        title: Text(device.name),
                        subtitle: Text(device.type.name),
                        selected: device.id == current?.id,
                        onTap: () => run(
                          () =>
                              _audioOutput.android.selectAudioOutput(device.id),
                        ),
                      ),
                  ],
          ),
        );
      },
    );
  }

  static IconData _audioIcon(AudioDeviceType? type) => switch (type) {
    AudioDeviceType.speaker => Icons.volume_up,
    AudioDeviceType.earpiece => Icons.phone_in_talk,
    AudioDeviceType.bluetooth => Icons.bluetooth_audio,
    AudioDeviceType.wiredHeadset || AudioDeviceType.usb => Icons.headphones,
    _ => Icons.speaker,
  };

  Future<void> _start() async {
    _subscriptions.add(_client.events.listen(_onEvent));
    try {
      // Asks for camera and microphone permission.
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });
      _localStream = stream;
      _camera = stream.getVideoTracks().firstOrNull;
      _microphone = stream.getAudioTracks().firstOrNull;
      if (mounted) setState(() {});

      // Keeps the call running in the background. The service types follow
      // the permissions granted by getUserMedia above.
      await ForegroundService.instance.start(
        const ForegroundServiceConfig(
          enableCamera: true,
          enableMicrophone: true,
          channelName: 'Fishjam Notifications',
          notificationTitle: 'Your video call is ongoing',
          notificationContent: 'Tap to return to the call.',
        ),
      );
      await _callKit.startSession(
        CallKitConfig(displayName: widget.displayName, isVideo: true),
      );

      await _client.connect(
        url: widget.credentials.url,
        token: widget.credentials.peerToken,
        peerMetadata: {'name': widget.displayName},
      );
      _setStatus('Connected');
      await Future.wait([_publishCamera(), _publishMicrophone()]);
    } on Object catch (e) {
      _setStatus('Error: $e');
    }
  }

  Future<void> _publishCamera() async {
    final camera = _camera;
    if (camera == null) return;
    _cameraTrackId = await _client.addTrack(
      camera,
      metadata: TrackMetadata(
        type: TrackType.camera,
        displayName: widget.displayName,
      ),
    );
  }

  Future<void> _publishMicrophone() async {
    final microphone = _microphone;
    if (microphone == null) return;
    _microphoneTrackId = await _client.addTrack(
      microphone,
      metadata: TrackMetadata(
        type: TrackType.microphone,
        displayName: widget.displayName,
      ),
    );
  }

  void _onEvent(FishjamEvent event) {
    switch (event) {
      case TrackReady(:final track) when track.kind == MediaKind.video:
        unawaited(_addRemoteVideo(track));
      case Joined():
        // A (re)joined session's snapshot is the source of truth: drop every
        // tile; ready tracks come back with TrackReady.
        _clearRemoteVideos();
      case TrackRemoved(:final track):
        final video = _remote[track.trackId];
        // Keep the PiP window open with its fallback while this peer
        // reconnects. Flutter does not rebuild tiles in the background, so
        // explicitly clear its native track now.
        if (identical(video, _remote.values.firstOrNull)) {
          unawaited(_remotePip.setMediaStream(null));
        }
        setState(() => _remote.remove(track.trackId));
      case LocalTrackAdded(:final track):
        // After a reconnection the restored tracks get new ids.
        if (track.track?.id == _camera?.id) _cameraTrackId = track.trackId;
        if (track.track?.id == _microphone?.id) {
          _microphoneTrackId = track.trackId;
        }
      case LocalTrackRemoved(:final trackId):
        if (trackId == _cameraTrackId) _cameraTrackId = null;
        if (trackId == _microphoneTrackId) _microphoneTrackId = null;
      case ReconnectionStarted():
        _setStatus('Reconnecting…');
      case Reconnected():
        _setStatus('Connected');
      case Disconnected(:final reason) when reason != DisconnectReason.left:
        _setStatus('Disconnected: ${reason.name}');
      default:
        break;
    }
  }

  void _clearRemoteVideos() => setState(_remote.clear);

  Future<void> _addRemoteVideo(RemoteTrackContext track) async {
    // The track may have gone while the event was queued.
    final current = _client.remoteTracks[track.trackId];
    if (!mounted || current == null || !current.isReady) return;
    final stream = current.stream;
    final peer = _client.remotePeers[track.endpointId];
    final name = switch (peer?.metadata.peer) {
      {'name': final String name} => name,
      _ => track.endpointId,
    };
    // A reconnect can deliver the new track while this app is backgrounded.
    // The tile will not rebuild until the app returns, so update the native
    // window immediately instead of leaving its fallback visible.
    if (_remotePip.isActive) {
      await _remotePip.setMediaStream(stream);
    }
    if (!mounted) return;
    setState(() => _remote[track.trackId] = _RemoteVideo(stream, name));
  }

  /// Muting replaces the sent media with nothing; unmuting puts it back.
  /// `replaceTrack(id, null)` only stops sending: the camera keeps capturing
  /// (and the local preview keeps running). Set `track.enabled = false` or
  /// stop the track if the device should be released.
  Future<void> _toggleCamera() async {
    final on = !_cameraOn;
    setState(() => _cameraOn = on);
    await _toggle(
      _cameraTrackId,
      _camera,
      on: on,
      type: TrackType.camera,
      publish: _publishCamera,
    );
  }

  /// Same track, so the published camera keeps its id. `true` means the
  /// front camera is now active.
  Future<void> _switchCamera() async {
    final camera = _camera;
    if (camera == null) return;
    try {
      final front = await Helper.switchCamera(camera);
      if (mounted) setState(() => _frontCamera = front);
    } on Object catch (e) {
      _setStatus('Error: $e');
    }
  }

  Future<void> _toggleMicrophone() async {
    final on = !_microphoneOn;
    setState(() => _microphoneOn = on);
    await _toggle(
      _microphoneTrackId,
      _microphone,
      on: on,
      type: TrackType.microphone,
      publish: _publishMicrophone,
    );
  }

  Future<void> _toggle(
    String? trackId,
    MediaStreamTrack? media, {
    required bool on,
    required TrackType type,
    required Future<void> Function() publish,
  }) async {
    if (media == null) return;
    try {
      if (trackId == null) {
        // A muted track is not restored after a reconnection.
        if (on) await publish();
        return;
      }
      await _client.replaceTrack(trackId, on ? media : null);
      _client.updateTrackMetadata(
        trackId,
        TrackMetadata(type: type, paused: !on, displayName: widget.displayName),
      );
    } on Object catch (e) {
      _setStatus('Error: $e');
    }
  }

  Future<void> _leave() async {
    await _client.leave();
    if (mounted) Navigator.of(context).pop();
  }

  void _setStatus(String status) {
    if (mounted) setState(() => _status = status);
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_client.dispose());
    unawaited(ForegroundService.instance.stop());
    unawaited(_callKit.endSession());
    final stream = _localStream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        unawaited(track.stop());
      }
      unawaited(stream.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _VideoTile(
        stream: _localStream,
        label: '${widget.displayName} (you)',
        mirror: _frontCamera,
        pip: _localPip,
        pipOptions: _noPip,
      ),
      for (final video in _remote.values)
        _VideoTile(
          stream: video.stream,
          label: video.label,
          pip: identical(video, _remote.values.first) ? _remotePip : null,
          pipOptions: identical(video, _remote.values.first)
              ? _pipOptions
              : _noPip,
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_status)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.all(8),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 3 / 4,
                children: tiles,
              ),
            ),
            _controls(),
          ],
        ),
      ),
    );
  }

  Widget _controls() => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton.filledTonal(
          onPressed: _toggleMicrophone,
          icon: Icon(_microphoneOn ? Icons.mic : Icons.mic_off),
        ),
        IconButton.filledTonal(
          onPressed: _toggleCamera,
          icon: Icon(_cameraOn ? Icons.videocam : Icons.videocam_off),
        ),
        IconButton.filledTonal(
          tooltip: 'Switch camera',
          onPressed: _camera == null ? null : _switchCamera,
          icon: const Icon(Icons.cameraswitch),
        ),
        IconButton.filledTonal(
          tooltip: 'Picture in picture',
          onPressed:
              (_remotePip.isActive || _remote.isNotEmpty
                      ? _remotePip
                      : _localPip)
                  .start,
          icon: const Icon(Icons.picture_in_picture_alt),
        ),
        IconButton.filledTonal(
          onPressed: _chooseAudioOutput,
          icon: Icon(_audioIcon(_audio.currentAudioOutput?.type)),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _leave,
          icon: const Icon(Icons.call_end),
          label: const Text('Leave'),
        ),
      ],
    ),
  );
}

class _VideoTile extends StatelessWidget {
  const _VideoTile({
    required this.label,
    required this.pipOptions,
    this.stream,
    this.pip,
    this.mirror = false,
  });

  final MediaStream? stream;
  final String label;
  final PictureInPictureController? pip;
  final PictureInPictureOptions pipOptions;
  final bool mirror;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: PictureInPictureView(
            mediaStream: stream,
            controller: pip,
            mirror: mirror,
            pipOptions: pipOptions,
          ),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Text(label, style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
