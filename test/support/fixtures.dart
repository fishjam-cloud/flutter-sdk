/// Loader, matcher and replayer for the golden fixtures in
/// `test/fixtures/*.json` (format: SPEC §23).
///
/// Typical use in a module test:
///
/// ```dart
/// final fixture = Fixture.load('publish_one_track');
/// await FixtureReplayer(
///   fixture: fixture,
///   transports: transports,
///   rtc: rtc,
///   events: events,
///   onApi: (step) => switch (step.call) {
///     'connect' => client.connect(url: 'ws://fishjam', token: 'T'),
///     'addTrack' => client.addTrack(FakeMediaTrack.video()),
///     _ => throw UnimplementedError(step.call),
///   },
/// ).run();
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fishjam_client/src/models/endpoint.dart';
import 'package:fishjam_client/src/models/events.dart';
import 'package:fishjam_client/src/models/simulcast.dart';
import 'package:fishjam_client/src/models/track.dart';
import 'package:fishjam_client/src/proto/fishjam/peer_notifications.pb.dart';
import 'package:fishjam_client/src/rtc/rtc_adapter.dart';

import '../fakes/fake_rtc.dart';
import '../fakes/fake_transport.dart';

/// Directory holding the fixtures, relative to the package root (the
/// working directory of `flutter test`).
const fixturesDirectory = 'test/fixtures';

// ------------------------------------------------------------------- model

/// A parsed fixture.
class Fixture {
  Fixture._(this.name, this.description, this.steps);

  /// Parses fixture JSON.
  factory Fixture.parse(String source) {
    final json = jsonDecode(source);
    if (json is! Map<String, Object?>) {
      throw const FormatException('A fixture is a JSON object');
    }
    final steps = json['steps'];
    if (steps is! List<Object?>) {
      throw const FormatException('"steps" must be a list');
    }
    return Fixture._(
      json['name']! as String,
      (json['description'] as String?) ?? '',
      [
        for (var i = 0; i < steps.length; i++)
          FixtureStep._parse(i, steps[i]! as Map<String, Object?>),
      ],
    );
  }

  /// Loads `test/fixtures/<name>.json`.
  factory Fixture.load(String name) =>
      Fixture.parse(File('$fixturesDirectory/$name.json').readAsStringSync());

  /// Names of every fixture file, sorted.
  static List<String> all() =>
      Directory(fixturesDirectory)
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.json'))
          .map((n) => n.substring(0, n.length - '.json'.length))
          .toList()
        ..sort();

  /// Fixture name (equals the file name).
  final String name;

  /// What the fixture covers.
  final String description;

  /// Ordered steps.
  final List<FixtureStep> steps;
}

/// One step of a fixture.
sealed class FixtureStep {
  const FixtureStep(this.index);

  factory FixtureStep._parse(int index, Map<String, Object?> json) {
    Map<String, Object?> obj(String key) =>
        (json[key] as Map<String, Object?>?) ?? const {};
    return switch (json['direction']) {
      'in' => InStep(index, obj('message')),
      'out' => OutStep(index, obj('message')),
      'close' => CloseStep(
        index,
        code: json['code'] as int?,
        reason: json['reason'] as String?,
      ),
      'api' => ApiStep(
        index,
        call: json['call']! as String,
        args: obj('args'),
        bind: json['bind'] as String?,
        error: json['error'] as String?,
      ),
      'rtc' => RtcStep(
        index,
        event: json['event']! as String,
        args: obj('args'),
      ),
      'expectRtc' => ExpectRtcStep(
        index,
        call: json['call']! as String,
        args: obj('args'),
      ),
      'expect' => ExpectEventStep(
        index,
        event: json['event']! as String,
        fields: obj('fields'),
      ),
      'wait' => WaitStep(index, Duration(milliseconds: json['ms']! as int)),
      final other => throw FormatException('Unknown step direction: $other'),
    };
  }

  /// Position in the fixture.
  final int index;
}

/// The server sends `message` (proto3 JSON of a `PeerMessage`).
class InStep extends FixtureStep {
  /// Creates the step.
  const InStep(super.index, this.message);

  /// Message template; bound placeholders are substituted.
  final Map<String, Object?> message;
}

/// The client must send a message matching `message`.
class OutStep extends FixtureStep {
  /// Creates the step.
  const OutStep(super.index, this.message);

  /// Expected message (may contain placeholders).
  final Map<String, Object?> message;
}

/// The server closes the socket; without code and reason the connection is
/// lost without a close frame.
class CloseStep extends FixtureStep {
  /// Creates the step.
  const CloseStep(super.index, {this.code, this.reason});

  /// Close code.
  final int? code;

  /// Close reason.
  final String? reason;
}

/// The app calls a public API.
class ApiStep extends FixtureStep {
  /// Creates the step.
  const ApiStep(
    super.index, {
    required this.call,
    required this.args,
    this.bind,
    this.error,
  });

  /// API name, e.g. `connect`, `addTrack`.
  final String call;

  /// Arguments (meaning defined per call by the test).
  final Map<String, Object?> args;

  /// Name to bind the call's result to.
  final String? bind;

  /// Expected error type name, when the call must fail.
  final String? error;
}

/// The WebRTC layer reports something.
class RtcStep extends FixtureStep {
  /// Creates the step.
  const RtcStep(super.index, {required this.event, required this.args});

  /// One of `iceConnectionState`, `connectionState`, `iceGatheringState`,
  /// `onTrack`, `iceCandidate`, `dataChannelState`, `dataChannelMessage`.
  final String event;

  /// Event arguments.
  final Map<String, Object?> args;
}

/// The client must have made a WebRTC call.
class ExpectRtcStep extends FixtureStep {
  /// Creates the step.
  const ExpectRtcStep(super.index, {required this.call, required this.args});

  /// Method recorded by the fake (see `FakeRtcCall.method`).
  final String call;

  /// Expected arguments (subset match).
  final Map<String, Object?> args;
}

/// The client must have emitted an event.
class ExpectEventStep extends FixtureStep {
  /// Creates the step.
  const ExpectEventStep(
    super.index, {
    required this.event,
    required this.fields,
  });

  /// Event class name.
  final String event;

  /// Expected fields of [describeEvent] (subset match).
  final Map<String, Object?> fields;
}

/// Time passes.
class WaitStep extends FixtureStep {
  /// Creates the step.
  const WaitStep(super.index, this.duration);

  /// How long.
  final Duration duration;
}

// ---------------------------------------------------------------- matching

final _placeholder = RegExp(r'^\$\{(\w+)\}$');

/// Placeholder bindings shared by every step of a replay.
class Bindings {
  final Map<String, Object?> _values = {};

  /// The value bound to [name].
  Object? operator [](String name) => _values[name];

  /// Whether [name] is bound.
  bool has(String name) => _values.containsKey(name);

  /// Binds [name]; fails if bound to a different value.
  void bind(String name, Object? value) {
    if (has(name) && !_deepEquals(_values[name], value)) {
      throw StateError('$name is already bound to ${_values[name]}');
    }
    _values[name] = value;
  }

  /// Whether [actual] matches [expected] (SPEC §23). Bindings made during a
  /// failed match are discarded.
  bool match(Object? expected, Object? actual) =>
      describeMismatch(expected, actual) == null;

  /// `null` when [actual] matches [expected] (binding placeholders),
  /// otherwise a description of the first mismatch.
  String? describeMismatch(Object? expected, Object? actual) {
    final snapshot = Map.of(_values);
    final result = _mismatch(expected, actual, r'$');
    if (result != null) {
      _values
        ..clear()
        ..addAll(snapshot);
    }
    return result;
  }

  String? _mismatch(Object? expected, Object? actual, String path) {
    if (expected == '<any>') return null;
    if (expected == '<sdp>') {
      return actual is String && actual.isNotEmpty
          ? null
          : '$path: expected non-empty SDP, got $actual';
    }
    if (expected is String) {
      final name = _placeholder.firstMatch(expected)?.group(1);
      if (name != null) {
        if (!has(name)) {
          _values[name] = actual;
          return null;
        }
        return _deepEquals(_values[name], actual)
            ? null
            : '$path: expected \${$name} = ${_values[name]}, got $actual';
      }
    }
    if (expected is Map<String, Object?>) {
      if (actual is! Map) return '$path: expected an object, got $actual';
      final remaining = Map<Object?, Object?>.of(actual);
      final unboundKeys = <String>[];
      for (final entry in expected.entries) {
        var key = entry.key;
        final name = _placeholder.firstMatch(key)?.group(1);
        if (name != null) {
          if (!has(name)) {
            unboundKeys.add(key);
            continue;
          }
          key = '${_values[name]}';
        }
        if (!remaining.containsKey(key)) return '$path: missing key "$key"';
        final m = _mismatch(entry.value, remaining.remove(key), '$path.$key');
        if (m != null) return m;
      }
      return _matchUnboundKeys(expected, unboundKeys, remaining, path);
    }
    if (expected is List<Object?>) {
      if (actual is! List) return '$path: expected a list, got $actual';
      if (actual.length != expected.length) {
        return '$path: expected ${expected.length} items, got '
            '${actual.length}: $actual';
      }
      for (var i = 0; i < expected.length; i++) {
        final m = _mismatch(expected[i], actual[i], '$path[$i]');
        if (m != null) return m;
      }
      return null;
    }
    return _deepEquals(expected, actual)
        ? null
        : '$path: expected $expected, got $actual';
  }

  /// Assigns placeholder keys to remaining actual keys, backtracking.
  String? _matchUnboundKeys(
    Map<String, Object?> expected,
    List<String> keys,
    Map<Object?, Object?> remaining,
    String path,
  ) {
    if (keys.isEmpty) return null;
    final key = keys.first;
    final name = _placeholder.firstMatch(key)!.group(1)!;
    for (final candidate in remaining.keys.toList()) {
      final snapshot = Map.of(_values);
      _values[name] = candidate;
      final value = remaining.remove(candidate);
      final m =
          _mismatch(expected[key], value, '$path.$candidate') ??
          _matchUnboundKeys(expected, keys.sublist(1), remaining, path);
      if (m == null) return null;
      remaining[candidate] = value;
      _values
        ..clear()
        ..addAll(snapshot);
    }
    return '$path: no key matches $key';
  }

  /// Replaces bound placeholders in [json] (values and map keys). Throws
  /// [StateError] for unbound ones.
  Object? substitute(Object? json) {
    if (json is String) {
      final name = _placeholder.firstMatch(json)?.group(1);
      if (name == null) return json;
      if (!has(name)) throw StateError('Unbound placeholder \${$name}');
      return _values[name];
    }
    if (json is Map<String, Object?>) {
      return {
        for (final e in json.entries)
          '${substitute(e.key)}': substitute(e.value),
      };
    }
    if (json is List<Object?>) return json.map(substitute).toList();
    return json;
  }
}

bool _deepEquals(Object? a, Object? b) {
  if (a is num && b is num) return a == b;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// Builds a `PeerMessage` from proto3 JSON.
PeerMessage peerMessageFromJson(Map<String, Object?> json) =>
    PeerMessage()..mergeFromProto3Json(json);

/// proto3 JSON of a `PeerMessage` (defaults omitted).
Map<String, Object?> peerMessageToJson(PeerMessage message) =>
    message.toProto3Json()! as Map<String, Object?>;

// ------------------------------------------------------------------ events

/// JSON-like description of [event] used by `expect` steps.
Map<String, Object?> describeEvent(FishjamEvent event) => {
  'event': switch (event) {
    AuthSucceeded() => 'AuthSucceeded',
    AuthFailed() => 'AuthFailed',
    JoinFailed() => 'JoinFailed',
    Joined() => 'Joined',
    Disconnected() => 'Disconnected',
    ReconnectionStarted() => 'ReconnectionStarted',
    Reconnected() => 'Reconnected',
    ReconnectionFailed() => 'ReconnectionFailed',
    ConnectionError() => 'ConnectionError',
    ServerError() => 'ServerError',
    PeerJoined() => 'PeerJoined',
    PeerLeft() => 'PeerLeft',
    PeerUpdated() => 'PeerUpdated',
    ComponentAdded() => 'ComponentAdded',
    ComponentRemoved() => 'ComponentRemoved',
    ComponentUpdated() => 'ComponentUpdated',
    TrackAdded() => 'TrackAdded',
    TrackReady() => 'TrackReady',
    TrackRemoved() => 'TrackRemoved',
    TrackUpdated() => 'TrackUpdated',
    TrackEncodingChanged() => 'TrackEncodingChanged',
    TrackVariantsChanged() => 'TrackVariantsChanged',
    VoiceActivityChanged() => 'VoiceActivityChanged',
    TargetTrackEncodingRequested() => 'TargetTrackEncodingRequested',
    LocalTrackAdded() => 'LocalTrackAdded',
    LocalTrackRemoved() => 'LocalTrackRemoved',
    LocalTrackReplaced() => 'LocalTrackReplaced',
    LocalTrackMuted() => 'LocalTrackMuted',
    LocalTrackUnmuted() => 'LocalTrackUnmuted',
    LocalTrackBandwidthSet() => 'LocalTrackBandwidthSet',
    LocalTrackEncodingBandwidthSet() => 'LocalTrackEncodingBandwidthSet',
    LocalTrackEncodingEnabled() => 'LocalTrackEncodingEnabled',
    LocalTrackEncodingDisabled() => 'LocalTrackEncodingDisabled',
    LocalPeerMetadataChanged() => 'LocalPeerMetadataChanged',
    LocalTrackMetadataChanged() => 'LocalTrackMetadataChanged',
    DataChannelsReady() => 'DataChannelsReady',
    DataChannelsError() => 'DataChannelsError',
  },
  ...switch (event) {
    AuthSucceeded(:final roomType) => {'roomType': roomType.name},
    AuthFailed(:final reason) => {'reason': reason.name},
    JoinFailed(:final reason) => {'reason': reason.name},
    Joined(:final peerId, :final peers, :final components) => {
      'peerId': peerId,
      'peers': peers.map(_peer).toList(),
      'components': components.map(_component).toList(),
    },
    Disconnected(:final reason, :final closeCode, :final closeReason) => {
      'reason': reason.name,
      'closeCode': closeCode,
      'closeReason': closeReason,
    },
    ReconnectionStarted() || Reconnected() || ReconnectionFailed() => {},
    DataChannelsReady() => {},
    ConnectionError(:final message) ||
    ServerError(:final message) => {'message': message},
    PeerJoined(:final peer) ||
    PeerLeft(:final peer) ||
    PeerUpdated(:final peer) => {'peer': _peer(peer)},
    ComponentAdded(:final component) ||
    ComponentRemoved(:final component) ||
    ComponentUpdated(:final component) => {'component': _component(component)},
    TrackAdded(:final track) ||
    TrackReady(:final track) ||
    TrackRemoved(:final track) ||
    TrackUpdated(:final track) ||
    TrackEncodingChanged(:final track) ||
    TrackVariantsChanged(:final track) ||
    VoiceActivityChanged(:final track) => {'track': _remoteTrack(track)},
    TargetTrackEncodingRequested(:final trackId, :final variant) ||
    LocalTrackEncodingEnabled(:final trackId, :final variant) ||
    LocalTrackEncodingDisabled(
      :final trackId,
      :final variant,
    ) => {'trackId': trackId, 'variant': variant.name},
    LocalTrackAdded(:final track) => {'track': _localTrack(track)},
    LocalTrackRemoved(:final trackId) ||
    LocalTrackMuted(:final trackId) ||
    LocalTrackUnmuted(:final trackId) => {'trackId': trackId},
    LocalTrackReplaced(:final trackId, :final track) => {
      'trackId': trackId,
      'mediaTrackId': track?.id,
    },
    LocalTrackBandwidthSet(:final trackId, :final bandwidth) => {
      'trackId': trackId,
      'bandwidth': _bandwidth(bandwidth),
    },
    LocalTrackEncodingBandwidthSet(
      :final trackId,
      :final variant,
      :final kbps,
    ) =>
      {'trackId': trackId, 'variant': variant.name, 'kbps': kbps},
    LocalPeerMetadataChanged(:final metadata) => {'metadata': metadata},
    LocalTrackMetadataChanged(:final trackId, :final metadata) => {
      'trackId': trackId,
      'metadata': metadata?.toJson(),
    },
    DataChannelsError(:final error) => {'error': '$error'},
  },
};

Map<String, Object?> _metadata(Metadata m) => {
  'peer': m.peer,
  'server': m.server,
};

Map<String, Object?> _peer(Peer p) => {
  'id': p.id,
  'type': p.type,
  'metadata': _metadata(p.metadata),
  'tracks': p.tracks.keys.toList(),
};

Map<String, Object?> _component(Component c) => {
  'id': c.id,
  'type': c.type,
  'metadata': _metadata(c.metadata),
  'tracks': c.tracks.keys.toList(),
};

Map<String, Object?> _simulcast(SimulcastConfig s) => {
  'enabled': s.enabled,
  'enabledVariants': s.enabledVariants.map((v) => v.name).toList(),
  'disabledVariants': s.disabledVariants.map((v) => v.name).toList(),
};

Object? _bandwidth(BandwidthLimit b) => switch (b) {
  SingleBandwidthLimit(:final kbps) => kbps,
  SimulcastBandwidthLimit(:final kbpsPerVariant) => {
    for (final e in kbpsPerVariant.entries) e.key.name: e.value,
  },
};

Map<String, Object?> _remoteTrack(RemoteTrackContext t) => {
  'trackId': t.trackId,
  'endpointId': t.endpointId,
  'kind': t.kind?.name,
  'metadata': t.rawMetadata,
  'simulcastConfig': _simulcast(t.simulcastConfig),
  'vadStatus': t.vadStatus.name,
  'encoding': t.encoding?.name,
  'ready': t.isReady,
};

Map<String, Object?> _localTrack(LocalTrackContext t) => {
  'trackId': t.trackId,
  'kind': t.kind.name,
  'metadata': t.metadata?.toJson(),
  'simulcastConfig': _simulcast(t.simulcastConfig),
  'maxBandwidth': _bandwidth(t.maxBandwidth),
  'muted': t.isMuted,
};

// ---------------------------------------------------------------- replayer

/// A fixture step did not hold.
class FixtureMismatch implements Exception {
  /// Creates the error.
  FixtureMismatch(this.fixture, this.step, this.message);

  /// Fixture name.
  final String fixture;

  /// Failing step.
  final FixtureStep step;

  /// What went wrong.
  final String message;

  @override
  String toString() =>
      'FixtureMismatch($fixture, step ${step.index} '
      '${step.runtimeType}): $message';
}

/// Lets queued microtasks and zero-delay timers run.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Replays a [Fixture] against a client wired to fakes.
class FixtureReplayer {
  /// Creates a replayer. [onApi] performs `api` steps; [onWait] advances
  /// time for `wait` steps (default: real delay).
  FixtureReplayer({
    required this.fixture,
    required this.transports,
    required this.rtc,
    required this.events,
    required this.onApi,
    this.onWait,
    this.outTimeout = defaultSentTimeout,
  });

  /// The fixture.
  final Fixture fixture;

  /// Where the client gets its transports.
  final FakeTransportFactory transports;

  /// Where the client gets its peer connections.
  final FakeRtcAdapter rtc;

  /// Events emitted by the client, appended as they happen.
  final List<FishjamEvent> events;

  /// Performs an `api` step and returns its result.
  final FutureOr<Object?> Function(ApiStep step) onApi;

  /// Advances time.
  final Future<void> Function(Duration duration)? onWait;

  /// How long to wait for each `out` message.
  final Duration outTimeout;

  /// Placeholder bindings.
  final Bindings bindings = Bindings();

  int _eventCursor = 0;
  int _rtcCursor = 0;
  final _pendingApi = <(ApiStep, Future<Object?>)>[];

  /// Runs every step; throws [FixtureMismatch] on the first failure.
  Future<void> run() async {
    for (final step in fixture.steps) {
      await _run(step);
    }
    for (final (step, future) in _pendingApi) {
      await _finishApi(step, future.timeout(outTimeout));
    }
  }

  Never _fail(FixtureStep step, String message) =>
      throw FixtureMismatch(fixture.name, step, message);

  Future<void> _run(FixtureStep step) async {
    switch (step) {
      case InStep(:final message):
        final json = bindings.substitute(message)! as Map<String, Object?>;
        transports.last.receive(peerMessageFromJson(json));
        await settle();
      case OutStep(:final message):
        await _expectOut(step, message);
      case CloseStep(:final code, :final reason):
        if (code == null && reason == null) {
          transports.last.loseConnection();
        } else {
          transports.last.serverClose(code: code, reason: reason);
        }
        await settle();
      case ApiStep():
        await _api(step);
      case RtcStep():
        _rtcEvent(step);
        await settle();
      case ExpectRtcStep(:final call, :final args):
        await settle();
        _expectRtc(step, call, args);
      case ExpectEventStep(:final event, :final fields):
        await settle();
        _expectEvent(step, {'event': event, ...fields});
      case WaitStep(:final duration):
        await (onWait ?? Future<void>.delayed)(duration);
        await settle();
    }
  }

  Future<void> _expectOut(OutStep step, Map<String, Object?> expected) async {
    final wantsCandidate = _isCandidate(expected);
    while (true) {
      final PeerMessage message;
      try {
        message = await transports.nextSent(timeout: outTimeout);
      } on TimeoutException {
        _fail(step, 'no message sent; expected $expected');
      }
      final actual = peerMessageToJson(message);
      if (!wantsCandidate && _isCandidate(actual)) continue;
      final mismatch = bindings.describeMismatch(expected, actual);
      if (mismatch != null) _fail(step, '$mismatch\nactual: $actual');
      return;
    }
  }

  static bool _isCandidate(Map<String, Object?> json) {
    final event = json['peerMediaEvent'];
    return event is Map && event.containsKey('candidate');
  }

  Future<void> _api(ApiStep step) async {
    final completer = Completer<Object?>();
    // Errors are inspected later; keep them from surfacing as unhandled.
    completer.future.ignore();
    unawaited(
      Future.sync(() => onApi(step))
          .then(completer.complete, onError: completer.completeError),
    );
    await settle();
    // Calls that finish right away (bindings, synchronous errors) are
    // checked now; the rest (e.g. addTrack waiting for an answer) at the end.
    if (completer.isCompleted) {
      await _finishApi(step, completer.future);
    } else {
      _pendingApi.add((step, completer.future));
    }
  }

  Future<void> _finishApi(ApiStep step, Future<Object?> future) async {
    try {
      final result = await future;
      if (step.error != null) {
        _fail(step, 'expected ${step.error}, but the call succeeded');
      }
      final bind = step.bind;
      if (bind != null) {
        final mismatch = bindings.describeMismatch('\${$bind}', result);
        if (mismatch != null) _fail(step, mismatch);
      }
    } on FixtureMismatch {
      rethrow;
    } on Object catch (e) {
      if (step.error == null) _fail(step, 'unexpected error: $e');
      if (e.runtimeType.toString() != step.error) {
        _fail(step, 'expected ${step.error}, got ${e.runtimeType}: $e');
      }
    }
  }

  void _rtcEvent(RtcStep step) {
    final args = bindings.substitute(step.args)! as Map<String, Object?>;
    final pc = rtc.lastPeerConnection;
    String arg(String key) => args[key]! as String;
    switch (step.event) {
      case 'iceConnectionState':
        pc.setIceConnectionState(
          IceConnectionState.values.byName(arg('state')),
        );
      case 'connectionState':
        pc.setConnectionState(PeerConnectionState.values.byName(arg('state')));
      case 'iceGatheringState':
        pc.setIceGatheringState(IceGatheringState.values.byName(arg('state')));
      case 'onTrack':
        pc.emitTrack(
          mid: arg('mid'),
          kind: MediaKind.values.byName(arg('kind')),
          streamId: args['streamId'] as String?,
        );
      case 'iceCandidate':
        pc.emitIceCandidate(
          IceCandidate(
            candidate: arg('candidate'),
            sdpMid: args['sdpMid'] as String?,
            sdpMLineIndex: args['sdpMLineIndex'] as int?,
          ),
        );
      case 'dataChannelState':
        final channel = pc.dataChannels.lastWhere(
          (c) => c.label == arg('label'),
        );
        switch (arg('state')) {
          case 'open':
            channel.open();
          case 'closed':
            channel.closeFromRemote();
          default:
            _fail(step, 'unsupported data channel state ${arg('state')}');
        }
      case 'dataChannelMessage':
        pc.dataChannels
            .lastWhere((c) => c.label == arg('label'))
            .receive(_bytes(args['data']));
      default:
        _fail(step, 'unknown rtc event ${step.event}');
    }
  }

  void _expectRtc(
    ExpectRtcStep step,
    String call,
    Map<String, Object?> expected,
  ) {
    final calls = [for (final pc in rtc.peerConnections) ...pc.calls];
    for (var i = _rtcCursor; i < calls.length; i++) {
      if (calls[i].method != call) continue;
      if (bindings.match(expected, calls[i].args)) {
        _rtcCursor = i + 1;
        return;
      }
    }
    _fail(
      step,
      'no $call matching $expected after call #$_rtcCursor; calls: '
      '${calls.skip(_rtcCursor).toList()}',
    );
  }

  void _expectEvent(ExpectEventStep step, Map<String, Object?> expected) {
    for (var i = _eventCursor; i < events.length; i++) {
      if (bindings.match(expected, describeEvent(events[i]))) {
        _eventCursor = i + 1;
        return;
      }
    }
    _fail(
      step,
      'no event matching $expected; emitted since last match: '
      '${events.skip(_eventCursor).map(describeEvent).toList()}',
    );
  }
}

Uint8List _bytes(Object? json) =>
    Uint8List.fromList((json! as List<Object?>).cast<int>());
