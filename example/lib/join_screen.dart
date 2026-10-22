import 'package:fishjam_client/fishjam_client.dart';
import 'package:flutter/material.dart';

import 'room_screen.dart';
import 'sandbox.dart';

enum _Mode { peerToken, sandbox }

/// Collects the credentials: a Fishjam URL and a peer token from your
/// backend, or (prototyping only) a Sandbox API URL.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'flutter');
  // Optional prefill from dart-defines; see example/.env.example.
  final _fishjamUrl = TextEditingController(
    text: const String.fromEnvironment('FISHJAM_ID'),
  );
  final _peerToken = TextEditingController(
    text: const String.fromEnvironment('PEER_TOKEN'),
  );
  final _sandboxUrl = TextEditingController(text: _sandboxUrlDefine);
  final _roomName = TextEditingController(text: 'flutter-room');
  _Mode _mode = _sandboxUrlDefine.isEmpty ? _Mode.peerToken : _Mode.sandbox;

  static const _sandboxUrlDefine = String.fromEnvironment('SANDBOX_API_URL');
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _fishjamUrl, _peerToken, _sandboxUrl, _roomName]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _join() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final credentials = RoomCredentials(
        url: fishjamUrlFromId(_fishjamUrl.text.trim()),
        peerToken: switch (_mode) {
          _Mode.peerToken => _peerToken.text.trim(),
          _Mode.sandbox => await fetchSandboxPeerToken(
            sandboxApiUrl: Uri.parse(_sandboxUrl.text.trim()),
            roomName: _roomName.text.trim(),
            peerName: _name.text.trim(),
          ),
        },
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RoomScreen(
            credentials: credentials,
            displayName: _name.text.trim(),
          ),
        ),
      );
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not join: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Join a Fishjam room')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(value: _Mode.peerToken, label: Text('Peer token')),
              ButtonSegment(value: _Mode.sandbox, label: Text('Sandbox API')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.single),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Display name'),
            validator: _required,
          ),
          TextFormField(
            controller: _fishjamUrl,
            decoration: const InputDecoration(
              labelText: 'Fishjam ID or URL',
              hintText: 'From the Fishjam dashboard',
            ),
            keyboardType: TextInputType.url,
            validator: _required,
          ),
          if (_mode == _Mode.peerToken) ...[
            TextFormField(
              controller: _peerToken,
              decoration: const InputDecoration(
                labelText: 'Peer token (from your backend)',
              ),
              validator: _required,
            ),
          ] else ...[
            const _SandboxWarning(),
            TextFormField(
              controller: _sandboxUrl,
              decoration: const InputDecoration(
                labelText: 'Sandbox API URL',
                hintText: 'Copy it from the Fishjam dashboard',
              ),
              keyboardType: TextInputType.url,
              validator: _required,
            ),
            TextFormField(
              controller: _roomName,
              decoration: const InputDecoration(labelText: 'Room name'),
              validator: _required,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _join,
            child: Text(_busy ? 'Joining…' : 'Join'),
          ),
        ],
      ),
    ),
  );
}

class _SandboxWarning extends StatelessWidget {
  const _SandboxWarning();

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: const Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        'For prototyping only. The Sandbox API is an unauthenticated test '
        'backend; never use it in production. In a real app, your backend '
        'creates the peer with a server SDK and gives the app its peer token.',
      ),
    ),
  );
}
