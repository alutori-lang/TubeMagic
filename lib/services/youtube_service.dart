import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/youtube/v3.dart' as yt;
import 'package:http/http.dart' as http;
import '../models/video_project.dart';

class YoutubeService {
  /// Uploads a video to YouTube using the authenticated client
  static Future<String?> uploadVideo({
    required http.Client authClient,
    required VideoProject project,
    required ValueChanged<double> onProgress,
  }) async {
    try {
      final youtubeApi = yt.YouTubeApi(authClient);

      // Safety: ensure title is never empty and max 100 chars
      String videoTitle = project.title.trim();
      if (videoTitle.isEmpty) {
        videoTitle = 'My Video ${DateTime.now().toString().substring(0, 10)}';
      }
      if (videoTitle.length > 100) {
        videoTitle = videoTitle.substring(0, 100);
      }

      // Clean description - max 5000 chars
      String description = project.fullDescription.trim();
      if (description.length > 5000) {
        description = description.substring(0, 5000);
      }

      // Clean tags - remove empty, limit each to 30 chars, limit total to 480 chars
      final allTags = project.tags
          .where((t) => t.trim().isNotEmpty)
          .map((t) => t.trim().length > 30 ? t.trim().substring(0, 30) : t.trim())
          .toSet() // remove duplicates
          .toList();

      // Enforce YouTube's 500-char total limit for tags
      final cleanTags = <String>[];
      int totalChars = 0;
      for (final tag in allTags) {
        if (totalChars + tag.length > 480) break;
        cleanTags.add(tag);
        totalChars += tag.length;
      }

      debugPrint('=== UPLOAD DEBUG ===');
      debugPrint('Title: "$videoTitle" (${videoTitle.length} chars)');
      debugPrint('Description: ${description.length} chars');
      debugPrint('Tags: ${cleanTags.length} tags');
      debugPrint('Category ID: ${project.categoryId}');
      debugPrint('Language: ${project.languageCode}');
      debugPrint('Privacy: ${project.privacyStatus}');
      debugPrint('Made for kids: ${project.madeForKids}');

      // Create video metadata
      final snippet = yt.VideoSnippet();
      snippet.title = videoTitle;
      snippet.description = description;
      snippet.categoryId = project.categoryId;
      if (cleanTags.isNotEmpty) {
        snippet.tags = cleanTags;
      }

      final status = yt.VideoStatus();
      status.privacyStatus = project.privacyStatus;
      status.selfDeclaredMadeForKids = project.madeForKids;

      final video = yt.Video();
      video.snippet = snippet;
      video.status = status;

      // Log the full JSON being sent
      debugPrint('Video JSON: ${jsonEncode(video.toJson())}');

      // Read video file
      final videoFile = project.videoFile!;
      final fileLength = await videoFile.length();
      final mediaStream = videoFile.openRead();

      // Create upload media
      final media = yt.Media(
        mediaStream,
        fileLength,
        contentType: 'video/mp4',
      );

      // Upload video
      onProgress(0.1);

      final response = await youtubeApi.videos.insert(
        video,
        ['snippet', 'status'],
        uploadMedia: media,
      );

      onProgress(0.9);

      // Set thumbnail if available
      if (project.thumbnailFile != null) {
        try {
          final thumbFile = project.thumbnailFile!;
          final thumbLength = await thumbFile.length();
          final thumbStream = thumbFile.openRead();
          final thumbMedia = yt.Media(
            thumbStream,
            thumbLength,
            contentType: 'image/jpeg',
          );
          await youtubeApi.thumbnails.set(
            response.id!,
            uploadMedia: thumbMedia,
          );
        } catch (e) {
          debugPrint('Thumbnail upload failed: $e');
        }
      }

      onProgress(1.0);
      return response.id;
    } catch (e) {
      debugPrint('YouTube upload error: $e');
      rethrow;
    }
  }

  /// Gets channel info for the authenticated user
  static Future<Map<String, String?>> getChannelInfo(
      http.Client authClient) async {
    try {
      final youtubeApi = yt.YouTubeApi(authClient);
      final response = await youtubeApi.channels.list(
        ['snippet', 'statistics'],
        mine: true,
      );

      if (response.items != null && response.items!.isNotEmpty) {
        final channel = response.items!.first;
        return {
          'id': channel.id,
          'name': channel.snippet?.title,
          'avatar': channel.snippet?.thumbnails?.default_?.url,
          'subscribers': channel.statistics?.subscriberCount,
        };
      }
      return {};
    } catch (e) {
      debugPrint('Channel info error: $e');
      return {};
    }
  }
}
