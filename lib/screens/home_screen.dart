import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/game_rules.dart';
import '../services/app_services.dart';
import '../services/profile_service.dart';
import '../services/room_repository.dart';
import '../widgets/pawn_avatar.dart';
import 'profile_screen.dart';
import 'room_screen.dart';

/// "Oda Kur" / "Odaya Katıl".
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String> Function(String uid) action) async {
    setState(() => _busy = true);
    try {
      final uid = await AppServices.auth.ensureSignedIn();
      final code = await action(uid);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoomScreen(code: code)),
      );
    } on RoomException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('Bağlantı hatası: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _create() => _run(
        (uid) => AppServices.rooms.createRoom(uid: uid, profile: widget.profile),
      );

  Future<void> _join() => _run((uid) async {
        final result = await AppServices.rooms.joinRoom(
          code: _code.text.trim(),
          uid: uid,
          profile: widget.profile,
        );
        if (result.reassignedPawn != null) {
          _toast('Piyonun başkasında olduğu için '
              '${result.reassignedPawn!.label} verildi.');
        }
        return result.code;
      });

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('METROPOL'),
        actions: [
          IconButton(
            tooltip: 'Profili düzenle',
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => ProfileScreen(initial: p)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                PawnAvatar(pawn: p.pawn, size: 56),
                const SizedBox(width: 16),
                Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 40),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56)),
              onPressed: _busy ? null : _create,
              icon: const Icon(Icons.add_home_work),
              label: const Text('Oda Kur'),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: GameRules.roomCodeLength,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, letterSpacing: 12),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Oda Kodu',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onSubmitted: (_) => _busy ? null : _join(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56)),
              onPressed: _busy ? null : _join,
              icon: const Icon(Icons.login),
              label: const Text('Odaya Katıl'),
            ),
            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
