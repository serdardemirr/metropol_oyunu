import 'package:firebase_auth/firebase_auth.dart';

/// Anonim giriş: kullanıcıdan e-posta/şifre istemeden her cihaza kalıcı bir
/// uid verir. Firestore güvenlik kuralları bu uid'e dayanır.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  String? get uid => _auth.currentUser?.uid;

  Future<String> ensureSignedIn() async {
    final current = _auth.currentUser;
    if (current != null) return current.uid;
    final cred = await _auth.signInAnonymously();
    return cred.user!.uid;
  }
}
