import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

enum MicrophonePermissionStatus {
  granted,
  denied,
  permanentlyDenied,
}

class VoiceService {
  VoiceService._();

  static final SpeechToText _speech = SpeechToText();
  static bool _initialized = false;
  static bool _available = false;
  static bool _keepListening = false;

  static void Function(String)? _onInterim;
  static void Function(String)? _onFinal;
  static void Function(String)? _onError;
  static void Function()? _onEnd;
  static String Function()? _getAccumulatedText;

  static Timer? _restartTimer;
  static String _lastRecognizedWords = '';

  static bool get isListening => _speech.isListening;
  static bool get isSupported => true;

  static Future<MicrophonePermissionStatus> ensureMicrophonePermission() async {
    if (kIsWeb) {
      return MicrophonePermissionStatus.granted;
    }

    var microphone = await Permission.microphone.status;
    if (microphone.isDenied) {
      microphone = await Permission.microphone.request();
    }
    if (microphone.isPermanentlyDenied) {
      return MicrophonePermissionStatus.permanentlyDenied;
    }
    if (!microphone.isGranted) {
      return MicrophonePermissionStatus.denied;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      var speech = await Permission.speech.status;
      if (speech.isDenied || speech.isLimited) {
        speech = await Permission.speech.request();
      }
      if (speech.isPermanentlyDenied) {
        return MicrophonePermissionStatus.permanentlyDenied;
      }
      if (!speech.isGranted) {
        return MicrophonePermissionStatus.denied;
      }
    }

    return MicrophonePermissionStatus.granted;
  }

  static Future<bool> startListening({
    void Function(String)? onInterim,
    void Function(String)? onFinal,
    void Function(String)? onError,
    void Function()? onEnd,
    String Function()? getAccumulatedText,
  }) async {
    debugPrint('[Voice] startListening called');
    _onInterim = onInterim;
    _onFinal = onFinal;
    _onError = onError;
    _onEnd = onEnd;
    _getAccumulatedText = getAccumulatedText;

    final permission = await ensureMicrophonePermission();
    debugPrint('[Voice] Permission status: $permission');
    if (permission == MicrophonePermissionStatus.permanentlyDenied) {
      _onError?.call(
        'Microphone access is blocked. Open Settings to allow Remell to use your microphone.',
      );
      return false;
    }
    if (permission == MicrophonePermissionStatus.denied) {
      _onError?.call(
        'Microphone permission is required to transcribe your voice.',
      );
      return false;
    }

    if (!_initialized) {
      debugPrint('[Voice] Initializing SpeechToText...');
      _available = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
      );
      _initialized = true;
      debugPrint('[Voice] SpeechToText initialized. Available: $_available');
    }

    if (_available != true) {
      debugPrint('[Voice] Speech recognition is NOT available on this device');
      _onError?.call('Speech recognition is not available on this device.');
      return false;
    }

    _keepListening = true;
    await _beginRecognitionWindow();
    return true;
  }

  static Future<String?> _pickLocaleId({String? accumulatedText}) async {
    if (!_initialized) return null;
    try {
      final locales = await _speech.locales();
      
      String? cleanLocale(String? loc) {
        if (loc == null) return null;
        if (kIsWeb) return loc.replaceAll('_', '-');
        return loc;
      }

      String? findLocale(List<String> prefixes) {
        for (final prefix in prefixes) {
          for (final locale in locales) {
            final id = locale.localeId.toLowerCase().replaceAll('_', '-');
            final target = prefix.toLowerCase().replaceAll('_', '-');
            if (id == target || id.startsWith(target)) {
              return cleanLocale(locale.localeId);
            }
          }
        }
        return null;
      }

      // Explicitly check for Tagalog/Filipino locales (fil-PH, fil, tl-PH, tl)
      final tagalogLocale = findLocale(['fil-PH', 'fil_PH', 'fil', 'tl-PH', 'tl_PH', 'tl']);
      if (tagalogLocale != null) {
        debugPrint('[Voice] Tagalog/Filipino locale selected: $tagalogLocale');
        return tagalogLocale;
      }

      final systemLocale = await _speech.systemLocale();
      final sysPicked = cleanLocale(systemLocale?.localeId);
      if (sysPicked != null) {
        debugPrint('[Voice] Using system locale: $sysPicked');
        return sysPicked;
      }

      return kIsWeb ? 'fil-PH' : 'en-US';
    } catch (e) {
      debugPrint('[Voice] Failed picking locale: ' + e.toString());
      return kIsWeb ? 'fil-PH' : null;
    }
  }

  static Future<void> _beginRecognitionWindow() async {
    debugPrint('[Voice] _beginRecognitionWindow. _keepListening: $_keepListening, isListening: ${_speech.isListening}');
    if (!_keepListening || _speech.isListening) return;

    final accumulated = _getAccumulatedText?.call() ?? '';
    final localeId = await _pickLocaleId(accumulatedText: accumulated);
    debugPrint('[Voice] Starting continuous SpeechToText listen with locale: $localeId');

    try {
      await _speech.listen(
        onResult: _handleResult,
        localeId: localeId,
        listenFor: const Duration(hours: 1),
        pauseFor: const Duration(seconds: 20),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          autoPunctuation: true,
        ),
      );
      debugPrint('[Voice] Continuous SpeechToText listen call active');
    } catch (error) {
      debugPrint('[Voice] Exception in _speech.listen: $error');
      if (_keepListening) {
        _restartTimer?.cancel();
        _restartTimer = Timer(
          const Duration(milliseconds: 150),
          _beginRecognitionWindow,
        );
      }
    }
  }

  static void _handleResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    debugPrint('[Voice] _handleResult words: "$words", final: ${result.finalResult}');
    _lastRecognizedWords = words;
    if (words.isEmpty) return;
    if (result.finalResult) {
      _onInterim?.call('');
      _onFinal?.call(words);
      _lastRecognizedWords = '';
    } else {
      _onInterim?.call(words);
    }
  }

  static void _handleStatus(String status) {
    debugPrint('[Voice] _handleStatus status: "$status", _keepListening: $_keepListening');
    if (!_keepListening) return;
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      if (_lastRecognizedWords.isNotEmpty) {
        debugPrint('[Voice] Finalizing words on status change: $_lastRecognizedWords');
        _onFinal?.call(_lastRecognizedWords);
        _lastRecognizedWords = '';
      }
      debugPrint('[Voice] Speech recognition paused, auto-restarting continuous dictation...');
      _restartTimer?.cancel();
      _restartTimer = Timer(
        const Duration(milliseconds: 50),
        _beginRecognitionWindow,
      );
    }
  }

  static void _handleError(SpeechRecognitionError error) {
    debugPrint('[Voice] _handleError: Msg: "${error.errorMsg}", Permanent: ${error.permanent}');
    if (error.permanent) {
      if (_lastRecognizedWords.isNotEmpty) {
        _onFinal?.call(_lastRecognizedWords);
        _lastRecognizedWords = '';
      }
      _onError?.call(error.errorMsg);
      // Auto restart continuous dictation even if transient error occurs
      if (_keepListening) {
        _restartTimer?.cancel();
        _restartTimer = Timer(
          const Duration(milliseconds: 200),
          _beginRecognitionWindow,
        );
      }
      return;
    }
    if (_keepListening) {
      if (_lastRecognizedWords.isNotEmpty) {
        debugPrint('[Voice] Finalizing words on error restart: $_lastRecognizedWords');
        _onFinal?.call(_lastRecognizedWords);
        _lastRecognizedWords = '';
      }
      debugPrint('[Voice] Non-permanent error, scheduling continuous restart...');
      _restartTimer?.cancel();
      _restartTimer = Timer(
        const Duration(milliseconds: 100),
        _beginRecognitionWindow,
      );
    }
  }

  static Future<void> stopListening() async {
    debugPrint('[Voice] stopListening called');
    _keepListening = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    if (_lastRecognizedWords.isNotEmpty) {
      debugPrint('[Voice] Finalizing words on manual stop: $_lastRecognizedWords');
      _onFinal?.call(_lastRecognizedWords);
      _lastRecognizedWords = '';
    }
    if (_speech.isListening) {
      debugPrint('[Voice] Stopping SpeechToText');
      await _speech.stop();
    }
    _onInterim?.call('');
    _onEnd?.call();
  }
}