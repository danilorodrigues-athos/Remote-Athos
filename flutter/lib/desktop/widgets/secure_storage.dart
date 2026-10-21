import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

const _kEncryptedPrefix = 'enc:';

final class _DataBlob extends Struct {
  @Uint32()
  external int cbData;
  external Pointer<Uint8> pbData;
}

typedef _CryptProtectDataC = Int32 Function(
    Pointer<_DataBlob>,
    Pointer<Uint16>,
    Pointer<_DataBlob>,
    Pointer<Void>,
    Pointer<Void>,
    Uint32,
    Pointer<_DataBlob>);
typedef _CryptProtectDataDart = int Function(
    Pointer<_DataBlob>,
    Pointer<Uint16>,
    Pointer<_DataBlob>,
    Pointer<Void>,
    Pointer<Void>,
    int,
    Pointer<_DataBlob>);

typedef _CryptUnprotectDataC = Int32 Function(
    Pointer<_DataBlob>,
    Pointer<Pointer<Uint16>>,
    Pointer<_DataBlob>,
    Pointer<Void>,
    Pointer<Void>,
    Uint32,
    Pointer<_DataBlob>);
typedef _CryptUnprotectDataDart = int Function(
    Pointer<_DataBlob>,
    Pointer<Pointer<Uint16>>,
    Pointer<_DataBlob>,
    Pointer<Void>,
    Pointer<Void>,
    int,
    Pointer<_DataBlob>);

/// DPAPI with `CRYPTPROTECT_LOCAL_MACHINE`: any user on this machine can open
/// the value, so elevating the app does not lose the saved passwords.
const _kLocalMachine = 0x4;

/// Encrypts and decrypts catalog secrets with the Windows DPAPI.
///
/// Only Windows is supported; other platforms keep the value untouched.
class SecureStorage {
  SecureStorage._();

  static bool get supported => Platform.isWindows;

  static _CryptProtectDataDart? _protect;
  static _CryptUnprotectDataDart? _unprotect;
  static Pointer<NativeFunction<IntPtr Function(IntPtr)>>? _localFree;

  static void _init() {
    if (_protect != null) return;
    final crypt32 = DynamicLibrary.open('crypt32.dll');
    _protect = crypt32
        .lookupFunction<_CryptProtectDataC, _CryptProtectDataDart>(
            'CryptProtectData');
    _unprotect = crypt32
        .lookupFunction<_CryptUnprotectDataC, _CryptUnprotectDataDart>(
            'CryptUnprotectData');
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    _localFree = kernel32
        .lookup<NativeFunction<IntPtr Function(IntPtr)>>('LocalFree');
  }

  /// Returns `enc:<base64>` on success, or null when encryption is unavailable.
  static String? encrypt(String plain) {
    if (!supported || plain.isEmpty) return null;
    try {
      _init();
      final bytes = Uint8List.fromList(utf8.encode(plain));
      final input = calloc<Uint8>(bytes.length);
      input.asTypedList(bytes.length).setAll(0, bytes);
      final inBlob = calloc<_DataBlob>();
      inBlob.ref
        ..cbData = bytes.length
        ..pbData = input;
      final outBlob = calloc<_DataBlob>();
      final ok = _protect!(inBlob, nullptr, nullptr, nullptr, nullptr,
          _kLocalMachine, outBlob);
      if (ok == 0) {
        calloc.free(input);
        calloc.free(inBlob);
        calloc.free(outBlob);
        return null;
      }
      final encrypted = outBlob.ref.pbData.asTypedList(outBlob.ref.cbData);
      final result = _kEncryptedPrefix + base64Encode(encrypted);
      _freeBlob(outBlob.ref.pbData);
      calloc.free(input);
      calloc.free(inBlob);
      calloc.free(outBlob);
      return result;
    } catch (e) {
      debugPrint('secure encrypt failed: $e');
      return null;
    }
  }

  /// Decrypts a `enc:<base64>` value. Returns the plain text, or null when it
  /// cannot be decrypted (different machine/user or corrupted data).
  static String? decrypt(String? value) {
    if (value == null || !value.startsWith(_kEncryptedPrefix)) return value;
    if (!supported) return null;
    try {
      _init();
      final bytes = base64Decode(value.substring(_kEncryptedPrefix.length));
      final input = calloc<Uint8>(bytes.length);
      input.asTypedList(bytes.length).setAll(0, bytes);
      final inBlob = calloc<_DataBlob>();
      inBlob.ref
        ..cbData = bytes.length
        ..pbData = input;
      final outBlob = calloc<_DataBlob>();
      final desc = calloc<Pointer<Uint16>>();
      final ok = _unprotect!(inBlob, desc, nullptr, nullptr, nullptr,
          _kLocalMachine, outBlob);
      if (ok == 0) {
        calloc.free(input);
        calloc.free(inBlob);
        calloc.free(outBlob);
        calloc.free(desc);
        return null;
      }
      final plain = outBlob.ref.pbData.asTypedList(outBlob.ref.cbData);
      final result = utf8.decode(plain, allowMalformed: true);
      _freeBlob(outBlob.ref.pbData);
      if (!desc.value.isNull) _freeBlob(desc.value.cast());
      calloc.free(input);
      calloc.free(inBlob);
      calloc.free(outBlob);
      calloc.free(desc);
      return result;
    } catch (e) {
      debugPrint('secure decrypt failed: $e');
      return null;
    }
  }

  static void _freeBlob(Pointer<Uint8> pointer) {
    if (pointer.isNull) return;
    _localFree!(pointer.address);
  }
}
