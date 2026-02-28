import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../utils/translations.dart';

class VoiceChangerScreen extends StatefulWidget {
  const VoiceChangerScreen({super.key});

  @override
  State<VoiceChangerScreen> createState() => _VoiceChangerScreenState();
}

class _VoiceChangerScreenState extends State<VoiceChangerScreen> {
  final FlutterTts _tts = FlutterTts();
  String? _playingVoiceId;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.5);
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _playingVoiceId = null);
      }
    });
    _tts.setErrorHandler((msg) {
      if (mounted) {
        setState(() => _playingVoiceId = null);
      }
    });
  }

  Future<void> _playPreview(String voiceId, double pitch, double rate) async {
    if (_playingVoiceId == voiceId) {
      await _tts.stop();
      setState(() => _playingVoiceId = null);
      return;
    }

    await _tts.stop();
    setState(() => _playingVoiceId = voiceId);

    await _tts.setPitch(pitch);
    await _tts.setSpeechRate(rate);

    // Set TTS language based on app locale
    final locale = Translations.currentLocale;
    final ttsLang = _getTtsLanguage(locale);
    await _tts.setLanguage(ttsLang);

    final phrase = Translations.t('voice_preview_phrase');
    await _tts.speak(phrase);
  }

  String _getTtsLanguage(String locale) {
    switch (locale) {
      case 'it': return 'it-IT';
      case 'es': return 'es-ES';
      case 'fr': return 'fr-FR';
      case 'de': return 'de-DE';
      case 'pt': return 'pt-BR';
      case 'hi': return 'hi-IN';
      case 'ar': return 'ar-SA';
      case 'ja': return 'ja-JP';
      case 'ko': return 'ko-KR';
      case 'zh': return 'zh-CN';
      case 'ru': return 'ru-RU';
      case 'tr': return 'tr-TR';
      case 'nl': return 'nl-NL';
      case 'pl': return 'pl-PL';
      case 'ur': return 'ur-PK';
      case 'bn': return 'bn-BD';
      case 'pa': return 'pa-IN';
      default: return 'en-US';
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(Translations.t('voice_changer_title')),
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.border),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: AppConstants.voiceOptions.length,
        itemBuilder: (context, index) {
          final voice = AppConstants.voiceOptions[index];
          final voiceId = voice['id'] as String;
          final isSelected = app.project.voiceId == voiceId;
          final isPlaying = _playingVoiceId == voiceId;
          final pitch = (voice['pitch'] as num).toDouble();

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.05)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () {
                  app.setVoice(
                    voiceId,
                    voice['name'] as String,
                    pitch,
                  );
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withValues(alpha: 0.1)
                              : AppTheme.iconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getVoiceIcon(voice['icon'] as String),
                          size: 22,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              voice['name'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${Translations.t('pitch')}: ${voice['pitch']}x',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Play preview button
                      GestureDetector(
                        onTap: () => _playPreview(voiceId, pitch, (voice['rate'] as num).toDouble()),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isPlaying
                                ? AppTheme.primary
                                : AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                            size: 22,
                            color: isPlaying
                                ? Colors.white
                                : AppTheme.primary,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle,
                            color: AppTheme.primary, size: 24),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getVoiceIcon(String iconName) {
    switch (iconName) {
      case 'mic': return Icons.mic;
      case 'boy': return Icons.boy;
      case 'man': return Icons.man;
      case 'woman': return Icons.woman;
      case 'girl': return Icons.girl;
      case 'elderly': return Icons.elderly;
      case 'face': return Icons.face;
      default: return Icons.mic;
    }
  }
}
