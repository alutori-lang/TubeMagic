import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';
import '../services/auth_service.dart';
import '../services/ai_service.dart';
import '../services/youtube_service.dart';
import '../models/video_project.dart';
import '../utils/app_theme.dart';
import '../utils/translations.dart';
import 'home_screen.dart';

class BatchUploadScreen extends StatefulWidget {
  final List<Map<String, String>> videos;
  final Map<String, Future<Map<String, String>?>> preTranscriptionFutures;
  final Map<String, Map<String, String>?> cachedTranscriptionResults;

  const BatchUploadScreen({
    super.key,
    required this.videos,
    required this.preTranscriptionFutures,
    required this.cachedTranscriptionResults,
  });

  @override
  State<BatchUploadScreen> createState() => _BatchUploadScreenState();
}

// Phase 1: generating metadata, Phase 2: review, Phase 3: uploading, Phase 4: done
enum _BatchPhase { generating, review, uploading, done }

enum _VideoStatus { generating, ready, uploading, done, error, cancelled }

class _VideoState {
  final String path;
  final String name;
  _VideoStatus status;
  String? title;
  String? description;
  List<String>? tags;
  List<String>? hashtags;
  String? errorMessage;
  String? youtubeUrl;
  bool removed = false;

  _VideoState({required this.path, required this.name}) : status = _VideoStatus.generating;
}

class _BatchUploadScreenState extends State<BatchUploadScreen> {
  final List<_VideoState> _videoStates = [];
  _BatchPhase _phase = _BatchPhase.generating;
  int _successCount = 0;
  int _errorCount = 0;

  @override
  void initState() {
    super.initState();
    for (final v in widget.videos) {
      _videoStates.add(_VideoState(path: v['path']!, name: v['name']!));
    }
    // Phase 1: generate metadata for all videos in parallel
    _generateAllMetadata();
  }

  /// Phase 1: Generate metadata for ALL videos in parallel
  Future<void> _generateAllMetadata() async {
    final app = context.read<AppProvider>();
    final auth = context.read<AuthService>();

    final futures = <Future>[];
    for (int i = 0; i < _videoStates.length; i++) {
      futures.add(_generateOneMetadata(i, app, auth));
    }
    await Future.wait(futures);

    if (mounted) {
      setState(() => _phase = _BatchPhase.review);
    }
  }

  Future<void> _generateOneMetadata(int index, AppProvider app, AuthService auth) async {
    final vs = _videoStates[index];
    try {
      // Get transcription (should be pre-cached)
      Map<String, String>? transcription;
      if (widget.cachedTranscriptionResults.containsKey(vs.path)) {
        transcription = widget.cachedTranscriptionResults[vs.path];
      } else if (widget.preTranscriptionFutures.containsKey(vs.path)) {
        transcription = await widget.preTranscriptionFutures[vs.path];
      } else {
        transcription = await AiService.transcribeVideo(vs.path);
      }
      if (!mounted) return;

      // Generate metadata
      final metadata = await AiService.generateVideoMetadata(
        categoryName: app.project.categoryName,
        languageCode: app.project.languageCode,
        languageName: app.project.languageName,
        videoFileName: vs.name,
        videoFilePath: vs.path,
        channelId: auth.channelId,
        preTranscriptionResult: transcription,
        onProgress: (_) {},
      );

      vs.title = metadata['title'] as String;
      vs.description = metadata['description'] as String;
      vs.tags = List<String>.from(metadata['tags'] as List);
      vs.hashtags = List<String>.from(metadata['hashtags'] as List);
      if (mounted) setState(() => vs.status = _VideoStatus.ready);
    } catch (e) {
      debugPrint('BATCH[$index] metadata error: $e');
      vs.errorMessage = e.toString();
      if (mounted) setState(() => vs.status = _VideoStatus.error);
    }
  }

  /// Phase 3: Upload ALL ready videos in parallel
  Future<void> _uploadAll() async {
    setState(() => _phase = _BatchPhase.uploading);
    final app = context.read<AppProvider>();
    final auth = context.read<AuthService>();

    final client = await auth.getValidAuthClient();
    if (client == null) {
      for (final vs in _videoStates.where((v) => v.status == _VideoStatus.ready)) {
        vs.status = _VideoStatus.error;
        vs.errorMessage = 'Not authenticated';
        _errorCount++;
      }
      setState(() => _phase = _BatchPhase.done);
      return;
    }

    final futures = <Future>[];
    for (int i = 0; i < _videoStates.length; i++) {
      if (_videoStates[i].status == _VideoStatus.ready) {
        futures.add(_uploadOne(i, app, client));
      }
    }
    await Future.wait(futures);

    if (mounted) setState(() => _phase = _BatchPhase.done);
  }

  Future<void> _uploadOne(int index, AppProvider app, dynamic client) async {
    final vs = _videoStates[index];
    if (mounted) setState(() => vs.status = _VideoStatus.uploading);

    try {
      final tempProject = VideoProject();
      tempProject.title = vs.title ?? vs.name;
      tempProject.description = vs.description ?? '';
      tempProject.tags = vs.tags ?? [];
      tempProject.hashtags = vs.hashtags ?? [];
      tempProject.categoryId = app.project.categoryId;
      tempProject.categoryName = app.project.categoryName;
      tempProject.privacyStatus = app.project.privacyStatus;
      tempProject.madeForKids = app.project.madeForKids;
      tempProject.videoPath = vs.path;
      tempProject.videoFile = File(vs.path);

      final videoId = await YoutubeService.uploadVideo(
        authClient: client,
        project: tempProject,
        onProgress: (_) {},
      );

      if (videoId != null) {
        vs.youtubeUrl = 'https://www.youtube.com/watch?v=$videoId';
        if (mounted) setState(() { vs.status = _VideoStatus.done; _successCount++; });
        debugPrint('BATCH[$index]: ${vs.name} -> $videoId');
      } else {
        if (mounted) setState(() { vs.status = _VideoStatus.error; vs.errorMessage = 'No ID'; _errorCount++; });
      }
    } catch (e) {
      debugPrint('BATCH[$index] upload error: $e');
      if (mounted) setState(() { vs.status = _VideoStatus.error; vs.errorMessage = e.toString(); _errorCount++; });
    }
  }

  /// Remove a video from the batch (before upload)
  void _removeVideo(int index) {
    setState(() {
      _videoStates[index].removed = true;
      _videoStates[index].status = _VideoStatus.cancelled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeVideos = _videoStates.where((v) => !v.removed).toList();
    final readyCount = activeVideos.where((v) => v.status == _VideoStatus.ready).length;
    final generatingCount = activeVideos.where((v) => v.status == _VideoStatus.generating).length;

    return PopScope(
      canPop: _phase == _BatchPhase.done || _phase == _BatchPhase.review,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(activeVideos),

              // Phase indicator
              _buildPhaseBar(),

              // Video list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: _videoStates.length,
                  itemBuilder: (_, i) {
                    if (_videoStates[i].removed) return const SizedBox.shrink();
                    return _buildVideoItem(_videoStates[i], i);
                  },
                ),
              ),

              // Bottom action button
              _buildBottomButton(readyCount, generatingCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(List<_VideoState> activeVideos) {
    String subtitle;
    switch (_phase) {
      case _BatchPhase.generating:
        subtitle = 'AI is generating metadata...';
      case _BatchPhase.review:
        subtitle = 'Review and confirm';
      case _BatchPhase.uploading:
        subtitle = 'Uploading to YouTube...';
      case _BatchPhase.done:
        subtitle = '$_successCount uploaded successfully';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Batch Upload',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Text('${activeVideos.length} videos',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPhaseBar() {
    final phaseIndex = _phase.index; // 0=generating, 1=review, 2=uploading, 3=done
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _buildPhaseStep('Generate', 0, phaseIndex),
          _buildPhaseLine(phaseIndex >= 1),
          _buildPhaseStep('Review', 1, phaseIndex),
          _buildPhaseLine(phaseIndex >= 2),
          _buildPhaseStep('Upload', 2, phaseIndex),
        ],
      ),
    );
  }

  Widget _buildPhaseStep(String label, int step, int current) {
    final isDone = current > step;
    final isActive = current == step;
    return Column(
      children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? AppTheme.successGreen : isActive ? AppTheme.primary : AppTheme.border,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text('${step + 1}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : AppTheme.textHint)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: isActive ? AppTheme.primary : isDone ? AppTheme.successGreen : AppTheme.textHint)),
      ],
    );
  }

  Widget _buildPhaseLine(bool active) {
    return Expanded(
      child: Container(
        height: 2, margin: const EdgeInsets.only(bottom: 16),
        color: active ? AppTheme.successGreen : AppTheme.border,
      ),
    );
  }

  Widget _buildBottomButton(int readyCount, int generatingCount) {
    if (_phase == _BatchPhase.generating) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: const LinearProgressIndicator(
                backgroundColor: AppTheme.border, color: AppTheme.primary, minHeight: 3),
            ),
            const SizedBox(height: 8),
            Text('Generating metadata... $generatingCount remaining',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    if (_phase == _BatchPhase.review) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: readyCount > 0 ? _uploadAll : null,
            icon: const Icon(Icons.cloud_upload, size: 20),
            label: Text('Upload $readyCount Videos',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.border,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      );
    }

    if (_phase == _BatchPhase.uploading) {
      final total = _videoStates.where((v) => !v.removed && v.status != _VideoStatus.cancelled).length;
      final done = _successCount + _errorCount;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: total > 0 ? done / total : 0,
                backgroundColor: AppTheme.border, color: AppTheme.primary, minHeight: 3),
            ),
            const SizedBox(height: 8),
            Text('Uploading... $done/$total',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    // Done
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            context.read<AppProvider>().resetProject();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          },
          icon: Icon(_errorCount == 0 ? Icons.check_circle : Icons.home, size: 20),
          label: Text(
            _errorCount == 0
                ? 'All $_successCount Videos Uploaded!'
                : '$_successCount uploaded, $_errorCount failed',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: _errorCount == 0 ? AppTheme.successGreen : AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  /// Open bottom sheet to view/edit video metadata
  void _openEditSheet(_VideoState vs, int index) {
    final t = Translations.t;
    final titleCtrl = TextEditingController(text: vs.title ?? '');
    final descCtrl = TextEditingController(text: vs.description ?? '');
    final tagsCtrl = TextEditingController(text: vs.tags?.join(', ') ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header with save button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(vs.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (_phase == _BatchPhase.review)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            vs.title = titleCtrl.text.trim();
                            vs.description = descCtrl.text.trim();
                            vs.tags = tagsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                          });
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(t('save'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
                      )
                    else
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 20, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
              const Divider(color: AppTheme.border),
              // Editable fields
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(t('title'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleCtrl,
                        maxLines: 2,
                        readOnly: _phase != _BatchPhase.review,
                        decoration: _sheetInputDecoration(t('title_hint')),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Text(t('description'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descCtrl,
                        maxLines: 8,
                        readOnly: _phase != _BatchPhase.review,
                        decoration: _sheetInputDecoration(t('description_hint')),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      // Tags
                      Text(t('tags'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: tagsCtrl,
                        maxLines: 3,
                        readOnly: _phase != _BatchPhase.review,
                        decoration: _sheetInputDecoration(t('tags_hint')),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      // Hashtags display
                      if (vs.hashtags != null && vs.hashtags!.isNotEmpty) ...[
                        Text(t('hashtags'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6, runSpacing: 6,
                          children: vs.hashtags!.map((tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text('#$tag',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _sheetInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textHint),
      filled: true,
      fillColor: AppTheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildVideoItem(_VideoState vs, int index) {
    final canRemove = _phase == _BatchPhase.review || _phase == _BatchPhase.generating;
    final showDetails = (_phase == _BatchPhase.review || _phase == _BatchPhase.uploading || _phase == _BatchPhase.done)
        && vs.title != null;
    final canTap = showDetails && vs.status != _VideoStatus.cancelled;

    IconData icon;
    Color iconColor;
    String statusText;
    bool showSpinner = false;

    switch (vs.status) {
      case _VideoStatus.generating:
        icon = Icons.auto_awesome;
        iconColor = AppTheme.primary;
        statusText = 'Generating...';
        showSpinner = true;
      case _VideoStatus.ready:
        icon = Icons.check_circle_outline;
        iconColor = AppTheme.successGreen;
        statusText = 'Ready to upload';
      case _VideoStatus.uploading:
        icon = Icons.cloud_upload;
        iconColor = AppTheme.primary;
        statusText = 'Uploading...';
        showSpinner = true;
      case _VideoStatus.done:
        icon = Icons.check_circle;
        iconColor = AppTheme.successGreen;
        statusText = 'Uploaded';
      case _VideoStatus.error:
        icon = Icons.error_outline;
        iconColor = Colors.red;
        statusText = vs.errorMessage ?? 'Failed';
      case _VideoStatus.cancelled:
        icon = Icons.block;
        iconColor = AppTheme.textHint;
        statusText = 'Removed';
    }

    return GestureDetector(
      onTap: canTap ? () => _openEditSheet(vs, index) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: vs.status == _VideoStatus.done
              ? AppTheme.successGreen.withValues(alpha: 0.04)
              : showSpinner
                  ? AppTheme.iconBg
                  : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: vs.status == _VideoStatus.done
                ? AppTheme.successGreen.withValues(alpha: 0.2)
                : showSpinner
                    ? AppTheme.primary.withValues(alpha: 0.2)
                    : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + name + cancel
            Row(
              children: [
                if (showSpinner)
                  const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                else
                  Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vs.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(statusText,
                          style: TextStyle(fontSize: 11, color: iconColor)),
                    ],
                  ),
                ),
                // Cancel/remove button
                if (canRemove && vs.status != _VideoStatus.cancelled)
                  GestureDetector(
                    onTap: () => _removeVideo(index),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.red),
                    ),
                  ),
              ],
            ),
            // Generated metadata preview (in review/upload/done phases)
            if (showDetails) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vs.title!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (vs.tags != null && vs.tags!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Tags: ${vs.tags!.take(5).join(', ')}${vs.tags!.length > 5 ? '...' : ''}',
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                    // Tap hint in review phase
                    if (_phase == _BatchPhase.review) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.edit_note, size: 14, color: AppTheme.primary.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Text('Tap to view & edit',
                              style: TextStyle(fontSize: 10, color: AppTheme.primary.withValues(alpha: 0.6))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
