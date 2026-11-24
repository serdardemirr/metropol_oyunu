import 'package:flutter/material.dart';

import '../models/pawn_token.dart';
import '../services/app_services.dart';
import '../services/profile_service.dart';
import '../widgets/pawn_picker.dart';
import 'home_screen.dart';

/// Kullanıcı adı + piyon seçimi.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.initial});

  final UserProfile? initial;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late PawnToken _pawn = widget.initial?.pawn ?? PawnToken.initial;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final profile = UserProfile(name: _name.text.trim(), pawn: _pawn);
    await AppServices.profile.save(profile);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(profile: profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profilini Oluştur')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _name,
                maxLength: ProfileService.maxNameLength,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı Adı',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: ProfileService.validateName,
              ),
              const SizedBox(height: 24),
              Text('Piyonunu seç',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              PawnPicker(
                value: _pawn,
                onChanged: (p) => setState(() => _pawn = p),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: const Text('Kaydet ve Devam Et'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
