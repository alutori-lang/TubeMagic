import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../services/auth_service.dart';
import '../services/youtube_service.dart';
import '../services/usage_limit_service.dart';
import '../utils/app_theme.dart';
import '../utils/translations.dart';
import '../widgets/gradient_button.dart';
import 'home_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _successAnimController;
  late Animation<double> _successScale;
  late String _statusText;
  double _progress = 0.0;
  bool _isDone = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _statusText = Translations.t('preparing_upload');
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _successAnimController, curve: Curves.elasticOut),
    );

    _startUpload();
  }

  @override
  void dispose() {
    _animController.dispose();
    _successAnimController.dispose();
    super.dispose();
  }

  Future<void> _startUpload() async {
    final app = context.read<AppProvider>();
    final auth = context.read<AuthService>();
    final t = Translations.t;

    // Try to get a valid auth client (re-authenticate if needed)
    final client = await auth.getValidAuthClient();

    if (client == null) {
      setState(() {
        _hasError = true;
        _errorMessage = t('not_authenticated');
      });
      return;
    }

    if (app.project.videoFile == null) {
      setState(() {
        _hasError = true;
        _errorMessage = t('no_video_selected');
      });
      return;
    }

    setState(() => _statusText = t('uploading_video'));

    try {
      final videoId = await YoutubeService.uploadVideo(
        authClient: client,
        project: app.project,
        onProgress: (progress) {
          setState(() {
            _progress = progress;
            if (progress < 0.3) {
              _statusText = t('uploading_video');
            } else if (progress < 0.7) {
              _statusText = t('processing_video');
            } else if (progress < 0.95) {
              _statusText = t('setting_metadata');
            } else {
              _statusText = t('finalizing');
            }
          });
        },
      );

      if (videoId != null) {
        await UsageLimitService.recordUpload();
        app.setYoutubeResult(videoId);
        setState(() {
          _isDone = true;
          _statusText = t('upload_complete');
          _progress = 1.0;
        });
        _animController.stop();
        _successAnimController.forward();
      }
    } catch (e) {
      final titlePreview = app.project.title.isEmpty
          ? 'EMPTY'
          : app.project.title.substring(0, app.project.title.length > 40 ? 40 : app.project.title.length);
      debugPrint('Upload failed! Title was: "${app.project.title}"');
      debugPrint('Upload failed! Error: $e');
      setState(() {
        _hasError = true;
        _errorMessage = '$e\n\n[Debug - Title: "$titlePreview..."]';
        _statusText = t('upload_failed');
      });
      _animController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final t = Translations.t;

    return PopScope(
      canPop: _isDone || _hasError,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Status icon
                if (_isDone)
                  ScaleTransition(
                    scale: _successScale,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 60,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  )
                else if (_hasError)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_rounded,
                      size: 60,
                      color: Colors.red,
                    ),
                  )
                else
                  RotationTransition(
                    turns: _animController,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_upload_rounded,
                        size: 50,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 30),

                // Status text
                Text(
                  _statusText,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _hasError ? Colors.red : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Progress bar (thin 4px)
                if (!_isDone && !_hasError) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      backgroundColor: AppTheme.border,
                      color: AppTheme.primary,
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],

                // Error message
                if (_hasError && _errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],

                // Success info
                if (_isDone) ...[
                  const SizedBox(height: 8),
                  Text(
                    t('video_published'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Video URL
                  if (app.project.youtubeVideoUrl != null)
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: app.project.youtubeVideoUrl!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t('url_copied'))),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.link,
                                size: 18, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                app.project.youtubeVideoUrl!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.copy,
                                size: 16, color: AppTheme.textHint),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Video details
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.project.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${app.project.tags.length} ${t('tags')} · ${app.project.hashtags.length} ${t('hashtags')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                // Bottom buttons
                if (_isDone || _hasError)
                  _hasError
                      ? SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              app.resetProject();
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) => const HomeScreen()),
                                (route) => false,
                              );
                            },
                            icon: const Icon(Icons.refresh, size: 20),
                            label: Text(t('try_again'),
                                style: const TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.red,
                            ),
                          ),
                        )
                      : GradientButton(
                          text: t('upload_another'),
                          icon: Icons.add,
                          onPressed: () {
                            app.resetProject();
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (_) => const HomeScreen()),
                              (route) => false,
                            );
                          },
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
