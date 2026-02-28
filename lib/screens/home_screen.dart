import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/auth_service.dart';
import '../services/app_provider.dart';
import '../services/ai_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../utils/translations.dart';
import 'voice_changer_screen.dart';
import 'thumbnail_screen.dart';
import 'review_screen.dart';
import 'upload_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedVideoName;
  bool _isPickingFile = false;

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
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
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
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primary,
                      backgroundImage: auth.channelAvatar != null
                          ? NetworkImage(auth.channelAvatar!)
                          : null,
                      child: auth.channelAvatar == null
                          ? const Text('U',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700))
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Upload Zone
                    GestureDetector(
                      onTap: _isPickingFile ? null : () => _pickVideo(app),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 35),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _selectedVideoName != null
                                ? AppTheme.primary.withValues(alpha: 0.3)
                                : const Color(0xFFDDDDDD),
                            width: 2,
                            style: _selectedVideoName != null
                                ? BorderStyle.solid
                                : BorderStyle.none,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _selectedVideoName != null
                                  ? Icons.check_circle_rounded
                                  : Icons.cloud_upload_outlined,
                              size: 48,
                              color: _selectedVideoName != null
                                  ? AppTheme.primary
                                  : AppTheme.textHint,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _selectedVideoName ?? t('upload_video'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _selectedVideoName != null
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedVideoName != null
                                  ? t('tap_to_change')
                                  : t('tap_to_select'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Settings label
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        t('settings'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),

                    // App Language
                    _buildOptionTile(
                      icon: Icons.translate,
                      label: t('app_language'),
                      value: _getLanguageName(app.appLocale),
                      onTap: () => _showAppLanguagePicker(context, app),
                    ),

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

                    // Review toggle
                    _buildToggleTile(
                      icon: Icons.visibility_outlined,
                      label: t('review_before_upload'),
                      value: project.reviewBeforePublish,
                      onChanged: (v) => app.setReviewBeforePublish(v),
                    ),

                    // Kids toggle
                    _buildToggleTile(
                      icon: Icons.child_care,
                      label: t('made_for_kids'),
                      value: project.madeForKids,
                      onChanged: (v) => app.setMadeForKids(v),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedVideoName == null || app.isGenerating
                      ? null
                      : () => _startProcess(context, app, auth),
                  icon: app.isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.rocket_launch, size: 20),
                  label: Text(
                    app.isGenerating
                        ? t('generating')
                        : t('generate_publish'),
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLanguageName(String code) {
    for (final lang in AppConstants.languages) {
      if (lang['code'] == code) return lang['name']!;
    }
    return 'English (US)';
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 20, color: AppTheme.textHint),
              ],
            ),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: AppTheme.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideo(AppProvider app) async {
    setState(() => _isPickingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        app.setVideoFile(file.path!);
        setState(() {
          _selectedVideoName = file.name;
        });
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

  void _showAppLanguagePicker(BuildContext context, AppProvider app) {
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
              t('select_app_language'),
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
                final isSelected = app.appLocale == lang['code'];
                return ListTile(
                  title: Text(lang['name']!),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppTheme.primary)
                      : null,
                  onTap: () {
                    app.setAppLocale(lang['code']!);
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
    app.setGenerating(true);
    app.setStatus('generating');

    try {
      // Generate AI metadata (with audio transcription if available)
      final metadata = await AiService.generateVideoMetadata(
        categoryName: app.project.categoryName,
        languageCode: app.project.languageCode,
        languageName: app.project.languageName,
        videoFileName: _selectedVideoName,
        videoFilePath: app.project.videoPath,
        channelId: auth.channelId,
      );

      app.setTitle(metadata['title'] as String);
      app.setDescription(metadata['description'] as String);
      app.setTags(List<String>.from(metadata['tags'] as List));
      app.setHashtags(List<String>.from(metadata['hashtags'] as List));

      // Set video file
      if (app.project.videoPath != null) {
        app.project.videoFile = File(app.project.videoPath!);
      }

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
