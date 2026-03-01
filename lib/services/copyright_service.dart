import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CopyrightResult {
  final bool isCopyrighted;
  final String? artist;
  final String? title;
  final String? album;

  CopyrightResult({
    required this.isCopyrighted,
    this.artist,
    this.title,
    this.album,
  });
}

class CopyrightService {
  static const String _apiUrl = 'https://api.audd.io/';
  static const String _apiToken = 'test';

  /// Check if a video contains copyrighted music using AudD API
  /// Returns CopyrightResult with match details if found
  /// Fails open: if API errors, returns not copyrighted (doesn't block user)
  static Future<CopyrightResult> checkCopyright(String videoPath) async {
    try {
      debugPrint('COPYRIGHT: Starting check for $videoPath');

      final file = File(videoPath);
      if (!await file.exists()) {
        debugPrint('COPYRIGHT: File not found');
        return CopyrightResult(isCopyrighted: false);
      }

      final fileSize = await file.length();
      debugPrint('COPYRIGHT: File size ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB');

      // AudD accepts up to 32MB for MP4 files
      if (fileSize > 32 * 1024 * 1024) {
        debugPrint('COPYRIGHT: File too large for AudD (>32MB), skipping check');
        return CopyrightResult(isCopyrighted: false);
      }

      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      request.fields['api_token'] = _apiToken;
      request.files.add(await http.MultipartFile.fromPath('file', videoPath));

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 2),
      );
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('COPYRIGHT: API response status ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('COPYRIGHT: Response body: ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}');

        if (data['status'] == 'success' && data['result'] != null) {
          final result = data['result'];
          final artist = result['artist']?.toString() ?? '';
          final title = result['title']?.toString() ?? '';
          final album = result['album']?.toString() ?? '';

          debugPrint('COPYRIGHT: MATCH FOUND - "$title" by "$artist" (Album: $album)');

          return CopyrightResult(
            isCopyrighted: true,
            artist: artist.isNotEmpty ? artist : null,
            title: title.isNotEmpty ? title : null,
            album: album.isNotEmpty ? album : null,
          );
        } else {
          debugPrint('COPYRIGHT: No match found - video is clean');
          return CopyrightResult(isCopyrighted: false);
        }
      } else {
        debugPrint('COPYRIGHT: API error ${response.statusCode}: ${response.body}');
        return CopyrightResult(isCopyrighted: false);
      }
    } catch (e) {
      debugPrint('COPYRIGHT: Error during check: $e');
      // Fail open - don't block user if API fails
      return CopyrightResult(isCopyrighted: false);
    }
  }
}
