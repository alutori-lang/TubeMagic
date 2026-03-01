import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiService {
  // Groq API - free tier (Whisper + Llama)
  static const String _apiKey = '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';
  static const String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _whisperUrl = 'https://api.groq.com/openai/v1/audio/transcriptions';

  /// Transcribes audio from a video file using Whisper API
  /// Returns a Map with 'text' (transcription) and 'language' (auto-detected from script)
  static Future<Map<String, String>?> transcribeVideo(String videoPath) async {
    try {
      debugPrint('Starting Whisper transcription for: $videoPath');

      final file = File(videoPath);
      if (!await file.exists()) {
        debugPrint('Video file not found: $videoPath');
        return null;
      }

      final fileSize = await file.length();
      debugPrint('Video file size: ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB');

      // Whisper API limit is 25MB
      if (fileSize > 25 * 1024 * 1024) {
        debugPrint('Video >25MB, skipping transcription (Whisper limit)');
        return null;
      }

      // ISO 639-1 code -> human-readable language name (ALL Whisper-supported + extras)
      const langNames = {
        // South Asia
        'ur': 'urdu', 'hi': 'hindi', 'pa': 'punjabi', 'sd': 'sindhi',
        'bn': 'bengali', 'ta': 'tamil', 'te': 'telugu', 'mr': 'marathi',
        'gu': 'gujarati', 'kn': 'kannada', 'ml': 'malayalam', 'as': 'assamese',
        'ne': 'nepali', 'si': 'sinhala', 'sa': 'sanskrit', 'ps': 'pashto',
        // Middle East & North Africa
        'ar': 'arabic', 'fa': 'persian', 'he': 'hebrew', 'yi': 'yiddish',
        'ku': 'kurdish', 'mt': 'maltese',
        // Southeast Asia & Pacific
        'my': 'burmese', 'km': 'khmer', 'th': 'thai', 'lo': 'lao',
        'vi': 'vietnamese', 'id': 'indonesian', 'ms': 'malay',
        'tl': 'tagalog', 'jw': 'javanese', 'su': 'sundanese',
        'mi': 'maori', 'haw': 'hawaiian',
        // East Asia
        'zh': 'chinese', 'ja': 'japanese', 'ko': 'korean',
        'mn': 'mongolian', 'bo': 'tibetan',
        // Central Asia
        'kk': 'kazakh', 'uz': 'uzbek', 'tg': 'tajik', 'tk': 'turkmen',
        'tt': 'tatar', 'ba': 'bashkir',
        // Western Europe
        'en': 'english', 'es': 'spanish', 'fr': 'french', 'de': 'german',
        'it': 'italian', 'pt': 'portuguese', 'nl': 'dutch', 'ca': 'catalan',
        'gl': 'galician', 'eu': 'basque', 'oc': 'occitan',
        'lb': 'luxembourgish', 'br': 'breton', 'cy': 'welsh',
        'is': 'icelandic', 'fo': 'faroese',
        // Northern Europe
        'da': 'danish', 'sv': 'swedish', 'no': 'norwegian', 'nn': 'nynorsk',
        'fi': 'finnish', 'et': 'estonian', 'lt': 'lithuanian', 'lv': 'latvian',
        // Eastern Europe & Balkans
        'pl': 'polish', 'cs': 'czech', 'sk': 'slovak', 'hu': 'hungarian',
        'ro': 'romanian', 'bg': 'bulgarian', 'ru': 'russian', 'uk': 'ukrainian',
        'be': 'belarusian', 'hr': 'croatian', 'sr': 'serbian', 'sl': 'slovenian',
        'bs': 'bosnian', 'mk': 'macedonian', 'sq': 'albanian',
        // Caucasus & Turkey
        'tr': 'turkish', 'az': 'azerbaijani', 'ka': 'georgian', 'hy': 'armenian',
        'el': 'greek',
        // Africa
        'am': 'amharic', 'sw': 'swahili', 'ha': 'hausa', 'yo': 'yoruba',
        'ig': 'igbo', 'so': 'somali', 'wo': 'wolof', 'sn': 'shona',
        'zu': 'zulu', 'xh': 'xhosa', 'rw': 'kinyarwanda', 'lg': 'luganda',
        'ak': 'akan', 'ee': 'ewe', 'ln': 'lingala', 'tw': 'twi',
        'mg': 'malagasy', 'ny': 'chichewa', 'st': 'sesotho', 'tn': 'setswana',
        'af': 'afrikaans',
        // Caribbean
        'ht': 'haitian creole',
      };

      // ATTEMPT 1: No language forced, let Whisper auto-detect
      debugPrint('ATTEMPT 1: Auto-detect language');
      var result = await _callWhisper(videoPath, null);
      if (result != null && _isGoodTranscription(result)) {
        debugPrint('ATTEMPT 1 SUCCESS: Good transcription (${result.length} chars)');
        final detectedLang = _detectLanguageFromScript(result);
        debugPrint('DETECTED LANGUAGE FROM SCRIPT: $detectedLang');
        return {'text': result, 'language': detectedLang};
      }
      debugPrint('ATTEMPT 1 FAILED: Bad transcription "${result?.substring(0, result.length > 50 ? 50 : result.length) ?? 'null'}"');

      // ATTEMPT 2: Try ONLY the best-guess language (1 retry max for speed)
      final scriptLang = result != null ? _detectLanguageFromScript(result) : 'unknown';
      final retryLangs = _getRetryLanguages(scriptLang);
      if (retryLangs.isNotEmpty) {
        final bestLang = retryLangs.first;
        debugPrint('ATTEMPT 2: Retry with best-guess language=$bestLang');
        result = await _callWhisper(videoPath, bestLang);
        if (result != null && _isGoodTranscription(result)) {
          debugPrint('ATTEMPT 2 SUCCESS with language=$bestLang (${result.length} chars)');
          return {'text': result, 'language': langNames[bestLang] ?? bestLang};
        }
        debugPrint('ATTEMPT 2 FAILED with language=$bestLang');
      }

      // Both attempts done - return whatever we have (don't waste more time)
      debugPrint('RETURNING BEST EFFORT after 2 attempts');
      if (result != null && result.isNotEmpty) {
        final detectedLang = _detectLanguageFromScript(result);
        return {'text': result, 'language': detectedLang};
      }
      return null;
    } catch (e) {
      debugPrint('Whisper transcription error: $e');
      return null;
    }
  }

  /// Call Whisper API with optional forced language
  static Future<String?> _callWhisper(String videoPath, String? language) async {
    try {
      final whisperStart = DateTime.now();
      final request = http.MultipartRequest('POST', Uri.parse(_whisperUrl));
      request.headers['Authorization'] = 'Bearer $_apiKey';
      request.fields['model'] = 'whisper-large-v3';
      request.fields['response_format'] = 'text';
      request.fields['temperature'] = '0';
      if (language != null) {
        request.fields['language'] = language;
      }
      request.files.add(await http.MultipartFile.fromPath('file', videoPath));

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 3),
      );
      final response = await http.Response.fromStream(streamedResponse);
      final whisperTime = DateTime.now().difference(whisperStart).inSeconds;
      debugPrint('TIMER: Whisper (lang=${language ?? "auto"}) took ${whisperTime}s');

      if (response.statusCode == 200) {
        String transcription = response.body.trim();
        debugPrint('Whisper raw (lang=${language ?? "auto"}, ${transcription.length} chars): ${transcription.substring(0, transcription.length > 200 ? 200 : transcription.length)}');
        return transcription.isEmpty ? null : transcription;
      } else {
        debugPrint('Whisper API failed (lang=${language ?? "auto"}): ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Whisper call error (lang=${language ?? "auto"}): $e');
      return null;
    }
  }

  /// Check if transcription is actually useful (not just "موسیقی" repeated)
  static bool _isGoodTranscription(String text) {
    // Must be at least 30 chars to be meaningful
    if (text.length < 30) {
      debugPrint('BAD: Too short (${text.length} chars)');
      return false;
    }

    // Split into words and check for excessive repetition
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 5) {
      debugPrint('BAD: Too few words (${words.length})');
      return false;
    }

    // Check if >60% of words are the same (repetition check)
    final wordCounts = <String, int>{};
    for (final w in words) {
      wordCounts[w] = (wordCounts[w] ?? 0) + 1;
    }
    final maxCount = wordCounts.values.reduce((a, b) => a > b ? a : b);
    final repetitionRatio = maxCount / words.length;
    if (repetitionRatio > 0.6) {
      debugPrint('BAD: Too repetitive (${(repetitionRatio * 100).toInt()}% same word "${wordCounts.entries.firstWhere((e) => e.value == maxCount).key}")');
      return false;
    }

    // Check for known garbage words (موسیقی = music in Urdu/Arabic)
    final garbagePatterns = ['موسیقی', 'موسيقى', 'music', 'mus', 'سبسکرائب', 'subscribe'];
    final lowerText = text.toLowerCase();
    for (final pattern in garbagePatterns) {
      final count = pattern.allMatches(lowerText).length;
      if (count > 0 && text.length < count * pattern.length * 3) {
        debugPrint('BAD: Mostly garbage word "$pattern" ($count times)');
        return false;
      }
    }

    debugPrint('GOOD: ${words.length} words, ${text.length} chars, repetition ${(repetitionRatio * 100).toInt()}%');
    return true;
  }

  /// Detect language from Unicode script of the transcription text
  static String _detectLanguageFromScript(String text) {
    int arabic = 0, devanagari = 0, gurmukhi = 0, bengali = 0, latin = 0;
    int cjk = 0, turkish = 0, cyrillic = 0, greek = 0, thai = 0;
    int georgian = 0, armenian = 0, hebrew = 0, ethiopic = 0;
    int tamil = 0, telugu = 0, kannada = 0, malayalam = 0, myanmar = 0, khmer = 0;

    for (int i = 0; i < text.length && i < 500; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0x0600 && code <= 0x06FF) arabic++;
      else if (code >= 0x0900 && code <= 0x097F) devanagari++;
      else if (code >= 0x0A00 && code <= 0x0A7F) gurmukhi++;
      else if (code >= 0x0980 && code <= 0x09FF) bengali++;
      else if (code >= 0x0B80 && code <= 0x0BFF) tamil++;
      else if (code >= 0x0C00 && code <= 0x0C7F) telugu++;
      else if (code >= 0x0C80 && code <= 0x0CFF) kannada++;
      else if (code >= 0x0D00 && code <= 0x0D7F) malayalam++;
      else if (code >= 0x1000 && code <= 0x109F) myanmar++;
      else if (code >= 0x1780 && code <= 0x17FF) khmer++;
      else if (code >= 0x0E00 && code <= 0x0E7F) thai++;
      else if (code >= 0x10A0 && code <= 0x10FF) georgian++;
      else if (code >= 0x0530 && code <= 0x058F) armenian++;
      else if (code >= 0x0590 && code <= 0x05FF) hebrew++;
      else if (code >= 0x1200 && code <= 0x137F) ethiopic++;
      else if (code >= 0x0400 && code <= 0x04FF) cyrillic++;
      else if (code >= 0x0370 && code <= 0x03FF) greek++;
      else if (code >= 0x4E00 && code <= 0x9FFF) cjk++;
      else if (code >= 0x0041 && code <= 0x007A) latin++;
    }

    // Check for Turkish special chars in Latin text
    if (latin > 0) {
      final turkishChars = RegExp(r'[ğüşıöçĞÜŞİÖÇ]');
      if (turkishChars.hasMatch(text)) turkish = latin;
    }

    final counts = {
      'urdu': arabic, 'hindi': devanagari, 'punjabi': gurmukhi,
      'bengali': bengali, 'tamil': tamil, 'telugu': telugu,
      'kannada': kannada, 'malayalam': malayalam, 'burmese': myanmar,
      'khmer': khmer, 'thai': thai, 'georgian': georgian,
      'armenian': armenian, 'hebrew': hebrew, 'amharic': ethiopic,
      'russian': cyrillic, 'greek': greek, 'chinese': cjk,
      'turkish': turkish, 'english': latin,
    };

    String best = 'unknown';
    int bestCount = 0;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        bestCount = entry.value;
        best = entry.key;
      }
    }
    return bestCount == 0 ? 'unknown' : best;
  }

  /// Get retry languages based on detected script
  static List<String> _getRetryLanguages(String detectedScript) {
    switch (detectedScript) {
      // Arabic script: Urdu, Arabic, Persian, Pashto, Sindhi, Kurdish, Saraiki(=sd)
      case 'urdu':      return ['ur', 'ar', 'fa', 'ps', 'sd', 'ku'];
      // Devanagari: Hindi, Marathi, Nepali, Sanskrit, Gujarati
      case 'hindi':     return ['hi', 'mr', 'ne', 'sa', 'gu'];
      case 'punjabi':   return ['pa', 'hi', 'sd'];  // Gurmukhi (Saraiki close to Punjabi)
      case 'bengali':   return ['bn', 'as', 'hi'];  // Bengali + Assamese
      case 'tamil':     return ['ta', 'si', 'ml'];   // Tamil, Sinhala, Malayalam
      case 'telugu':    return ['te', 'kn', 'hi'];
      case 'kannada':   return ['kn', 'te', 'hi'];
      case 'malayalam': return ['ml', 'ta', 'hi'];
      case 'burmese':   return ['my', 'th'];
      case 'khmer':     return ['km', 'th', 'vi'];
      case 'thai':      return ['th', 'lo'];
      case 'georgian':  return ['ka'];
      case 'armenian':  return ['hy'];
      case 'hebrew':    return ['he', 'yi'];
      // Ethiopic: Amharic + East African languages
      case 'amharic':   return ['am', 'so', 'sw', 'ha'];
      // Cyrillic: Russian, Ukrainian, Belarusian, Bulgarian, Serbian, Macedonian, Kazakh, Mongolian
      case 'russian':   return ['ru', 'uk', 'be', 'bg', 'sr', 'mk', 'kk', 'mn', 'tt', 'ba', 'tg'];
      case 'greek':     return ['el'];
      // CJK: Chinese, Japanese, Korean
      case 'chinese':   return ['zh', 'ja', 'ko'];
      // Turkish + Turkic languages
      case 'turkish':   return ['tr', 'az', 'tk', 'uz'];
      // Latin script: ALL European + African + Southeast Asian + Caribbean
      case 'english':   return [
        // Western Europe
        'en', 'it', 'es', 'fr', 'pt', 'de', 'nl',
        'ca', 'gl', 'eu', 'oc', 'lb', 'br', 'cy',
        // Nordic & Baltic
        'da', 'sv', 'no', 'nn', 'fi', 'is', 'fo',
        'et', 'lt', 'lv',
        // Eastern Europe & Balkans
        'pl', 'cs', 'sk', 'hu', 'ro', 'sq', 'bs', 'hr', 'sl',
        // Africa (Latin script)
        'sw', 'wo', 'yo', 'ha', 'ig', 'sn', 'zu', 'xh', 'af',
        'lg', 'ak', 'ee', 'ln', 'ny', 'st', 'tn', 'mg', 'rw',
        // Southeast Asia & Pacific (Latin script)
        'id', 'ms', 'tl', 'vi', 'jw', 'su', 'mi', 'haw',
        // Caribbean & others
        'ht', 'mt', 'so',
      ];
      // Unknown script: try most common world languages from every continent
      default: return [
        'en', 'it', 'es', 'fr', 'pt', 'de', 'ur', 'hi', 'ar', 'pa',
        'bn', 'sw', 'yo', 'ha', 'wo', 'sq', 'ro', 'tr',
        'zh', 'ru', 'ko', 'ja', 'id', 'th', 'vi', 'fa',
      ];
    }
  }

  /// Fixes control characters inside JSON string values
  static String _fixJsonControlChars(String json) {
    final buffer = StringBuffer();
    bool inString = false;
    bool escaped = false;
    for (int i = 0; i < json.length; i++) {
      final char = json[i];
      if (escaped) {
        buffer.write(char);
        escaped = false;
        continue;
      }
      if (char == '\\' && inString) {
        buffer.write(char);
        escaped = true;
        continue;
      }
      if (char == '"') {
        inString = !inString;
        buffer.write(char);
        continue;
      }
      if (inString && (char.codeUnitAt(0) < 32 || char.codeUnitAt(0) == 127)) {
        // Replace control chars inside strings with space
        if (char == '\n' || char == '\r') {
          buffer.write('\\n');
        } else if (char == '\t') {
          buffer.write(' ');
        } else {
          buffer.write(' ');
        }
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  /// Extracts a clean topic from video file name
  static String _extractTopicFromFileName(String? fileName) {
    if (fileName == null || fileName.isEmpty) return '';
    // Remove file extension
    String name = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    // Replace underscores, dashes, dots with spaces
    name = name.replaceAll(RegExp(r'[_\-\.]'), ' ');
    // Remove common prefixes like VID_, IMG_, etc.
    name = name.replaceAll(RegExp(r'^(VID|IMG|MOV|VIDEO|REC|Screen Recording|Screenrecord|SVID)\s*', caseSensitive: false), '');
    // Remove timestamps like 20240101_120000
    name = name.replaceAll(RegExp(r'\d{8}[\s_]?\d{6}'), '');
    // Remove standalone numbers
    name = name.replaceAll(RegExp(r'\b\d+\b'), '');
    // Clean up spaces
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return name;
  }

  /// Detects if the filename is a real video title (downloaded from social media)
  /// vs a camera/phone-generated filename like VID_20240315_143022.mp4
  static bool _isRealVideoTitle(String? fileName) {
    if (fileName == null || fileName.isEmpty) return false;

    // Remove file extension
    String name = fileName.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
    if (name.isEmpty || name.length < 4) return false;

    // Camera/phone patterns - these are NOT real titles
    final cameraPatterns = [
      RegExp(r'^VID[-_]', caseSensitive: false),           // VID_20240315
      RegExp(r'^IMG[-_]', caseSensitive: false),           // IMG_1234
      RegExp(r'^MOV[-_]?', caseSensitive: false),          // MOV_0042, MOV0042
      RegExp(r'^VIDEO[-_]', caseSensitive: false),         // VIDEO_20240315
      RegExp(r'^REC[-_]', caseSensitive: false),           // REC_20240315
      RegExp(r'^SVID[-_]', caseSensitive: false),          // SVID_20240315
      RegExp(r'^DSC[-_]', caseSensitive: false),           // DSC_0001
      RegExp(r'^DCIM[-_]', caseSensitive: false),          // DCIM_0001
      RegExp(r'^WP[-_]\d', caseSensitive: false),          // WP_20240315
      RegExp(r'^PXL[-_]', caseSensitive: false),           // PXL_20240315 (Pixel phones)
      RegExp(r'^Screen[-\s]?Record', caseSensitive: false), // Screen Recording
      RegExp(r'^Screenrecord', caseSensitive: false),       // Screenrecord
      RegExp(r'^InShot[-_]', caseSensitive: false),         // InShot_20240315
      RegExp(r'^trim[-_.]', caseSensitive: false),          // trim.VID
      RegExp(r'^\d{8}[-_]\d{4,6}$'),                       // 20240315_143022 (pure timestamp)
      RegExp(r'^\d{10,}$'),                                 // 1710500000000 (epoch)
      RegExp(r'^video[-_]?\d+', caseSensitive: false),      // video_001, video1
      RegExp(r'^recording[-_]?\d', caseSensitive: false),   // recording_001
      RegExp(r'^[\d\s_\-().]+$'),                           // Only numbers, spaces, underscores
    ];

    for (final pattern in cameraPatterns) {
      if (pattern.hasMatch(name)) {
        debugPrint('FILENAME DETECT: "$name" = CAMERA (matched: ${pattern.pattern})');
        return false;
      }
    }

    // Check if the name has real words (at least 2 words with 2+ letters each)
    final words = name
        .replaceAll(RegExp(r'[_\-\.]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2 && RegExp(r'[a-zA-Z\u0600-\uFE00\u0900-\u097F\u0A00-\u0A7F\u4E00-\u9FFF\u3040-\u309F\uAC00-\uD7AF]').hasMatch(w))
        .toList();

    if (words.length >= 2) {
      debugPrint('FILENAME DETECT: "$name" = REAL TITLE (${words.length} real words)');
      return true;
    }

    debugPrint('FILENAME DETECT: "$name" = CAMERA (not enough real words)');
    return false;
  }

  /// Extracts the clean title from a social-media-downloaded filename
  static String _extractRealTitle(String fileName) {
    // Remove extension
    String name = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    // Replace underscores/dashes with spaces
    name = name.replaceAll(RegExp(r'[_]'), ' ');
    // Clean up extra spaces
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return name;
  }

  /// Generates title, description, tags, and hashtags for a video
  /// Uses Whisper transcription when available for content-aware metadata
  static Future<Map<String, dynamic>> generateVideoMetadata({
    required String categoryName,
    required String languageCode,
    required String languageName,
    String? videoFileName,
    String? videoFilePath,
    String? channelId,
    String? channelName,
    Map<String, String>? preTranscriptionResult,
    void Function(String status)? onProgress,
  }) async {
    final topic = _extractTopicFromFileName(videoFileName);
    final hasRealTitle = _isRealVideoTitle(videoFileName);
    final realTitle = hasRealTitle ? _extractRealTitle(videoFileName!) : '';

    // Step 1: Use pre-cached transcription or transcribe now
    String? transcription;
    String detectedLanguage = 'unknown';
    if (preTranscriptionResult != null && preTranscriptionResult['text'] != null) {
      // Already transcribed in background while user was configuring settings
      transcription = preTranscriptionResult['text'];
      detectedLanguage = preTranscriptionResult['language'] ?? 'unknown';
      debugPrint('SPEED: Using pre-cached transcription (${transcription!.length} chars, lang: $detectedLanguage)');
    } else if (videoFilePath != null) {
      onProgress?.call('Analyzing audio...');
      final result = await transcribeVideo(videoFilePath);
      if (result != null) {
        transcription = result['text'];
        detectedLanguage = result['language'] ?? 'unknown';
      }
    }
    debugPrint('DETECTED LANGUAGE FROM AUDIO: $detectedLanguage');

    onProgress?.call('Generating metadata...');

    // Step 2: Build the prompt based on filename type
    final safeChannelName = (channelName != null && channelName.isNotEmpty) ? channelName : '';
    String prompt;

    if (hasRealTitle) {
      // ===== REAL TITLE MODE: filename is from social media download =====
      debugPrint('MODE: REAL TITLE from social media -> "$realTitle"');

      // Extract first 2 words from the real title for tag #1
      final titleWords = realTitle.split(RegExp(r'\s+'));
      final first2Words = titleWords.take(2).join(' ');

      prompt = '''
You are a YouTube SEO expert with deep knowledge of artists, singers, speakers, and creators worldwide.

VIDEO TITLE (from filename): "$realTitle"
${transcription != null ? 'AUDIO TRANSCRIPTION:\n"""\n$transcription\n"""' : ''}
DETECTED LANGUAGE: $detectedLanguage
Category: $categoryName
Uploader's channel name: "$safeChannelName"

The video title "$realTitle" is the REAL title. Use it EXACTLY as the YouTube title.

IMPORTANT - ARTIST/SPEAKER IDENTIFICATION:
If you can identify the singer/artist/speaker/creator from the title or transcription, you MUST:
1. Know EXACTLY what type of artist they are (folk singer, pop singer, naat khawan, qawwal, rapper, motivational speaker, etc.)
2. Know their REAL biography: where they are from, what genre they actually perform, what they are famous for
3. Do NOT guess or assume their genre. For example:
   - Talib Hussain Dard = Punjabi FOLK singer from Pakistan, known for dard-bhare (painful/emotional) Punjabi folk songs. He is NOT a Sufi singer.
   - Nusrat Fateh Ali Khan = Qawwali singer (Sufi music)
   - Atif Aslam = Pakistani pop/playback singer
   - Tony Robbins = American motivational speaker about personal development
4. If you are NOT 100% sure about the artist, write a GENERIC description without labeling their specific genre.

Return this EXACT JSON structure:
{
  "title_suffix": "1-3 attractive, click-worthy words to ADD AFTER the original title. Based on the content type and culture. Examples: if punjabi song → 'Punjabi Beautiful Song' or 'Saraiki Culture Song'. If naat → 'Beautiful Naat Sharif'. If motivational → 'Incredible True Story' or 'Must Watch'. If hindi song → 'Hindi Romantic Song'. Match the language/culture of the content.",
  "singer_or_speaker": "Full name of the artist/speaker identified from title and audio. Empty string if unknown.",
  "artist_type": "Their EXACT real type: folk singer, pop singer, naat khawan, qawwal, rapper, classical singer, motivational speaker, life coach, comedian, etc. Be ACCURATE. Empty if unknown.",
  "artist_bio": "A 2-3 sentence ACCURATE biography of the artist. Where they are from, what genre they ACTUALLY perform, what they are famous for. Do NOT invent facts. Empty if unknown.",
  "content_type": "song OR naat OR qawwali OR folk OR speech OR motivational OR interview OR talk OR podcast OR news OR tutorial OR vlog OR remix OR mashup",
  "content_genre": "The ACCURATE specific genre: punjabi folk, punjabi pop, islamic naat, sufi qawwali, hindi film songs, urdu ghazal, english motivational, cooking tutorial, etc.",
  "description": "Write a rich 500+ char YouTube description. Start with the title. Then write about the artist using their REAL biography (artist_bio). Then describe the content. If you know the artist, write: who they are, where they are from, their actual genre, and why people love them. Include relevant lyrics from transcription if available. No hashtags. All in Latin A-Z.",
  "tags": ["SEE RULES BELOW for tag order"],
  "hashtags": ["8-10 hashtags without # symbol"]
}

CRITICAL TAG RULES (follow this EXACT order):
- Tag 1: "$first2Words" (first 2 words of the title)
- Tag 2: "$safeChannelName" (the uploader's channel name)
- Tag 3: The artist/speaker name (ONLY if identified, skip if unknown)
- Tags 4-10: Genre-specific tags based on the REAL genre (not guessed). Examples:
  * Punjabi folk singer → "punjabi folk", "folk songs", "punjabi music", "desi folk", "new folk song"
  * Naat khawan → "naat sharif", "islamic naat", "naat 2026", "beautiful naat", "naat khawan"
  * Qawwal → "qawwali", "sufi music", "sufi qawwali", "dhamaal"
  * Motivational speaker → "motivational", "motivation", "self improvement", then topic-specific tags
  * Hindi pop singer → "hindi songs", "bollywood", "hindi pop", "new hindi song"
  * Tutorial → "tutorial", "how to", specific subject tags
- Tags 11-40: More related viral/trending tags for the REAL content type and culture
- Each tag max 15 chars, total all tags under 500 chars

RULES:
- title_suffix: Generate 1-3 ATTRACTIVE words that make people want to click. Must match the culture and content type. NOT generic words like "video" or "2026". Think: what would make someone click THIS video?
- NEVER label an artist with a wrong genre. If unsure, use generic terms like "singer" or "artist"
- ALL output in Latin A-Z letters only (romanize any non-Latin text)
- Return ONLY valid JSON
''';
    } else if (transcription != null && transcription.isNotEmpty) {
      // ===== CAMERA MODE WITH TRANSCRIPTION: use first 11 words =====
      debugPrint('MODE: CAMERA filename, using transcription for title');
      final allWords = transcription.split(RegExp(r'\s+'));
      final first11Words = allWords.take(11).join(' ');
      debugPrint('FIRST 11 WORDS FOR TITLE: $first11Words');

      prompt = '''
You are a YouTube SEO expert. Analyze this video transcription and return structured data.

AUDIO TRANSCRIPTION (may be in native script - romanize ALL output to Latin A-Z):
"""
$transcription
"""

DETECTED LANGUAGE: $detectedLanguage
Category: $categoryName
Uploader's channel name: "$safeChannelName"

Return this EXACT JSON structure:

{
  "first_words_romanized": "Romanize the FIRST 11 words from the transcription above to Latin A-Z letters. These are: $first11Words -- Romanize these EXACT characters to Latin. Do NOT translate. Do NOT summarize. Do NOT write Music/Mousiqi/Song. Write the actual phonetic sounds in Latin letters.",
  "singer_or_speaker": "Name of singer/speaker if mentioned in transcription, or empty string if unknown",
  "content_type": "song OR speech OR interview OR talk OR conference OR vlog OR news",
  "culture": "The culture based on detected language: $detectedLanguage (e.g. Punjabi, Urdu, Hindi, Arabic, Turkish, English etc.)",
  "mood": "emotional OR sad OR happy OR motivational OR romantic OR religious OR political OR funny",
  "description": "Write a rich 500+ char description about the video content. Include actual lyrics/quotes from transcription romanized to Latin. Mention the culture. No hashtags. All in Latin A-Z.",
  "tags": ["40-50 tags, each max 15 chars, culture-specific + viral tags, total under 500 chars"],
  "hashtags": ["8-10 hashtags without # symbol, culture + content related"]
}

CRITICAL RULES:
- "first_words_romanized": Take the characters "$first11Words" and write how they SOUND in Latin letters. Example: if you see "دل دا مملا" write "Dil Da Mamla". Do NOT write "Music" or "Mousiqi" or any English translation.
- Singer/speaker: ONLY if their name appears in the transcription
- Culture MUST match the detected language ($detectedLanguage)
- ALL output in ROMANIZED Latin letters (A-Z) only
- Return ONLY valid JSON
''';
    } else {
      // ===== CAMERA MODE WITHOUT TRANSCRIPTION: use filename topic =====
      debugPrint('MODE: CAMERA filename, no transcription, using topic');
      prompt = '''
You are a YouTube SEO expert. Generate optimized metadata for a YouTube video.

Video topic/name: ${topic.isNotEmpty ? topic : 'General $categoryName video'}
Category: $categoryName
Language: $languageName ($languageCode)
Original file name: ${videoFileName ?? 'unknown'}

IMPORTANT: The title and description MUST be directly related to the video topic "$topic". Do NOT generate generic content.

Generate the following in JSON format:
{
  "title": "A title directly about '$topic' (minimum 80 characters, must reference the actual video content)",
  "description": "A detailed description about '$topic' (minimum 500 characters, must be about the actual video topic)",
  "tags": ["tag1", "tag2", "tag3", ... (generate 25-30 tags related to '$topic')],
  "hashtags": ["hashtag1", "hashtag2", "hashtag3", ... (generate 8-10 hashtags related to '$topic' without # symbol)]
}

Rules:
- Title MUST reference the actual video topic "$topic"
- Title MUST be at least 80 characters long
- Description must be about the actual video content
- Tags must be relevant to the video topic
- All content must be in $languageName language
- Make it SEO optimized and engaging

Return ONLY valid JSON, no other text.
''';
    }

    Map<String, dynamic> metadata;

    try {
      final llmStart = DateTime.now();
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content': hasRealTitle
                  ? 'You are the world\'s best YouTube SEO expert AND music/entertainment encyclopedia. The user has a video downloaded from social media with a REAL title in the filename. Use that title exactly. You MUST identify the artist/singer/speaker accurately. CRITICAL: You must know the artist\'s REAL genre, REAL biography, and where they are from. NEVER guess genres - Talib Hussain Dard is a Punjabi FOLK singer not Sufi, Nusrat Fateh Ali Khan is a Qawwal, etc. If you don\'t know an artist well, use generic terms. Write accurate biographies in descriptions. ALL output romanized Latin A-Z only. JSON only.'
                  : transcription != null
                      ? 'You are the world\'s best YouTube SEO expert. ABSOLUTE RULE: The title MUST start with the FIRST 11 WORDS from the video transcription, romanized to Latin A-Z. Copy the actual spoken/sung words - NEVER replace them with summary words like "Mousiqi", "Music", "Song". The detected audio language tells you the culture. Nationality must match language (Urdu=Pakistani, Punjabi=Pakistani/Indian, Arabic=Arab). ALL output romanized Latin A-Z only. JSON only.'
                      : 'You are the world\'s best YouTube SEO expert. Your goal: make videos GO VIRAL with perfect titles, descriptions, and tags. CRITICAL: ALL output in ROMANIZED Latin letters (A-Z) only. No native scripts. Respond with valid JSON only.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.4,
          'max_tokens': 2000,
        }),
      );

      final llmTime = DateTime.now().difference(llmStart).inSeconds;
      debugPrint('TIMER: LLM took ${llmTime}s');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        String cleanContent = content
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        // Fix malformed JSON: remove control characters inside strings (newlines, tabs, etc.)
        cleanContent = cleanContent.replaceAll(RegExp(r'[\x00-\x1F\x7F](?!["\\/bfnrtu])'), ' ');
        // Try parsing, if it fails try aggressive cleanup
        try {
          metadata = jsonDecode(cleanContent) as Map<String, dynamic>;
        } catch (_) {
          debugPrint('JSON parse failed, attempting aggressive cleanup...');
          // Replace all actual newlines/tabs inside JSON string values with spaces
          cleanContent = _fixJsonControlChars(cleanContent);
          metadata = jsonDecode(cleanContent) as Map<String, dynamic>;
        }
      } else {
        debugPrint('AI API failed with status ${response.statusCode}, using local fallback');
        metadata = _generateLocalMetadata(
          categoryName, languageName, topic,
          transcription: transcription,
        );
      }
    } catch (e) {
      debugPrint('AI API error: $e, using local fallback');
      metadata = _generateLocalMetadata(
        categoryName, languageName, topic,
        transcription: transcription,
      );
    }

    // BUILD TITLE IN DART from LLM parts
    if (hasRealTitle) {
      // ===== REAL TITLE MODE: use filename + attractive suffix =====
      final titleSuffix = (metadata['title_suffix'] as String?)?.trim() ?? '';
      String finalRealTitle = realTitle;
      if (titleSuffix.isNotEmpty) {
        finalRealTitle = '$realTitle | $titleSuffix';
      }
      // Keep title under 100 chars
      if (finalRealTitle.length > 100) {
        finalRealTitle = finalRealTitle.substring(0, 100).trim();
      }
      metadata['title'] = finalRealTitle;
      debugPrint('REAL TITLE MODE - Original: "$realTitle" + Suffix: "$titleSuffix" = "$finalRealTitle"');

      // Ensure tags follow the required order: first2words, channelName, artist, genre tags
      final titleWords = realTitle.split(RegExp(r'\s+'));
      final first2Words = titleWords.take(2).join(' ');
      final singerSpeaker = (metadata['singer_or_speaker'] as String?)?.trim() ?? '';

      // Rebuild tags with correct order if LLM didn't follow instructions
      if (metadata['tags'] != null && metadata['tags'] is List) {
        final llmTags = (metadata['tags'] as List).map((t) => t.toString().trim()).where((t) => t.isNotEmpty).toList();
        final orderedTags = <String>[];

        // Tag 1: First 2 words of title
        if (first2Words.isNotEmpty) orderedTags.add(first2Words);
        // Tag 2: Channel name
        if (safeChannelName.isNotEmpty) orderedTags.add(safeChannelName);
        // Tag 3: Singer/speaker name
        if (singerSpeaker.isNotEmpty) orderedTags.add(singerSpeaker);
        // Tags 4+: LLM genre-specific tags (skip duplicates of first 3)
        for (final tag in llmTags) {
          if (!orderedTags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
            orderedTags.add(tag);
          }
        }
        metadata['tags'] = orderedTags;
      }

      debugPrint('REAL TITLE TAGS: ${metadata['tags']}');
    } else if (transcription != null && transcription.isNotEmpty) {
      // ===== CAMERA MODE: build title from transcription =====
      final firstWords = (metadata['first_words_romanized'] as String?)?.trim() ?? '';
      final singerSpeaker = (metadata['singer_or_speaker'] as String?)?.trim() ?? '';
      final contentType = (metadata['content_type'] as String?)?.trim() ?? 'song';
      final culture = (metadata['culture'] as String?)?.trim() ?? detectedLanguage;
      final mood = (metadata['mood'] as String?)?.trim() ?? 'beautiful';

      debugPrint('BUILD TITLE - firstWords: "$firstWords"');
      debugPrint('BUILD TITLE - singer: "$singerSpeaker"');
      debugPrint('BUILD TITLE - culture: "$culture", type: "$contentType"');

      // Map content type to display label
      String typeLabel;
      switch (contentType.toLowerCase()) {
        case 'song': typeLabel = 'Songs'; break;
        case 'speech': typeLabel = 'Speech'; break;
        case 'interview': typeLabel = 'Interview'; break;
        case 'talk': typeLabel = 'Talk'; break;
        case 'conference': typeLabel = 'Conference'; break;
        case 'news': typeLabel = 'News'; break;
        default: typeLabel = 'Songs'; break;
      }

      // Capitalize mood
      final moodCap = mood.isNotEmpty ? '${mood[0].toUpperCase()}${mood.substring(1)}' : 'Beautiful';

      // Build title: FirstWords | Singer | Culture Type Mood 2026
      final parts = <String>[];
      if (firstWords.isNotEmpty) {
        parts.add(firstWords);
      }
      if (singerSpeaker.isNotEmpty) {
        parts.add(singerSpeaker);
      }
      parts.add('$culture $typeLabel $moodCap 2026');

      String titleText = parts.join(' | ');

      // Clean up
      titleText = titleText.replaceAll(RegExp(r'\b[Uu]nknown\b'), '').trim();
      titleText = titleText.replaceAll(RegExp(r'\s*[-|]\s*[-|]\s*'), ' | ').trim();
      titleText = titleText.replaceAll(RegExp(r'\s+'), ' ').trim();
      titleText = titleText.replaceAll(RegExp(r'^[-|]\s*'), '').trim();
      titleText = titleText.replaceAll(RegExp(r'\s*[-|]$'), '').trim();

      metadata['title'] = titleText.isNotEmpty ? titleText : 'Amazing $categoryName Video Must Watch 2026';
      debugPrint('FINAL BUILT TITLE: "${metadata['title']}"');
    } else {
      // No transcription - use LLM's title as-is
      String titleText = (metadata['title'] as String?)?.trim() ?? '';
      titleText = titleText.replaceAll(RegExp(r'\b[Uu]nknown\b'), '').trim();
      if (titleText.isEmpty) {
        metadata['title'] = 'Amazing $categoryName Video - Must Watch Content You Will Love Today';
      } else {
        metadata['title'] = titleText;
      }
    }

    // Safety: clean placeholder text from description
    final finalTitle = (metadata['title'] as String?) ?? '';
    String descText = (metadata['description'] as String?)?.trim() ?? '';
    descText = descText.replaceAll(RegExp(r'\[Video Title\]', caseSensitive: false), finalTitle);
    descText = descText.replaceAll(RegExp(r'\{Video Title\}', caseSensitive: false), finalTitle);
    descText = descText.replaceAll(RegExp(r'"Video Title"', caseSensitive: false), finalTitle);
    descText = descText.replaceAll(RegExp(r'^Video Title\b', caseSensitive: false, multiLine: true), finalTitle);
    metadata['description'] = descText;

    // Enforce tag rules: each tag max 15 chars, total max 500 chars
    if (metadata['tags'] != null && metadata['tags'] is List) {
      List<String> tags = (metadata['tags'] as List)
          .map((t) => t.toString().trim())
          .where((t) => t.isNotEmpty)
          .map((t) => t.length > 15 ? t.substring(0, 15).trim() : t)
          .toList();

      // Enforce total 500 chars limit
      int totalChars = 0;
      final List<String> finalTags = [];
      for (final tag in tags) {
        final newTotal = totalChars + tag.length + (finalTags.isEmpty ? 0 : 1); // +1 for comma separator
        if (newTotal > 500) break;
        finalTags.add(tag);
        totalChars = newTotal;
      }
      metadata['tags'] = finalTags;
      debugPrint('Tags count: ${finalTags.length}, total chars: $totalChars');
    }

    // Build final description: hashtags on first line, then description, then channel link at end
    String description = (metadata['description'] as String?) ?? '';
    final hashtags = metadata['hashtags'] as List?;

    // Build hashtag line for first row of description
    String hashtagLine = '';
    if (hashtags != null && hashtags.isNotEmpty) {
      hashtagLine = hashtags.map((h) => '#${h.toString().replaceAll('#', '')}').join(' ');
    }

    // Compose final description: hashtags first, then content, then channel link
    final StringBuffer finalDescription = StringBuffer();
    if (hashtagLine.isNotEmpty) {
      finalDescription.writeln(hashtagLine);
      finalDescription.writeln();
    }
    finalDescription.write(description);

    // Append channel link at the very end
    if (channelId != null && channelId.isNotEmpty) {
      finalDescription.writeln();
      finalDescription.writeln();
      finalDescription.writeln('▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬');
      finalDescription.writeln('Subscribe to my channel:');
      finalDescription.writeln('https://www.youtube.com/channel/$channelId?sub_confirmation=1');
      finalDescription.write('▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬');
    }

    metadata['description'] = finalDescription.toString();

    debugPrint('=== TUBEMAGIC AI RESULT ===');
    debugPrint('Transcription: ${transcription != null ? "YES (${transcription.length} chars)" : "NO"}');
    if (transcription != null) {
      debugPrint('Transcription preview: ${transcription.substring(0, transcription.length > 200 ? 200 : transcription.length)}');
    }
    debugPrint('TITLE: "${metadata['title']}"');
    debugPrint('TITLE length: ${(metadata['title'] as String).length} chars');
    debugPrint('TAGS count: ${(metadata['tags'] as List?)?.length ?? 0}');
    debugPrint('=== END TUBEMAGIC AI ===');

    return metadata;
  }

  /// Local fallback metadata generation based on video topic and/or transcription
  static Map<String, dynamic> _generateLocalMetadata(
      String categoryName, String languageName, String topic,
      {String? transcription}) {
    // If we have transcription, use it even in local fallback
    if (transcription != null && transcription.isNotEmpty) {
      return _generateFromTranscription(transcription, categoryName);
    }
    if (topic.isNotEmpty) {
      return _generateFromTopic(topic, categoryName);
    }
    final templates = _getCategoryTemplates(categoryName);
    return {
      'title': templates['title']!,
      'description': templates['description']!,
      'tags': templates['tags'] as List<String>,
      'hashtags': templates['hashtags'] as List<String>,
    };
  }

  /// Generate metadata based on actual video transcription (local fallback)
  static Map<String, dynamic> _generateFromTranscription(
      String transcription, String category) {
    // Take first 100 chars for title (clean up)
    final titleSnippet = transcription.length > 80
        ? transcription.substring(0, 80).trim()
        : transcription.trim();

    // Extract key words from transcription for tags
    final words = transcription
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet()
        .toList();

    // Take unique words for tags (max 25)
    final tagWords = words.take(25).toList();

    // Take some words for hashtags (max 8)
    final hashtagWords = words
        .take(8)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .toList();

    return {
      'title': '$titleSnippet | $category Video',
      'description':
          'Video content:\n\n$transcription\n\n'
          'If you enjoyed this video, please like and subscribe for more content!\n\n'
          'Share with your friends and family.',
      'tags': [
        ...tagWords,
        category.toLowerCase(),
        'trending',
        'viral',
        'youtube',
      ],
      'hashtags': [
        ...hashtagWords,
        category.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''),
        'Trending',
      ],
    };
  }

  /// Generate metadata based on the extracted video topic
  static Map<String, dynamic> _generateFromTopic(String topic, String category) {
    final topicLower = topic.toLowerCase();
    final topicCapitalized = topic.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');

    // Generate topic-specific words for tags
    final topicWords = topicLower.split(' ').where((w) => w.length > 2).toList();

    return {
      'title': '$topicCapitalized - The Complete Video You Need to Watch Right Now | Best $category Content',
      'description': 'Welcome to this amazing video about $topicCapitalized! In this video we cover everything you need to know about $topic.\n\n'
          'This is the most complete and detailed video about $topic that you will find on YouTube. '
          'We have put a lot of effort into making this content informative, entertaining, and valuable for you.\n\n'
          'If you enjoy this video about $topicCapitalized, please give it a thumbs up and subscribe to our channel for more content like this!\n\n'
          'Share this video with anyone who is interested in $topic.\n\n'
          'Thank you for watching! Your support means the world to us.',
      'tags': [
        ...topicWords,
        topicLower,
        'best $topicLower',
        '$topicLower video',
        '$topicLower 2026',
        'trending',
        'viral',
        'youtube',
        'must watch',
        'best video',
        'new video',
        'amazing',
        category.toLowerCase(),
      ],
      'hashtags': [
        topicCapitalized.replaceAll(' ', ''),
        ...topicWords.take(3).map((w) => w[0].toUpperCase() + w.substring(1)),
        category.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''),
        'Trending', 'Viral', 'YouTube', 'MustWatch',
      ],
    };
  }

  static Map<String, dynamic> _getCategoryTemplates(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'music':
        return {
          'title':
              'Amazing Music Video That Will Touch Your Soul - Best New Song You Need To Hear Today',
          'description':
              'Welcome to an incredible music experience! This video features amazing music that will touch your heart and soul. If you love music, this is the perfect video for you.\n\nMake sure to subscribe to our channel for more amazing music content. Hit the bell icon to never miss a new upload!\n\nIf you enjoyed this video, please give it a thumbs up and share it with your friends and family. Your support means the world to us!\n\nFollow us on social media for updates and behind-the-scenes content.\n\nThank you for watching and supporting our channel! We appreciate every single one of you.',
          'tags': [
            'music', 'new music', 'best music', 'music video', 'song',
            'new song', 'best song', 'trending music', 'viral music',
            'top music', 'music 2026', 'hit song', 'popular music',
            'love song', 'emotional music', 'feel good music', 'party music',
            'chill music', 'relaxing music', 'motivational music',
            'workout music', 'driving music', 'study music', 'sleep music',
            'acoustic music', 'pop music', 'rock music', 'hip hop music',
          ],
          'hashtags': [
            'Music', 'NewMusic', 'Trending', 'ViralMusic', 'BestSong',
            'MusicVideo', 'TopHits', 'NewRelease',
          ],
        };
      case 'comedy':
        return {
          'title':
              'Try Not To Laugh Challenge - Funniest Video You Will Ever Watch This Year',
          'description':
              'Get ready to laugh like never before! This hilarious video is guaranteed to make your day better. We bring you the funniest content that will have you rolling on the floor!\n\nDon\'t forget to subscribe and hit the bell icon for more funny videos every week!\n\nShare this video with your friends who need a good laugh today!\n\nThank you for watching! Your support keeps us going!',
          'tags': [
            'funny', 'comedy', 'laugh', 'hilarious', 'try not to laugh',
            'funny video', 'comedy video', 'humor', 'memes', 'viral funny',
            'trending comedy', 'best comedy', 'funny moments', 'pranks',
            'funny fails', 'comedy 2026', 'lol', 'entertainment',
            'funny clips', 'best funny', 'top funny', 'comedy show',
            'stand up', 'jokes', 'fun',
          ],
          'hashtags': [
            'Funny', 'Comedy', 'TryNotToLaugh', 'Humor', 'Viral',
            'FunnyVideo', 'LOL', 'Entertainment',
          ],
        };
      case 'sports':
        return {
          'title':
              'Incredible Sports Moments That Will Leave You Speechless - Best Athletic Highlights',
          'description':
              'Witness the most incredible sports moments ever captured on camera! These amazing athletic feats will leave you speechless and inspired.\n\nSubscribe for more amazing sports content and highlights!\n\nIf you enjoyed this video, smash that like button and share it with fellow sports fans!\n\nThank you for being part of our community!',
          'tags': [
            'sports', 'highlights', 'best moments', 'athletic', 'incredible',
            'amazing sports', 'sports video', 'football', 'soccer', 'basketball',
            'cricket', 'tennis', 'boxing', 'mma', 'sports 2026',
            'top sports', 'viral sports', 'best plays', 'goals', 'dunks',
            'knockouts', 'records', 'athletes', 'sports highlights', 'game',
          ],
          'hashtags': [
            'Sports', 'Highlights', 'Amazing', 'BestPlays', 'Athletic',
            'Viral', 'TopSports', 'Incredible',
          ],
        };
      case 'gaming':
        return {
          'title':
              'Epic Gaming Moments You Won\'t Believe Actually Happened - Insane Gameplay Highlights',
          'description':
              'Check out these absolutely insane gaming moments! From clutch plays to impossible shots, this video has it all.\n\nSubscribe for more epic gaming content uploaded regularly!\n\nLeave a comment telling us your favorite moment in this video!\n\nThank you for watching, gamers!',
          'tags': [
            'gaming', 'gameplay', 'gamer', 'epic', 'gaming moments',
            'best gaming', 'pro gaming', 'clutch', 'gaming highlights',
            'video games', 'pc gaming', 'console gaming', 'gaming 2026',
            'lets play', 'walkthrough', 'tips', 'tricks', 'gaming channel',
            'streamer', 'esports', 'competitive', 'ranked', 'win', 'victory',
          ],
          'hashtags': [
            'Gaming', 'Gamer', 'EpicMoments', 'Gameplay', 'ProGaming',
            'VideoGames', 'GamingHighlights', 'Clutch',
          ],
        };
      default:
        return {
          'title':
              'You Won\'t Believe What Happens Next - The Most Amazing Video You Will Watch Today',
          'description':
              'Welcome to our channel! In this video, we bring you something truly special and amazing that you don\'t want to miss.\n\nMake sure to subscribe and hit the notification bell so you never miss our new uploads!\n\nIf you enjoyed this video, please give it a like and share it with your friends and family.\n\nYour support means everything to us. Thank you for watching!\n\nFollow us on social media for behind-the-scenes content and updates.',
          'tags': [
            'viral', 'trending', 'amazing', 'incredible', 'best video',
            'must watch', 'new video', 'top video', 'popular', 'content',
            'entertainment', 'fun', 'interesting', 'cool', 'awesome',
            'subscribe', 'like', 'share', 'video', 'youtube',
            'new upload', 'daily', 'weekly', 'channel', 'creator',
          ],
          'hashtags': [
            'Viral', 'Trending', 'MustWatch', 'Amazing', 'BestVideo',
            'YouTube', 'Subscribe', 'NewVideo',
          ],
        };
    }
  }
}
