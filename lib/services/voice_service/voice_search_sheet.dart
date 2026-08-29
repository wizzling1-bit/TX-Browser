import 'package:flutter/material.dart';
import 'package:tx_browser/core/theme/tx_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../widgets/buttons/tx_button.dart';

/// Modal bottom sheet that listens to user voice input using real Android speech recognition.
class VoiceSearchSheet extends StatefulWidget {
  const VoiceSearchSheet({
    super.key,
    required this.onResult,
  });

  final ValueChanged<String> onResult;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<String> onResult,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceSearchSheet(onResult: onResult),
    );
  }

  @override
  State<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _wordsSpoken = '';
  String _statusText = 'Initializing voice engine...';
  String? _errorMessage;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _initAndStartListening();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    if (_isListening) {
      _speech.stop();
    }
    super.dispose();
  }

  Future<void> _initAndStartListening() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        setState(() {
          _errorMessage = 'Microphone permission is required for voice search.';
          _statusText = 'Permission Denied';
        });
        return;
      }

      final available = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );

      if (!mounted) return;

      if (available) {
        setState(() {
          _statusText = 'Listening... Speak now';
          _errorMessage = null;
        });
        _startListening();
      } else {
        setState(() {
          _errorMessage = 'Speech recognition is not available on this device.';
          _statusText = 'Unavailable';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not start voice search: $e';
          _statusText = 'Error';
        });
      }
    }
  }

  void _startListening() async {
    _wordsSpoken = '';
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _wordsSpoken = result.recognizedWords;
        });

        if (result.finalResult && _wordsSpoken.trim().isNotEmpty) {
          _finishWithResult(_wordsSpoken.trim());
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.search,
        cancelOnError: true,
        partialResults: true,
      ),
    );

    if (mounted) {
      setState(() => _isListening = true);
    }
  }

  void _onError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() {
      _isListening = false;
      if (error.errorMsg.contains('error_no_match') ||
          error.errorMsg.contains('error_speech_timeout')) {
        _errorMessage = 'No speech heard. Please try again.';
      } else {
        _errorMessage = error.errorMsg;
      }
      _statusText = 'Tap to try again';
    });
  }

  void _onStatus(String status) {
    if (!mounted) return;
    if (status == 'notListening' || status == 'done') {
      setState(() {
        _isListening = false;
      });
      if (_wordsSpoken.trim().isNotEmpty) {
        _finishWithResult(_wordsSpoken.trim());
      }
    }
  }

  void _finishWithResult(String text) {
    Navigator.of(context).pop();
    widget.onResult(text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<TxColorScheme>()!;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: TxSpacing.xl,
        right: TxSpacing.xl,
        top: TxSpacing.lg,
        bottom: MediaQuery.of(context).padding.bottom + TxSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: TxSpacing.xl),

          // Microphone Ripple Animated Sphere
          GestureDetector(
            onTap: () {
              if (!_isListening && _errorMessage != null) {
                _initAndStartListening();
              }
            },
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (context, child) {
                final scale = _isListening ? 1.0 + (_animCtrl.value * 0.12) : 1.0;
                final glowAlpha = _isListening ? 0.25 + (_animCtrl.value * 0.25) : 0.08;

                return Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _errorMessage != null
                        ? colors.error.withValues(alpha: 0.15)
                        : colors.primary.withValues(alpha: glowAlpha),
                    border: Border.all(
                      color: _errorMessage != null
                          ? colors.error
                          : colors.primary.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: _isListening
                        ? [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.3),
                              blurRadius: 20 * scale,
                              spreadRadius: 4 * scale,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _errorMessage != null
                              ? colors.error
                              : colors.primary,
                        ),
                        child: Icon(
                          _errorMessage != null
                              ? LucideIcons.micOff
                              : LucideIcons.mic,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: TxSpacing.lg),

          // Status / Transcription text
          Text(
            _wordsSpoken.isNotEmpty
                ? '"$_wordsSpoken"'
                : (_errorMessage ?? _statusText),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _errorMessage != null
                      ? colors.error
                      : colors.textPrimary,
                ),
          ),
          const SizedBox(height: TxSpacing.xs),
          Text(
            _isListening
                ? 'Try saying "wikipedia.org" or "latest space news"'
                : (_errorMessage != null
                    ? 'Tap the microphone icon to retry'
                    : 'Searching DuckDuckGo'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
          ),

          const SizedBox(height: TxSpacing.xl),

          // Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_wordsSpoken.isNotEmpty)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: TxSpacing.sm),
                    child: TxButton(
                      label: 'Search Now',
                      icon: LucideIcons.search,
                      onPressed: () => _finishWithResult(_wordsSpoken),
                    ),
                  ),
                ),
              Expanded(
                child: TxButton(
                  label: _errorMessage != null ? 'Close' : 'Cancel',
                  variant: TxButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
