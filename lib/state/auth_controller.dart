import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../repositories/repository.dart';
import '../repositories/repository_exception.dart';

/// Holds the authenticated user and exposes authentication operations.
class AuthController extends ChangeNotifier {
  final IRepository repo;
  StreamSubscription<AppUser?>? _sub;

  AppUser? _user;
  bool _busy = false;
  String? _error;

  AuthController(this.repo) {
    _sub = repo.onAuthStateChanged.listen((user) {
      _user = user;
      _error = null;
      notifyListeners();
    });
  }

  AppUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get busy => _busy;
  String? get error => _error;

  bool get isCitizen => _user?.role == UserRole.citizen;
  bool get isResponder => _user?.role == UserRole.responder;
  bool get isAdmin => _user?.role == UserRole.administrator;

  Future<bool> signIn(String email, String password) => _run(() async {
        await repo.signIn(email, password);
        return true;
      });

  Future<bool> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
    required UserRole role,
  }) =>
      _run(() async {
        await repo.signUp(
          name: name,
          phone: phone,
          email: email,
          password: password,
          role: role,
        );
        return true;
      });

  Future<bool> signOut() => _run(() async {
        await repo.signOut();
        return true;
      });

  Future<bool> resetPassword(String email) => _run(() async {
        await repo.resetPassword(email);
        return true;
      });

  Future<bool> updateProfile({String? name, String? phone}) => _run(() async {
        await repo.updateProfile(name: name, phone: phone);
        return true;
      });

  Future<bool> _run(Future<bool> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      return await action();
    } catch (e) {
      _error = RepositoryException.messageOf(e);
      notifyListeners();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}