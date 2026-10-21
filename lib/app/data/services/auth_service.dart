import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mangaplus/app/data/models/user_profile.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection('userProfiles');

  Future<UserProfile?> loadProfile(String uid) async {
    final doc = await _profiles.doc(uid).get();
    return doc.exists ? UserProfile.fromFirestore(doc) : null;
  }

  Future<UserProfile> registerEmail({
    required String displayName,
    required String username,
    required String email,
    required String password,
    required String countryCode,
    required String countryName,
    required DateTime birthDate,
  }) async {
    final normalized = normalizeUsername(username);
    validateUsername(normalized);
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw const AuthException('تعذر إنشاء الحساب.');
    try {
      await _reserveUsernameAndCreateProfile(
        user: user,
        normalized: normalized,
        displayName: displayName.trim(),
        countryCode: countryCode,
        countryName: countryName,
        birthDate: birthDate,
      );
      await user.sendEmailVerification();
      return (await loadProfile(user.uid))!;
    } catch (_) {
      await user.delete().catchError((_) {});
      rethrow;
    }
  }

  Future<UserProfile> signInEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw const AuthException('تعذر تسجيل الدخول.');
    await user.reload();
    final profile = await loadProfile(user.uid);
    if (profile == null) throw const AuthException('بيانات الحساب غير مكتملة.');
    return profile;
  }

  Future<UserProfile?> signInGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    final authentication = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: authentication.accessToken,
      idToken: authentication.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user == null) throw const AuthException('تعذر تسجيل الدخول باستخدام Google.');
    final profile = await loadProfile(user.uid);
    return profile ?? UserProfile(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? '',
          username: '',
          countryCode: '',
          countryName: '',
          createdAt: DateTime.now(),
          photoUrl: user.photoURL ?? '',
          emailVerified: user.emailVerified,
        );
  }

  Future<UserProfile> completeGoogleProfile({
    required String username,
    required String countryCode,
    required String countryName,
    required DateTime birthDate,
  }) async {
    final user = currentUser;
    if (user == null) throw const AuthException('انتهت جلسة التسجيل.');
    final normalized = normalizeUsername(username);
    validateUsername(normalized);
    await _reserveUsernameAndCreateProfile(
      user: user,
      normalized: normalized,
      displayName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : normalized,
      countryCode: countryCode,
      countryName: countryName,
      birthDate: birthDate,
    );
    return (await loadProfile(user.uid))!;
  }

  Future<UserProfile> continueAsGuest() async {
    final result = await _auth.signInAnonymously();
    final user = result.user;
    if (user == null) throw const AuthException('تعذر بدء وضع الضيف.');
    final existing = await loadProfile(user.uid);
    if (existing != null) return existing;
    final profile = UserProfile(
      uid: user.uid,
      email: '',
      displayName: 'قارئ MangaPlus',
      username: 'guest_${user.uid.substring(0, 6)}',
      countryCode: '',
      countryName: '',
      createdAt: DateTime.now(),
      isGuest: true,
    );
    await _profiles.doc(user.uid).set(profile.toFirestore());
    return profile;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> resendVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || user.emailVerified) return;
    await user.sendEmailVerification();
  }

  Future<UserProfile> refreshProfile() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('لا يوجد مستخدم مسجل.');
    await user.reload();
    final profile = await loadProfile(user.uid);
    if (profile == null) throw const AuthException('بيانات الحساب غير مكتملة.');
    return profile;
  }

  Future<UserProfile> updateProfile({
    required String displayName,
    required String bio,
    required UserPrivacy privacy,
  }) async {
    final user = currentUser;
    if (user == null || user.isAnonymous) {
      throw const AuthException('يجب تسجيل الدخول بحساب دائم لتعديل الملف.');
    }
    await _profiles.doc(user.uid).update({
      'displayName': displayName.trim(),
      'bio': bio.trim(),
      'privacy': privacy.toMap(),
    });
    return (await loadProfile(user.uid))!;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut().catchError((_) {});
    await _auth.signOut();
  }

  Future<void> _reserveUsernameAndCreateProfile({
    required User user,
    required String normalized,
    required String displayName,
    required String countryCode,
    required String countryName,
    required DateTime birthDate,
  }) async {
    final usernameRef = _firestore.collection('usernames').doc(normalized);
    final profileRef = _profiles.doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final reserved = await transaction.get(usernameRef);
      if (reserved.exists && '${reserved.data()?['uid']}' != user.uid) {
        throw const AuthException('اسم المستخدم مستخدم بالفعل.');
      }
      final profile = UserProfile(
        uid: user.uid,
        email: user.email ?? '',
        displayName: displayName,
        username: normalized,
        countryCode: countryCode,
        countryName: countryName,
        createdAt: DateTime.now(),
        birthDate: birthDate,
        emailVerified: user.emailVerified,
        isGuest: user.isAnonymous,
      );
      transaction.set(usernameRef, {
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(profileRef, profile.toFirestore());
    });
  }

  static String normalizeUsername(String value) => value.trim().toLowerCase();

  static void validateUsername(String value) {
    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(value)) {
      throw const AuthException(
        'اسم المستخدم يجب أن يتكون من 3 إلى 24 حرفًا إنجليزيًا أو رقمًا أو _.',
      );
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
