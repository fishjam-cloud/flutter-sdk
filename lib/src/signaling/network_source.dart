/// Reports which kinds of network the device uses, as the OS sees them.
abstract interface class NetworkSource {
  /// The kinds of network in use (e.g. `wifi`, `mobile`); empty when
  /// offline. Throws when the OS cannot be asked.
  Future<Set<String>> getNetworkTypes();

  /// Every report the OS makes; a report may repeat the previous one.
  Stream<Set<String>> get networkTypesChanged;
}
