import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A capability the reporter can hold onto without the app ever storing their
/// identity alongside the report.
///
/// The plain code is shown exactly once and never persisted. Only its SHA-256
/// digest is stored, and that digest *is* the Firestore document id. Because a
/// 128-bit random code cannot be brute-forced through a digest lookup, holding
/// the code is proof of authorship — which is what lets a reporter withdraw or
/// follow an anonymous report without the app ever learning who they are.
class WithdrawalCode {
  /// Human-friendly and hard to mistype: 4 groups of 4 uppercase letters.
  static const int groups = 4;
  static const int groupLength = 4;

  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final Random _random = Random.secure();

  final String code;
  final String token;

  const WithdrawalCode({required this.code, required this.token});

  /// Generates a fresh code. The returned plain [code] is shown to the user and
  /// never stored anywhere.
  factory WithdrawalCode.generate() {
    final buffer = StringBuffer();
    for (var i = 0; i < groups * groupLength; i++) {
      buffer.write(_alphabet[_random.nextInt(_alphabet.length)]);
    }
    return WithdrawalCode.fromCode(buffer.toString());
  }

  /// Accepts anything the reporter might type and returns the canonical form,
  /// so the code is displayed identically however it was entered.
  factory WithdrawalCode.fromCode(String code) {
    final normalized = normalize(code);
    return WithdrawalCode(code: format(normalized), token: digest(normalized));
  }

  /// Uppercases and strips separators so "abcd-efgh" and "ABCD EFGH" match.
  static String normalize(String code) =>
      code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Puts the group separators back, so a code is always read in 4 groups of 4
  /// however it was typed.
  static String format(String code) {
    final normalized = normalize(code);
    final buffer = StringBuffer();
    for (var i = 0; i < normalized.length; i++) {
      if (i > 0 && i % groupLength == 0) buffer.write('-');
      buffer.write(normalized[i]);
    }
    return buffer.toString();
  }

  /// True when the code has the right shape, so obviously mistyped input is
  /// rejected without a database round trip.
  static bool isWellFormedCode(String code) =>
      normalize(code).length == groups * groupLength;

  /// The Firestore document id: irreversible, so a leaked database does not
  /// hand out the ability to withdraw anyone's report.
  static String digest(String code) =>
      sha256.convert(utf8.encode(normalize(code))).toString();

  bool get isWellFormed => WithdrawalCode.isWellFormedCode(code);

  @override
  String toString() => code;
}
