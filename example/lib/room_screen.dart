import 'dart:async';
import 'dart:io';

import 'package:fishjam_client/fishjam_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'sandbox.dart';

/// A minimal room: publishes camera and microphone, renders remote video,
/// mute toggles and leave.
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
  _RemoteVideo(this.renderer, this.label);

  final RTCVideoRenderer renderer;
  final String label;
}

class _RoomScreenState extends State<RoomScreen> {
  // Tracks are published again after a reconnection (with new ids).
  final _client = FishjamClient(
    reconnect: const ReconnectConfig(addTracksOnReconnect: true),
  );
  final _localRenderer = RTCVideoRenderer();
  final _remote = <String, _RemoteVideo>{};
  final _subscriptions = <StreamSubscription<Object?>>[];

  MediaStream? _localStream;
  MediaStreamTrack? _camera;
  MediaStreamTrack? _microphone;
  String? _cameraTrackId;
  String? _microphoneTrackId;
  bool _cameraOn = true;
  bool _microphoneOn = true;
  String _status = 'Connecting…';
  final _audioOutput = AudioOutputManager.instance;
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
    unawaited(_refreshAudioOutputs());
    unawaited(_start());
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
    await _localRenderer.initialize();
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
      _localRenderer.srcObject = stream;
      if (mounted) setState(() {});

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
        unawaited(_remote.remove(track.trackId)?.renderer.dispose());
        setState(() {});
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

  void _clearRemoteVideos() {
    for (final video in _remote.values) {
      unawaited(video.renderer.dispose());
    }
    setState(_remote.clear);
  }

  Future<void> _addRemoteVideo(RemoteTrackContext track) async {
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    // The track may have gone (or the screen closed) while initializing.
    final current = _client.remoteTracks[track.trackId];
    if (!mounted || current == null || !current.isReady) {
      await renderer.dispose();
      return;
    }
    renderer.srcObject = current.stream;
    final peer = _client.remotePeers[track.endpointId];
    final name = switch (peer?.metadata.peer) {
      {'name': final String name} => name,
      _ => track.endpointId,
    };
    final previous = _remote[track.trackId];
    setState(() => _remote[track.trackId] = _RemoteVideo(renderer, name));
    await previous?.renderer.dispose();
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
    for (final video in _remote.values) {
      unawaited(video.renderer.dispose());
    }
    unawaited(_localRenderer.dispose());
    unawaited(_client.dispose());
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
        renderer: _localRenderer,
        label: '${widget.displayName} (you)',
        mirror: true,
      ),
      for (final video in _remote.values)
        _VideoTile(renderer: video.renderer, label: video.label),
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
    required this.renderer,
    required this.label,
    this.mirror = false,
  });

  final RTCVideoRenderer renderer;
  final String label;
  final bool mirror;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: RTCVideoView(
            renderer,
            mirror: mirror,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
