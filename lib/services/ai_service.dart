import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiService {
  // Groq API - free tier (Whisper + Llama)
  static const String _apiKey = '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';
  static const String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _whisperUrl = 'https://api.groq.com/openai/v1/audio/transcriptions';

  /// Transcribes audio from a video file using OpenAI Whisper API
  static Future<String?> transcribeVideo(String videoPath) async {
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

      final request = http.MultipartRequest('POST', Uri.parse(_whisperUrl));
      request.headers['Authorization'] = 'Bearer $_apiKey';
      request.fields['model'] = 'whisper-large-v3-turbo';
      request.fields['response_format'] = 'text';
      request.files.add(await http.MultipartFile.fromPath('file', videoPath));

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 3),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final transcription = response.body.trim();
        debugPrint('Transcription received (${transcription.length} chars): ${transcription.substring(0, transcription.length > 200 ? 200 : transcription.length)}...');
        return transcription.isNotEmpty ? transcription : null;
      } else {
        debugPrint('Whisper API failed with status ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Whisper transcription error: $e');
      return null;
    }
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

  /// Generates title, description, tags, and hashtags for a video
  /// Uses Whisper transcription when available for content-aware metadata
  static Future<Map<String, dynamic>> generateVideoMetadata({
    required String categoryName,
    required String languageCode,
    required String languageName,
    String? videoFileName,
    String? videoFilePath,
    String? channelId,
    void Function(String status)? onProgress,
  }) async {
    final topic = _extractTopicFromFileName(videoFileName);

    // Step 1: Try to transcribe the video audio
    String? transcription;
    if (videoFilePath != null) {
      onProgress?.call('Analyzing audio...');
      transcription = await transcribeVideo(videoFilePath);
    }

    onProgress?.call('Generating metadata...');

    // Step 2: Build the prompt based on whether we have a transcription
    String prompt;
    if (transcription != null && transcription.isNotEmpty) {
      // We have real audio content - use it!
      prompt = '''
You are a YouTube SEO expert AND a music expert. Generate optimized metadata for a YouTube video based on its ACTUAL AUDIO CONTENT.

VIDEO TRANSCRIPTION (what is said/sung in the video):
"""
$transcription
"""

Category: $categoryName
Language: $languageName ($languageCode)
Original file name: ${videoFileName ?? 'unknown'}

STEP 1 - IDENTIFY THE SONG AND ARTIST:
First, analyze the transcription carefully. Identify the song title from the key lyrics/phrases.
Then, use your knowledge to figure out WHO originally sang/performed this song.
- For example: if the lyrics contain "Peed tere jaan di, bhid tere jaan di" → this is the song "Peed Tere Jaan Di" by Gurdas Maan
- For example: if lyrics contain "Naina da kya kasoor" → this is by Amit Trivedi
- For example: if lyrics contain "Lamberghini" → this is by The Doorbeen ft Ragini
- Think hard about which famous singer/artist performs this song based on the lyrics you see

TITLE RULES (VERY IMPORTANT):
- Title MUST be at least 80 characters long (MINIMUM 80 chars, this is mandatory!)
- If you are CONFIDENT about the artist name → include it in the title. Example: "Peed Tere Jaan Di by Gurdas Maan Punjabi Best Emotional Song New Hit 2026"
- If you are NOT SURE about the artist → do NOT put any artist name in the title. Just write the song title with descriptive words. Example: "Peed Tere Jaan Di Punjabi Best Emotional Sad Song New Hit 2026 Must Listen"
- NEVER write "Unknown Artist", "Unknown Singer", "Unknown", or "Various Artists" in the title
- Title should include: song name + artist name (ONLY if confident) + language + descriptive words to reach 80+ chars
- CRITICAL: ALL text in ROMANIZED ENGLISH/LATIN alphabet letters ONLY (A-Z, a-z). No Gurmukhi, Devanagari, Arabic scripts etc.

DESCRIPTION RULES:
- Do NOT include hashtags in the description - they will be added automatically by the app
- Description MUST include actual lyrics/words from the transcription
- Include the transcription or key parts of it
- Minimum 400 characters
- Do NOT add any channel link - the app adds it automatically

TAGS RULES (VERY IMPORTANT - FOLLOW EXACTLY):
- Generate between 40 and 50 tags to fill up close to 460 characters total (NEVER exceed 500 characters total)
- Each INDIVIDUAL tag must be maximum 15 characters long
- The FIRST tag MUST be the song title/key phrase
- ALWAYS include an artist/singer name as a tag, even if you are only guessing. In tags you can put possible artist names. For example if you think the song might be by Gurdas Maan, put "gurdas maan" as a tag. If you think it could be by Diljit Dosanjh, put "diljit dosanjh". Always try to include at least one artist name in tags.
- Generate 40-50 short tags to reach ~460 total characters

LANGUAGE-SPECIFIC VIRAL TAGS (use the right ones based on detected language):
- For PUNJABI: "punjabi song", "punjabi music", "new punjabi", "punjabi hits", "desi music", "bhangra", "punjabi pop", "punjabi sad", "jatt", "gabru", "desi", "viral punjabi", "trending", "latest punjabi", "top punjabi"
- For HINDI: "hindi song", "bollywood", "hindi music", "new hindi", "bollywood hits", "desi music", "hindi pop", "trending hindi", "latest hindi", "viral hindi"
- For ENGLISH: "english song", "pop music", "new music", "viral song", "trending music", "top hits", "music video", "latest hits"
- For ARABIC: "arabic song", "arabic music", "khaleeji", "new arabic", "trending arabic"
- ALWAYS include: "viral", "trending", "new", "latest", "top", "best", "hits 2026", "music", "song"

Generate the following in JSON format:
{
  "title": "Song title with artist name ONLY if confident, minimum 80 characters, NEVER unknown",
  "description": "Description with lyrics/content, minimum 400 chars, NO hashtags, NO channel link",
  "tags": ["song title", "artist name guess", ... 40-50 tags, each max 15 chars, total ~460 chars],
  "hashtags": ["hashtag1", "hashtag2", ... 8-10 hashtags without # symbol]
}

Rules:
- Title: min 80 chars. Include artist ONLY if confident. NEVER write "unknown" or "various". Use romanized Latin letters only.
- Description: min 400 chars. Include actual lyrics. NO hashtags. NO channel link.
- Tags: 40-50 tags, each max 15 chars, total ~460 chars. First tag = song title. ALWAYS include artist name in tags even if just guessing.
- Hashtags: 8-10 relevant hashtags without # symbol
- ALL text in ROMANIZED English/Latin letters ONLY. No native scripts.
- Make it SEO optimized for going VIRAL

Return ONLY valid JSON, no other text.
''';
    } else {
      // No transcription available - use file name based approach
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
              'content': transcription != null
                  ? 'You are a YouTube SEO expert AND a music expert with deep knowledge of songs from all languages (Punjabi, Hindi, English, Arabic, etc.). You can identify songs and their artists from lyrics. You have access to the actual transcription of the video. First identify the song and its original artist/singer from the lyrics. Then generate metadata based on the REAL content. CRITICAL RULES: 1) ALWAYS try to identify the artist from the lyrics. 2) Put artist name in title ONLY if you are confident. 3) ALWAYS put artist name in tags even if just guessing. 4) NEVER write "unknown" anywhere. 5) ALL output text MUST use ONLY English/Latin alphabet letters (A-Z, a-z). NEVER use Gurmukhi, Devanagari, Arabic or any non-Latin script. Always respond with valid JSON only.'
                  : 'You are a YouTube SEO expert. Generate content based on the actual video topic. CRITICAL RULE: ALL output text MUST use ONLY English/Latin alphabet letters (A-Z, a-z). NEVER use non-Latin scripts. Write all non-English words in romanized form. Always respond with valid JSON only.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'max_tokens': 3000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        final cleanContent = content
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        metadata = jsonDecode(cleanContent) as Map<String, dynamic>;
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

    // Safety: ensure title is never empty or invalid
    String titleText = (metadata['title'] as String?)?.trim() ?? '';
    // Remove "Unknown Artist", "Unknown Singer" etc. from title
    titleText = titleText.replaceAll(RegExp(r'\b[Uu]nknown\s*[Aa]rtist\b'), '').trim();
    titleText = titleText.replaceAll(RegExp(r'\b[Uu]nknown\s*[Ss]inger\b'), '').trim();
    titleText = titleText.replaceAll(RegExp(r'\b[Uu]nknown\b'), '').trim();
    // Clean up double spaces and leading/trailing separators
    titleText = titleText.replaceAll(RegExp(r'\s*[-|]\s*[-|]\s*'), ' - ').trim();
    titleText = titleText.replaceAll(RegExp(r'\s+'), ' ').trim();
    titleText = titleText.replaceAll(RegExp(r'^[-|]\s*'), '').trim();
    titleText = titleText.replaceAll(RegExp(r'\s*[-|]$'), '').trim();

    if (titleText.isEmpty) {
      metadata['title'] = 'Amazing $categoryName Video - Must Watch Content You Will Love Today';
      debugPrint('WARNING: Title was empty, using fallback title');
    } else {
      metadata['title'] = titleText;
    }

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

    debugPrint('Generated title: "${metadata['title']}"');
    debugPrint('Generated title length: ${(metadata['title'] as String).length}');
    debugPrint('Had transcription: ${transcription != null}');

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
