import 'dart:async';

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
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '479859476328-67vu8i5cp6rttk5p6sstutjuq5kv2au5.apps.googleusercontent.com',
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _profiles =>
      _firestore.collection('userProfiles');

  Future<UserProfile?> loadProfile(String uid) async {
    final doc = await _profiles.doc(uid).get();
    if (!doc.exists) return null;
    final profile = UserProfile.fromFirestore(doc);
    final user = _auth.currentUser;
    if (user?.uid == uid && user?.isAnonymous == false) {
      return profile.copyWith(emailVerified: user!.emailVerified);
    }
    return profile;
  }

  Future<bool> isUsernameAvailable(String username) async {
    final normalized = normalizeUsername(username);
    validateUsername(normalized);
    final doc = await _firestore.collection('usernames').doc(normalized).get();
    return !doc.exists;
  }

  Future<UserProfile> registerEmail({
    required String displayName,
    required String username,
    required String email,
    required String password,
    required String countryCode,
    required String countryName,
    required DateTime birthDate,
    required String gender,
  }) async {
    final normalized = normalizeUsername(username);
    validateUsername(normalized);
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw const AuthException('تعذر إنشاء الحساب.');
    UserProfile profile;
    try {
      profile = await _reserveUsernameAndCreateProfile(
        user: user,
        normalized: normalized,
        displayName: displayName.trim(),
        countryCode: countryCode,
        countryName: countryName,
        birthDate: birthDate,
        gender: gender,
      );
    } catch (_) {
      await _firestore.collection('usernames').doc(normalized).delete().catchError((_) {});
      await user.delete().catchError((_) {});
      rethrow;
    }
    try {
      await user.sendEmailVerification();
    } catch (error) {
      throw VerificationEmailSendException(profile, error);
    }
    return profile;
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
    required String gender,
  }) async {
    final user = currentUser;
    if (user == null) throw const AuthException('انتهت جلسة التسجيل.');
    final normalized = normalizeUsername(username);
    validateUsername(normalized);
    return _reserveUsernameAndCreateProfile(
      user: user,
      normalized: normalized,
      displayName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : normalized,
      countryCode: countryCode,
      countryName: countryName,
      birthDate: birthDate,
      gender: gender,
    );
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
    return profile.copyWith(emailVerified: _auth.currentUser?.emailVerified == true);
  }

  Future<void> signOut() async {
    // End the Firebase session first so a slow Google SDK cannot leave the
    // user signed in to the app. Google provider cleanup is best-effort.
    await _auth.signOut();
    unawaited(_googleSignIn.signOut().timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    ).catchError((_) {}));
  }

  Future<UserProfile> updatePhotoData(String photoData) async {
    final user = currentUser;
    if (user == null || user.isAnonymous) {
      throw const AuthException('يجب تسجيل الدخول بحساب دائم لتعديل الصورة.');
    }
    if (photoData.length > 850000) {
      throw const AuthException('الصورة أكبر من الحد المسموح. اختر صورة أصغر.');
    }
    await _profiles.doc(user.uid).update({
      'photoData': photoData,
      'photoUrl': '',
    });
    return (await loadProfile(user.uid))!;
  }

  Future<UserProfile> updateDisplayName(String displayName) async {
    final user = currentUser;
    final value = displayName.trim();
    if (user == null || user.isAnonymous || value.isEmpty || value.length > 40) {
      throw const AuthException('الاسم الظاهر مطلوب ويجب ألا يتجاوز 40 حرفًا.');
    }
    await _profiles.doc(user.uid).update({'displayName': value});
    return (await loadProfile(user.uid))!;
  }

  Future<UserProfile> updateBio(String bio) async {
    final user = currentUser;
    final value = bio.trim();
    if (user == null || user.isAnonymous || value.length > 300) {
      throw const AuthException('تعذر حفظ النبذة، الحد الأقصى 300 حرف.');
    }
    await _profiles.doc(user.uid).update({'bio': value});
    return (await loadProfile(user.uid))!;
  }

  Future<UserProfile> setFavoritesSync(bool enabled) async {
    final user = currentUser;
    if (user == null || user.isAnonymous) {
      throw const AuthException('يجب تسجيل الدخول بحساب دائم للمزامنة.');
    }
    await _profiles.doc(user.uid).update({'syncFavorites': enabled});
    return (await loadProfile(user.uid))!;
  }

  Future<Map<String, dynamic>> loadSettings() async {
    final user = currentUser;
    if (user == null || user.isAnonymous) return const {};
    final doc = await _profiles.doc(user.uid).get();
    final value = doc.data()?['settings'];
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  Future<void> saveSettings({required String language, required String themeMode}) async {
    final user = currentUser;
    if (user == null || user.isAnonymous) return;
    await _profiles.doc(user.uid).update({
      'settings': {'language': language, 'themeMode': themeMode},
    });
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final user = currentUser;
    final email = user?.email;
    if (user == null || email == null || user.isAnonymous) {
      throw const AuthException('هذا الحساب لا يدعم تغيير كلمة المرور.');
    }
    if (!user.providerData.any((provider) => provider.providerId == 'password')) {
      throw const AuthException('تم إنشاء الحساب عبر مزود خارجي ولا يملك كلمة مرور محلية.');
    }
    final credential = EmailAuthProvider.credential(email: email, password: currentPassword);
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<UserProfile> _reserveUsernameAndCreateProfile({
    required User user,
    required String normalized,
    required String displayName,
    required String countryCode,
    required String countryName,
    required DateTime birthDate,
    required String gender,
  }) async {
    final usernameRef = _firestore.collection('usernames').doc(normalized);
    final profileRef = _profiles.doc(user.uid);
    final profile = UserProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName: displayName,
      username: normalized,
      countryCode: countryCode,
      countryName: countryName,
      createdAt: DateTime.now(),
      birthDate: birthDate,
      gender: gender,
      emailVerified: user.emailVerified,
      isGuest: user.isAnonymous,
    );
    await _firestore.runTransaction((transaction) async {
      final reserved = await transaction.get(usernameRef);
      if (reserved.exists && '${reserved.data()?['uid']}' != user.uid) {
        throw const AuthException('اسم المستخدم مستخدم بالفعل.');
      }
      transaction.set(usernameRef, {
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(profileRef, profile.toFirestore());
    });
    return profile;
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

class VerificationEmailSendException implements Exception {
  const VerificationEmailSendException(this.profile, this.cause);

  final UserProfile profile;
  final Object cause;
}
