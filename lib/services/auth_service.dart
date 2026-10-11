import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _dbOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  /// Default constructor — uses the real Firebase singletons.
  AuthService()
      : _authOverride = null,
        _dbOverride = null;

  /// Injectable constructor for testing — accepts a fake/mock Firestore
  /// instance. FirebaseAuth is not accessed during Firestore-only tests.
  AuthService.withFirestore(FirebaseFirestore db)
      : _authOverride = null,
        _dbOverride = db;

  // ── Streams / getters ──────────────────────────────────────────────────────

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Email / Password ───────────────────────────────────────────────────────

  /// Sign in with email and password.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Create a new Firebase Auth account with email and password.
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Send a password-reset email.
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Firestore profile ──────────────────────────────────────────────────────

  /// Returns true if a Firestore profile document exists for [uid].
  Future<bool> profileExists(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists;
  }

  /// Fetch user profile from Firestore.
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  /// Create or overwrite a Firestore profile.
  Future<void> createUserProfile(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  /// Update specific fields on an existing Firestore profile.
  Future<void> updateUserProfile(String uid, Map<String, dynamic> fields) async {
    await _db.collection('users').doc(uid).update(fields);
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Human-readable message for [FirebaseAuthException].
  String friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
  // ── Ban check ──────────────────────────────────────────────────────────────

  /// Real-time stream of the user's ban status.
  /// Emits a DateTime (bannedUntil) when the user is actively banned,
  /// or null when not banned. Use this to react to bans applied at runtime.
  Stream<DateTime?> watchBanStatus(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final data = doc.data() ?? {};
      final bannedField = data['bannedUntil'];
      if (bannedField == null) return null;
      DateTime? bannedUntil;
      if (bannedField is Timestamp) {
        bannedUntil = bannedField.toDate();
      } else {
        bannedUntil = DateTime.tryParse(bannedField.toString());
      }
      if (bannedUntil != null && bannedUntil.isAfter(DateTime.now())) {
        return bannedUntil;
      }
      return null;
    });
  }

  /// Returns the bannedUntil DateTime if the user is currently banned,
  /// or null if they are not banned (or the field doesn't exist).
  Future<DateTime?> getBanStatus(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final bannedField = data['bannedUntil'];
      if (bannedField == null) return null;

      DateTime? bannedUntil;
      if (bannedField is Timestamp) {
        bannedUntil = bannedField.toDate();
      } else {
        bannedUntil = DateTime.tryParse(bannedField.toString());
      }

      // Only return if the ban is still active
      if (bannedUntil != null && bannedUntil.isAfter(DateTime.now())) {
        return bannedUntil;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
