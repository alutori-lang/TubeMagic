import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../services/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/translations.dart';

class ThumbnailScreen extends StatefulWidget {
  const ThumbnailScreen({super.key});

  @override
  State<ThumbnailScreen> createState() => _ThumbnailScreenState();
}

class _ThumbnailScreenState extends State<ThumbnailScreen> {
  String? _selectedOption; // 'auto' or 'gallery'
  File? _thumbnailFile;
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    if (app.project.thumbnailStyle.isNotEmpty) {
      _selectedOption = app.project.thumbnailStyle;
    }
    if (app.project.thumbnailFile != null) {
      _thumbnailFile = app.project.thumbnailFile;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.t;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('thumbnail_title')),
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Option 1: Auto from video
                _buildOption(
                  id: 'auto',
                  icon: Icons.auto_awesome,
                  title: t('auto_from_video'),
                  subtitle: t('auto_from_video_desc'),
                ),
                const SizedBox(height: 12),

                // Option 2: Choose from gallery
                _buildOption(
                  id: 'gallery',
                  icon: Icons.photo_library_outlined,
                  title: t('choose_from_gallery'),
                  subtitle: t('choose_from_gallery_desc'),
                ),
                const SizedBox(height: 20),

                // Preview
                if (_isExtracting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  ),

                if (_thumbnailFile != null && !_isExtracting) ...[
                  Text(
                    t('thumbnail_selected'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _thumbnailFile!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Save button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedOption == null ? null : () => _save(context),
                child: Text(t('save')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedOption == id;

    return Material(
      color: isSelected
          ? AppTheme.primary.withValues(alpha: 0.05)
          : AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _onOptionTap(id),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withValues(alpha: 0.1)
                      : AppTheme.iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle,
                    color: AppTheme.primary, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onOptionTap(String id) async {
    setState(() => _selectedOption = id);

    if (id == 'auto') {
      await _extractFromVideo();
    } else if (id == 'gallery') {
      await _pickFromGallery();
    }
  }

  Future<void> _extractFromVideo() async {
    final app = context.read<AppProvider>();
    if (app.project.videoPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Translations.t('no_video_selected'))),
        );
      }
      return;
    }

    setState(() => _isExtracting = true);

    try {
      // Use video_player to get a frame
      final controller = VideoPlayerController.file(
        File(app.project.videoPath!),
      );
      await controller.initialize();

      // Seek to 1 second for a good frame
      final duration = controller.value.duration;
      final seekTo = duration.inSeconds > 3
          ? const Duration(seconds: 2)
          : Duration(milliseconds: duration.inMilliseconds ~/ 2);
      await controller.seekTo(seekTo);
      await Future.delayed(const Duration(milliseconds: 500));

      await controller.dispose();

      // For auto thumbnail, we set the style and YouTube will auto-generate
      setState(() {
        _isExtracting = false;
        _thumbnailFile = null; // YouTube auto-generates from video
      });
    } catch (e) {
      setState(() => _isExtracting = false);
      // Auto thumbnail means YouTube will generate it automatically
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 90,
      );
      if (picked != null) {
        setState(() {
          _thumbnailFile = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${Translations.t('error')}: $e')),
        );
      }
    }
  }

  void _save(BuildContext context) {
    final app = context.read<AppProvider>();
    app.setThumbnailStyle(_selectedOption!);
    if (_thumbnailFile != null) {
      app.setThumbnailFile(_thumbnailFile);
    } else {
      app.setThumbnailFile(null);
    }
    Navigator.pop(context);
  }
}
