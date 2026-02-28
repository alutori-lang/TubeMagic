class AppConstants {
  static const String appName = 'TubeMagic';
  static const String appTagline = 'Smart YouTube video publisher';

  // YouTube API Scopes
  static const List<String> youtubeScopes = [
    'https://www.googleapis.com/auth/youtube.upload',
    'https://www.googleapis.com/auth/youtube',
    'https://www.googleapis.com/auth/youtube.readonly',
  ];

  // Video Categories
  static const List<Map<String, String>> videoCategories = [
    {'id': '10', 'name': 'Music', 'icon': 'music_note'},
    {'id': '23', 'name': 'Comedy', 'icon': 'sentiment_very_satisfied'},
    {'id': '17', 'name': 'Sports', 'icon': 'sports_soccer'},
    {'id': '20', 'name': 'Gaming', 'icon': 'sports_esports'},
    {'id': '22', 'name': 'Vlog / People', 'icon': 'videocam'},
    {'id': '27', 'name': 'Education', 'icon': 'school'},
    {'id': '24', 'name': 'Entertainment', 'icon': 'movie'},
    {'id': '26', 'name': 'How-to / Style', 'icon': 'auto_fix_high'},
    {'id': '25', 'name': 'News / Politics', 'icon': 'newspaper'},
    {'id': '28', 'name': 'Science / Tech', 'icon': 'science'},
    {'id': '19', 'name': 'Travel / Events', 'icon': 'flight'},
    {'id': '15', 'name': 'Pets / Animals', 'icon': 'pets'},
  ];

  // Voice Changer Options
  static const List<Map<String, dynamic>> voiceOptions = [
    {'id': 'original', 'name': 'Original', 'icon': 'mic', 'pitch': 1.0, 'rate': 0.5},
    {'id': 'boy', 'name': 'Boy', 'icon': 'boy', 'pitch': 1.5, 'rate': 0.55},
    {'id': 'adult_male', 'name': 'Adult Male', 'icon': 'man', 'pitch': 0.65, 'rate': 0.45},
    {'id': 'woman', 'name': 'Woman', 'icon': 'woman', 'pitch': 1.7, 'rate': 0.5},
    {'id': 'girl', 'name': 'Girl', 'icon': 'girl', 'pitch': 2.0, 'rate': 0.6},
    {'id': 'old', 'name': 'Old', 'icon': 'elderly', 'pitch': 0.4, 'rate': 0.35},
    {'id': 'young', 'name': 'Young', 'icon': 'face', 'pitch': 1.3, 'rate': 0.55},
  ];

  // Languages
  static const List<Map<String, String>> languages = [
    {'code': 'en', 'name': 'English (US)'},
    {'code': 'it', 'name': 'Italian'},
    {'code': 'es', 'name': 'Spanish'},
    {'code': 'fr', 'name': 'French'},
    {'code': 'de', 'name': 'German'},
    {'code': 'pt', 'name': 'Portuguese'},
    {'code': 'hi', 'name': 'Hindi'},
    {'code': 'ar', 'name': 'Arabic'},
    {'code': 'ja', 'name': 'Japanese'},
    {'code': 'ko', 'name': 'Korean'},
    {'code': 'zh', 'name': 'Chinese'},
    {'code': 'ru', 'name': 'Russian'},
    {'code': 'tr', 'name': 'Turkish'},
    {'code': 'nl', 'name': 'Dutch'},
    {'code': 'pl', 'name': 'Polish'},
    {'code': 'ur', 'name': 'Urdu'},
    {'code': 'bn', 'name': 'Bengali'},
    {'code': 'pa', 'name': 'Punjabi'},
  ];

  // Privacy options
  static const List<Map<String, String>> privacyOptions = [
    {'id': 'public', 'icon': 'public'},
    {'id': 'unlisted', 'icon': 'link'},
    {'id': 'private', 'icon': 'lock'},
  ];
}
