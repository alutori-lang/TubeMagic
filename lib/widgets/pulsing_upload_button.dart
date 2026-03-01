import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class PulsingUploadButton extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onPreview;
  final bool isSelected;
  final String? selectedFileName;

  const PulsingUploadButton({
    super.key,
    this.onTap,
    this.onPreview,
    this.isSelected = false,
    this.selectedFileName,
  });

  @override
  State<PulsingUploadButton> createState() => _PulsingUploadButtonState();
}

class _PulsingUploadButtonState extends State<PulsingUploadButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing ring
                if (!widget.isSelected)
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _opacityAnimation.value,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.primaryGradient,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                // Main button
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF2ED573), Color(0xFF26C666)],
                          )
                        : AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: (widget.isSelected
                                ? AppTheme.successGreen
                                : AppTheme.primary)
                            .withValues(alpha: 0.3),
                        blurRadius: 25,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isSelected
                            ? Icons.check_rounded
                            : Icons.arrow_upward_rounded,
                        size: 30,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.isSelected ? 'SELECTED' : 'UPLOAD',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.selectedFileName ?? 'Tap to select videos from your device',
          style: TextStyle(
            fontSize: 11,
            color: widget.isSelected ? AppTheme.textPrimary : AppTheme.textHint,
            fontWeight: widget.isSelected ? FontWeight.w500 : FontWeight.w400,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.isSelected && widget.onPreview != null) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: widget.onPreview,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.iconBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline, size: 14, color: AppTheme.primary),
                  SizedBox(width: 4),
                  Text(
                    'Preview',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
