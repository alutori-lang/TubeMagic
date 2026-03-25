import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/auth_service.dart';
import '../services/app_provider.dart';
import '../services/ai_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../utils/translations.dart';
import '../widgets/pulsing_upload_button.dart';
import '../widgets/stats_row.dart';
import '../widgets/gradient_button.dart';
import 'voice_changer_screen.dart';
import 'thumbnail_screen.dart';
import 'review_screen.dart';
import 'upload_screen.dart';
import 'batch_upload_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Batch: list of selected videos [{path, name}]
  final List<Map<String, String>> _selectedVideos = [];
  bool _isPickingFile = false;
  // Pre-transcribe audio in background for each video (keyed by path)
  final Map<String, Future<Map<String, String>?>> _preTranscriptionFutures = {};
  final Map<String, Map<String, String>?> _cachedTranscriptionResults = {};

  static const int _maxVideos = 10;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final app = context.watch<AppProvider>();
    final project = app.project;
    final t = Translations.t;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(
                  bottom: BorderSide(color: AppTheme.border),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    t('app_name'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                  const Spacer(),
                  // Avatar with gradient
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'logout') _handleLogout(context, auth);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'channel',
                        enabled: false,
                        child: Text(
                          auth.channelName ?? t('my_channel'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            const Icon(Icons.logout, size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(t('sign_out'),
                                style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: auth.channelAvatar != null
                          ? ClipOval(
                              child: Image.network(auth.channelAvatar!,
                                  width: 32, height: 32, fit: BoxFit.cover))
                          : const Center(
                              child: Text('U',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12))),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Row (real channel data)
                    StatsRow(
                      videos: auth.channelVideos,
                      views: auth.channelViews,
                      subscribers: auth.channelSubscribers,
                    ),
                    const SizedBox(height: 14),

                    // Big Upload Button
                    Center(
                      child: PulsingUploadButton(
                        onTap: _isPickingFile ? null : () => _pickVideo(app),
                        isSelected: _selectedVideos.isNotEmpty,
                        selectedFileName: _selectedVideos.length == 1
                            ? _selectedVideos.first['name']
                            : _selectedVideos.isNotEmpty
                                ? '${_selectedVideos.length} videos selected'
                                : null,
                        onPreview: _selectedVideos.length == 1
                            ? () => _previewVideo(_selectedVideos.first['path']!)
                            : null,
                      ),
                    ),

                    // Selected videos list (batch)
                    if (_selectedVideos.length > 1) ...[
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < _selectedVideos.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 22, height: 22,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text('${i + 1}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedVideos[i]['name'] ?? '',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _removeVideo(i),
                                      child: const Icon(Icons.close, size: 16, color: AppTheme.textHint),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    // Add more videos button
                    if (_selectedVideos.isNotEmpty && _selectedVideos.length < _maxVideos) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: GestureDetector(
                          onTap: _isPickingFile ? null : () => _pickVideo(app),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add, size: 16, color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Add Videos (${_selectedVideos.length}/$_maxVideos)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Progress area (when generating)
                    if (app.isGenerating) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: const LinearProgressIndicator(
                          backgroundColor: AppTheme.border,
                          color: AppTheme.primary,
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          app.project.status.isNotEmpty ? app.project.status : t('generating'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Settings header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Publishing Settings',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: Text(
                            'Edit All',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Video Language
                    _buildOptionTile(
                      icon: Icons.language,
                      label: t('language'),
                      value: project.languageName,
                      onTap: () => _showLanguagePicker(context, app),
                    ),

                    // Category
                    _buildOptionTile(
                      icon: Icons.category_outlined,
                      label: t('category'),
                      value: project.categoryName,
                      onTap: () => _showCategoryPicker(context, app),
                    ),

                    // Privacy Status
                    _buildOptionTile(
                      icon: Icons.shield_outlined,
                      label: t('privacy_status'),
                      value: t(project.privacyStatus),
                      onTap: () => _showPrivacyPicker(context, app),
                    ),

                    // Voice Changer
                    _buildOptionTile(
                      icon: Icons.mic_outlined,
                      label: t('voice_changer'),
                      value: project.voiceName,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const VoiceChangerScreen()),
                        );
                      },
                    ),

                    // Thumbnail
                    _buildOptionTile(
                      icon: Icons.image_outlined,
                      label: t('thumbnail'),
                      value: project.thumbnailStyle.isEmpty
                          ? t('choose_style')
                          : project.thumbnailStyle == 'auto'
                              ? t('auto_from_video')
                              : t('choose_from_gallery'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ThumbnailScreen()),
                        );
                      },
                    ),

                    // Kids option
                    _buildOptionTile(
                      icon: Icons.child_care,
                      label: t('made_for_kids'),
                      value: project.madeForKids ? t('yes') : t('no'),
                      onTap: () => _showKidsPicker(context, app),
                    ),

                    // Review toggle
                    _buildToggleTile(
                      icon: Icons.visibility_outlined,
                      label: t('review_before_upload'),
                      value: project.reviewBeforePublish,
                      onChanged: (v) => app.setReviewBeforePublish(v),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Bottom Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: GradientButton(
                text: app.isGenerating
                    ? t('generating')
                    : _selectedVideos.length > 1
                        ? 'Launch All (${_selectedVideos.length})'
                        : t('generate_publish'),
                subtitle: _selectedVideos.length > 1
                    ? 'AI processes each video automatically'
                    : 'AI generates title, description, tags & thumbnail',
                icon: app.isGenerating ? null : Icons.rocket_launch,
                isLoading: app.isGenerating,
                onPressed: _selectedVideos.isEmpty || app.isGenerating
                    ? null
                    : () => _startProcess(context, app, auth),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right,
                  size: 14, color: AppTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            // Custom toggle switch
            GestureDetector(
              onTap: () => onChanged(!value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 24,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: value ? AppTheme.primary : const Color(0xFFDDDDDD),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment:
                      value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _previewVideo(String videoPath) {
    showDialog(
      context: context,
      builder: (ctx) => _VideoPreviewDialog(videoPath: videoPath),
    );
  }

  void _removeVideo(int index) {
    final removed = _selectedVideos.removeAt(index);
    _preTranscriptionFutures.remove(removed['path']);
    _cachedTranscriptionResults.remove(removed['path']);
    // Update provider with first video (or clear)
    if (_selectedVideos.isNotEmpty) {
      final app = context.read<AppProvider>();
      app.setVideoFile(_selectedVideos.first['path']!);
    }
    setState(() {});
  }

  Future<void> _pickVideo(AppProvider app) async {
    setState(() => _isPickingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        for (final video in result.files) {
          if (video.path == null) continue;
          // Skip duplicates
          if (_selectedVideos.any((v) => v['path'] == video.path)) continue;
          // Max 10 videos
          if (_selectedVideos.length >= _maxVideos) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Maximum $_maxVideos videos allowed')),
              );
            }
            break;
          }
          _selectedVideos.add({'path': video.path!, 'name': video.name});
          // Start Whisper pre-transcription in background for each video
          debugPrint('SPEED: Starting background transcription for ${video.name}');
          final path = video.path!;
          _preTranscriptionFutures[path] = AiService.transcribeVideo(path)
            ..then((result) {
              _cachedTranscriptionResults[path] = result;
              debugPrint('SPEED: Background transcription done for ${video.name} (lang: ${result?['language']}, ${result?['text']?.length ?? 0} chars)');
            });
        }
        // Set first video in provider
        if (_selectedVideos.isNotEmpty) {
          app.setVideoFile(_selectedVideos.first['path']!);
        }
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${Translations.t('error_picking_video')}: $e')),
        );
      }
    }
    setState(() => _isPickingFile = false);
  }

  void _showLanguagePicker(BuildContext context, AppProvider app) {
    final t = Translations.t;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              t('select_language'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: AppConstants.languages.length,
              itemBuilder: (_, i) {
                final lang = AppConstants.languages[i];
                final isSelected =
                    app.project.languageCode == lang['code'];
                return ListTile(
                  title: Text(lang['name']!),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppTheme.primary)
                      : null,
                  onTap: () {
                    app.setLanguage(lang['code']!, lang['name']!);
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryPicker(BuildContext context, AppProvider app) {
    final t = Translations.t;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              t('select_category'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: AppConstants.videoCategories.length,
              itemBuilder: (_, i) {
                final cat = AppConstants.videoCategories[i];
                final isSelected = app.project.categoryId == cat['id'];
                return ListTile(
                  leading: Icon(
                    _getCategoryIcon(cat['icon']!),
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                  ),
                  title: Text(cat['name']!),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppTheme.primary)
                      : null,
                  onTap: () {
                    app.setCategory(cat['id']!, cat['name']!);
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPicker(BuildContext context, AppProvider app) {
    final t = Translations.t;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              t('select_privacy'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          ...AppConstants.privacyOptions.map((option) {
            final id = option['id']!;
            final isSelected = app.project.privacyStatus == id;
            return ListTile(
              leading: Icon(
                _getPrivacyIcon(option['icon']!),
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              title: Text(t(id)),
              subtitle: Text(
                t('${id}_desc'),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: AppTheme.primary)
                  : null,
              onTap: () {
                app.setPrivacyStatus(id);
                Navigator.pop(ctx);
              },
            );
          }),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _showKidsPicker(BuildContext context, AppProvider app) {
    final t = Translations.t;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              t('made_for_kids'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.block,
              color: !app.project.madeForKids ? AppTheme.primary : AppTheme.textSecondary,
            ),
            title: Text(t('no')),
            trailing: !app.project.madeForKids
                ? const Icon(Icons.check, color: AppTheme.primary)
                : null,
            onTap: () {
              app.setMadeForKids(false);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.child_care,
              color: app.project.madeForKids ? AppTheme.primary : AppTheme.textSecondary,
            ),
            title: Text(t('yes')),
            trailing: app.project.madeForKids
                ? const Icon(Icons.check, color: AppTheme.primary)
                : null,
            onTap: () {
              app.setMadeForKids(true);
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  IconData _getPrivacyIcon(String icon) {
    switch (icon) {
      case 'public': return Icons.public;
      case 'link': return Icons.link;
      case 'lock': return Icons.lock;
      default: return Icons.public;
    }
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'music_note': return Icons.music_note;
      case 'sentiment_very_satisfied': return Icons.sentiment_very_satisfied;
      case 'sports_soccer': return Icons.sports_soccer;
      case 'sports_esports': return Icons.sports_esports;
      case 'videocam': return Icons.videocam;
      case 'school': return Icons.school;
      case 'movie': return Icons.movie;
      case 'auto_fix_high': return Icons.auto_fix_high;
      case 'newspaper': return Icons.newspaper;
      case 'science': return Icons.science;
      case 'flight': return Icons.flight;
      case 'pets': return Icons.pets;
      default: return Icons.category;
    }
  }

  Future<void> _startProcess(
      BuildContext context, AppProvider app, AuthService auth) async {
    // BATCH MODE: navigate to batch upload screen
    if (_selectedVideos.length > 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BatchUploadScreen(
            videos: List.from(_selectedVideos),
            preTranscriptionFutures: Map.from(_preTranscriptionFutures),
            cachedTranscriptionResults: Map.from(_cachedTranscriptionResults),
          ),
        ),
      );
      return;
    }

    // SINGLE VIDEO MODE (with review support)
    app.setGenerating(true);
    app.setStatus('generating');

    try {
      final videoPath = _selectedVideos.first['path']!;
      final videoName = _selectedVideos.first['name'];

      // Use pre-cached transcription if available
      Map<String, String>? preResult;
      if (_cachedTranscriptionResults.containsKey(videoPath)) {
        preResult = _cachedTranscriptionResults[videoPath];
        debugPrint('SPEED: Transcription was ready instantly (pre-cached)');
      } else if (_preTranscriptionFutures.containsKey(videoPath)) {
        app.setStatus('Finishing audio analysis...');
        preResult = await _preTranscriptionFutures[videoPath];
      }

      // Generate AI metadata
      final metadata = await AiService.generateVideoMetadata(
        categoryName: app.project.categoryName,
        languageCode: app.project.languageCode,
        languageName: app.project.languageName,
        videoFileName: videoName,
        videoFilePath: videoPath,
        channelId: auth.channelId,
        channelName: auth.channelName,
        preTranscriptionResult: preResult,
        onProgress: (status) {
          app.setStatus(status);
        },
      );

      app.setTitle(metadata['title'] as String);
      app.setDescription(metadata['description'] as String);
      app.setTags(List<String>.from(metadata['tags'] as List));
      app.setHashtags(List<String>.from(metadata['hashtags'] as List));

      // Set video file
      app.setVideoFile(videoPath);
      app.project.videoFile = File(videoPath);

      app.setGenerating(false);

      if (!context.mounted) return;

      // Navigate based on review preference
      if (app.project.reviewBeforePublish) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReviewScreen()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UploadScreen()),
        );
      }
    } catch (e) {
      app.setGenerating(false);
      app.setError(e.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${Translations.t('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleLogout(BuildContext context, AuthService auth) async {
    await auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }
}

class _VideoPreviewDialog extends StatefulWidget {
  final String videoPath;
  const _VideoPreviewDialog({required this.videoPath});

  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() => _initialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // Video player
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: _initialized ? _controller.value.aspectRatio : 16 / 9,
              child: _initialized
                  ? VideoPlayer(_controller)
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
            ),
          ),
          // Controls
          if (_initialized)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      setState(() {
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.replay, color: Colors.white70, size: 22),
                    onPressed: () {
                      _controller.seekTo(Duration.zero);
                      _controller.play();
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
