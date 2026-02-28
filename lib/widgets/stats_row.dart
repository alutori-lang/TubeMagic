import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class StatsRow extends StatelessWidget {
  final String? videos;
  final String? views;
  final String? subscribers;

  const StatsRow({
    super.key,
    this.videos,
    this.views,
    this.subscribers,
  });

  /// Formats large numbers: 1234 -> 1.2K, 1234567 -> 1.2M
  static String _formatNumber(String? raw) {
    if (raw == null || raw.isEmpty) return '0';
    final n = int.tryParse(raw);
    if (n == null) return raw;
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    } else if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStatCard(_formatNumber(videos), 'Published'),
        const SizedBox(width: 8),
        _buildStatCard(_formatNumber(views), 'Views'),
        const SizedBox(width: 8),
        _buildStatCard(_formatNumber(subscribers), 'Subs'),
      ],
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
