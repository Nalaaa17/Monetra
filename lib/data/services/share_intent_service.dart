import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SharedReceiptPayload {
  final String? imagePath;
  final String? text;

  const SharedReceiptPayload({
    this.imagePath,
    this.text,
  });

  bool get hasImage => imagePath != null && imagePath!.trim().isNotEmpty;
  bool get hasText => text != null && text!.trim().isNotEmpty;
  bool get isEmpty => !hasImage && !hasText;

  static SharedReceiptPayload? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final imagePath = raw['imagePath']?.toString();
    final text = raw['text']?.toString();
    final payload = SharedReceiptPayload(
      imagePath: (imagePath != null && imagePath.trim().isNotEmpty)
          ? imagePath.trim()
          : null,
      text: (text != null && text.trim().isNotEmpty) ? text.trim() : null,
    );
    return payload.isEmpty ? null : payload;
  }
}

/// Menyimpan payload resi yang baru dibagikan dari luar aplikasi (m-banking / galeri)
/// agar bisa dikonsumsi sekali saat `AddTransactionScreen` terbuka.
final pendingSharedReceiptProvider =
    StateProvider<SharedReceiptPayload?>((ref) => null);

class ShareIntentService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.monetra.monetra/share');
  static const EventChannel _eventChannel =
      EventChannel('com.monetra.monetra/share/events');

  static bool get _isSupportedPlatform => !kIsWeb && Platform.isAndroid;

  static Future<SharedReceiptPayload?> getInitialShare() async {
    if (!_isSupportedPlatform) return null;
    try {
      final raw = await _methodChannel.invokeMethod<dynamic>('getInitialShare');
      return SharedReceiptPayload.fromMap(raw);
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('Error reading initial share: $e');
      return null;
    }
  }

  static Stream<SharedReceiptPayload> shareStream() {
    if (!_isSupportedPlatform) {
      return const Stream<SharedReceiptPayload>.empty();
    }
    return _eventChannel.receiveBroadcastStream().transform(
      StreamTransformer<dynamic, SharedReceiptPayload>.fromHandlers(
        handleData: (data, sink) {
          final payload = SharedReceiptPayload.fromMap(data);
          if (payload != null) {
            sink.add(payload);
          }
        },
        handleError: (error, stackTrace, sink) {
          debugPrint('Error on share event stream: $error');
        },
      ),
    );
  }
}
