import 'package:meta/meta.dart';

/// A simulcast layer.
enum Variant {
  /// Lowest resolution (rid `l`, scaled down 4x).
  low('l'),

  /// Medium resolution (rid `m`, scaled down 2x).
  medium('m'),

  /// Full resolution (rid `h`).
  high('h');

  Variant(this.rid);

  /// The RTP stream id used for this layer.
  final String rid;

  /// The variant for [rid]; `null` for an unknown rid. A missing rid means
  /// [high] on the receive side, which callers handle explicitly.
  static Variant? fromRid(String rid) {
    for (final v in values) {
      if (v.rid == rid) return v;
    }
    return null;
  }
}

/// Simulcast configuration of a track.
@immutable
final class SimulcastConfig {
  const SimulcastConfig({
    required this.enabled,
    this.enabledVariants = const [],
    this.disabledVariants = const [],
  });

  const SimulcastConfig.disabled() : this(enabled: false);

  /// Simulcast with every layer enabled.
  const SimulcastConfig.allVariants()
    : this(enabled: true, enabledVariants: Variant.values);

  /// Whether the track is sent in several layers.
  final bool enabled;

  /// Layers being sent.
  final List<Variant> enabledVariants;

  /// Layers not being sent.
  final List<Variant> disabledVariants;

  SimulcastConfig copyWith({
    bool? enabled,
    List<Variant>? enabledVariants,
    List<Variant>? disabledVariants,
  }) => SimulcastConfig(
    enabled: enabled ?? this.enabled,
    enabledVariants: enabledVariants ?? this.enabledVariants,
    disabledVariants: disabledVariants ?? this.disabledVariants,
  );

  @override
  bool operator ==(Object other) =>
      other is SimulcastConfig &&
      other.enabled == enabled &&
      _sameList(other.enabledVariants, enabledVariants) &&
      _sameList(other.disabledVariants, disabledVariants);

  @override
  int get hashCode => Object.hash(
    enabled,
    Object.hashAll(enabledVariants),
    Object.hashAll(disabledVariants),
  );

  @override
  String toString() =>
      'SimulcastConfig(enabled: $enabled, enabled: $enabledVariants, '
      'disabled: $disabledVariants)';
}

/// Maximum bandwidth of an outgoing track, in kbps (1 kbps = 1024 bps).
///
/// Video limits are clamped to `singleStreamCapKbps` / `simulcastCapsKbps`;
/// `0` means "use the cap". Audio limits are applied as given.
@immutable
sealed class BandwidthLimit {
  const BandwidthLimit();

  /// One limit for the whole track. On a simulcast track it is split across
  /// the layers proportionally to their pixel count.
  const factory BandwidthLimit.single(int kbps) = SingleBandwidthLimit;

  /// Per-layer limits for a simulcast track. Missing layers use their cap.
  const factory BandwidthLimit.simulcast(Map<Variant, int> kbpsPerVariant) =
      SimulcastBandwidthLimit;

  /// No explicit limit (`single(0)`).
  static const BandwidthLimit unlimited = SingleBandwidthLimit(0);
}

/// One limit for the whole track, in kbps.
final class SingleBandwidthLimit extends BandwidthLimit {
  const SingleBandwidthLimit(this.kbps);

  /// The limit in kbps; `0` means "use the cap".
  final int kbps;

  @override
  bool operator ==(Object other) =>
      other is SingleBandwidthLimit && other.kbps == kbps;

  @override
  int get hashCode => kbps.hashCode;

  @override
  String toString() => 'BandwidthLimit.single($kbps)';
}

/// Per-layer limits, in kbps.
final class SimulcastBandwidthLimit extends BandwidthLimit {
  const SimulcastBandwidthLimit(this.kbpsPerVariant);

  /// Limit per layer; iteration order is low, medium, high once resolved.
  final Map<Variant, int> kbpsPerVariant;

  @override
  bool operator ==(Object other) {
    if (other is! SimulcastBandwidthLimit) return false;
    if (other.kbpsPerVariant.length != kbpsPerVariant.length) return false;
    for (final entry in kbpsPerVariant.entries) {
      if (other.kbpsPerVariant[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    kbpsPerVariant.entries.map((e) => Object.hash(e.key, e.value)),
  );

  @override
  String toString() => 'BandwidthLimit.simulcast($kbpsPerVariant)';
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
