import 'dart:io';

class VideoProject {
  File? videoFile;
  String? videoPath;
  String title = '';
  String description = '';
  List<String> tags = [];
  List<String> hashtags = [];
  String categoryId = '22'; // Default: People & Blogs
  String categoryName = 'Vlog / People';
  String languageCode = 'en';
  String languageName = 'English (US)';
  String voiceId = 'original';
  String voiceName = 'Original';
  double voicePitch = 1.0;
  bool madeForKids = true;
  bool reviewBeforePublish = false;
  String privacyStatus = 'public'; // public, unlisted, private
  String thumbnailStyle = ''; // 'auto' or 'gallery'
  String thumbnailCustomPrompt = '';
  File? thumbnailFile;
  String? thumbnailUrl;
  bool isProcessing = false;
  double uploadProgress = 0.0;
  String status = 'idle'; // idle, generating, uploading, done, error
  String? errorMessage;
  String? youtubeVideoId;
  String? youtubeVideoUrl;

  VideoProject();

  String get tagsString => tags.join(', ');
  String get hashtagsString => hashtags.map((h) => '#$h').join(' ');

  String get privacyLabel {
    switch (privacyStatus) {
      case 'public': return 'Public';
      case 'unlisted': return 'Unlisted';
      case 'private': return 'Private';
      default: return 'Public';
    }
  }

  String get fullDescription {
    final buffer = StringBuffer();
    buffer.writeln(description);
    buffer.writeln();
    if (hashtags.isNotEmpty) {
      buffer.writeln(hashtagsString);
      buffer.writeln();
    }
    return buffer.toString();
  }

  void reset() {
    videoFile = null;
    videoPath = null;
    title = '';
    description = '';
    tags = [];
    hashtags = [];
    categoryId = '22';
    categoryName = 'Vlog / People';
    languageCode = 'en';
    languageName = 'English (US)';
    voiceId = 'original';
    voiceName = 'Original';
    voicePitch = 1.0;
    madeForKids = true;
    reviewBeforePublish = false;
    privacyStatus = 'public';
    thumbnailStyle = '';
    thumbnailCustomPrompt = '';
    thumbnailFile = null;
    thumbnailUrl = null;
    isProcessing = false;
    uploadProgress = 0.0;
    status = 'idle';
    errorMessage = null;
    youtubeVideoId = null;
    youtubeVideoUrl = null;
  }
}
