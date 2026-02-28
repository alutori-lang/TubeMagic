import 'package:flutter/foundation.dart';
import '../models/video_project.dart';
import '../utils/translations.dart';

class AppProvider extends ChangeNotifier {
  final VideoProject _project = VideoProject();
  bool _isGenerating = false;
  bool _isUploading = false;
  String _appLocale = 'en';

  VideoProject get project => _project;
  bool get isGenerating => _isGenerating;
  bool get isUploading => _isUploading;
  String get appLocale => _appLocale;

  void setAppLocale(String locale) {
    _appLocale = locale;
    Translations.setLocale(locale);
    notifyListeners();
  }

  void setVideoFile(String path) {
    _project.videoPath = path;
    notifyListeners();
  }

  void setCategory(String id, String name) {
    _project.categoryId = id;
    _project.categoryName = name;
    notifyListeners();
  }

  void setLanguage(String code, String name) {
    _project.languageCode = code;
    _project.languageName = name;
    notifyListeners();
  }

  void setVoice(String id, String name, double pitch) {
    _project.voiceId = id;
    _project.voiceName = name;
    _project.voicePitch = pitch;
    notifyListeners();
  }

  void setMadeForKids(bool value) {
    _project.madeForKids = value;
    notifyListeners();
  }

  void setReviewBeforePublish(bool value) {
    _project.reviewBeforePublish = value;
    notifyListeners();
  }

  void setTitle(String title) {
    _project.title = title;
    notifyListeners();
  }

  void setDescription(String desc) {
    _project.description = desc;
    notifyListeners();
  }

  void setTags(List<String> tags) {
    _project.tags = tags;
    notifyListeners();
  }

  void setHashtags(List<String> hashtags) {
    _project.hashtags = hashtags;
    notifyListeners();
  }

  void setThumbnailStyle(String style) {
    _project.thumbnailStyle = style;
    notifyListeners();
  }

  void setThumbnailCustomPrompt(String prompt) {
    _project.thumbnailCustomPrompt = prompt;
    notifyListeners();
  }

  void setPrivacyStatus(String status) {
    _project.privacyStatus = status;
    notifyListeners();
  }

  void setThumbnailFile(dynamic file) {
    _project.thumbnailFile = file;
    notifyListeners();
  }

  void setGenerating(bool value) {
    _isGenerating = value;
    notifyListeners();
  }

  void setUploading(bool value) {
    _isUploading = value;
    notifyListeners();
  }

  void setUploadProgress(double value) {
    _project.uploadProgress = value;
    notifyListeners();
  }

  void setStatus(String status) {
    _project.status = status;
    notifyListeners();
  }

  void setError(String? error) {
    _project.errorMessage = error;
    notifyListeners();
  }

  void setYoutubeResult(String videoId) {
    _project.youtubeVideoId = videoId;
    _project.youtubeVideoUrl = 'https://www.youtube.com/watch?v=$videoId';
    notifyListeners();
  }

  void resetProject() {
    _project.reset();
    _isGenerating = false;
    _isUploading = false;
    notifyListeners();
  }
}
