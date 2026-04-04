import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/billing_service.dart';
import '../utils/app_theme.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Go Premium'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<BillingService>(
        builder: (context, billing, _) {
          if (billing.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (billing.isPremium) {
            return _buildAlreadyPremium(context);
          }

          return _buildUpgradeView(context, billing);
        },
      ),
    );
  }

  Widget _buildAlreadyPremium(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified, size: 80, color: Colors.green),
            ),
            const SizedBox(height: 24),
            const Text(
              'You are Premium!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'Enjoy unlimited uploads and all features.',
              style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeView(BuildContext context, BillingService billing) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Header
          const Icon(Icons.rocket_launch, size: 64, color: Color(0xFFFF5252)),
          const SizedBox(height: 16),
          const Text(
            'Upgrade to Premium',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Unlock the full power of TubeRocket',
            style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 32),

          // Features comparison
          _buildFeatureRow(Icons.upload, 'Video uploads', '3/day', 'Unlimited'),
          _buildFeatureRow(Icons.batch_prediction, 'Batch upload', 'No', 'Yes (10 videos)'),
          _buildFeatureRow(Icons.language, 'Languages', '5', 'All 18'),
          _buildFeatureRow(Icons.support_agent, 'Priority support', 'No', 'Yes'),
          const SizedBox(height: 32),

          // Subscription options
          if (billing.monthlyProduct != null)
            _buildPlanCard(
              context,
              billing,
              billing.monthlyProduct!,
              'Monthly',
              billing.monthlyProduct!.price,
              '/month',
              false,
            ),

          const SizedBox(height: 12),

          if (billing.yearlyProduct != null)
            _buildPlanCard(
              context,
              billing,
              billing.yearlyProduct!,
              'Yearly',
              billing.yearlyProduct!.price,
              '/year',
              true,
            ),

          if (billing.products.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF5252), width: 2),
              ),
              child: Column(
                children: [
                  const Text(
                    'Premium - \$4.99/month',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Subscriptions will be available soon!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5252),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Subscribe Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Restore purchases
          TextButton(
            onPressed: () async {
              await billing.restorePurchases();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Restoring purchases...')),
                );
              }
            },
            child: Text(
              'Restore Purchases',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),

          if (billing.error != null) ...[
            const SizedBox(height: 12),
            Text(
              billing.error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),

          // Legal text
          Text(
            'Subscriptions are managed by Google Play or App Store. '
            'Cancel anytime from your device settings.',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String feature, String free, String premium) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(feature, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
          Expanded(
            flex: 2,
            child: Text(free, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14), textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 2,
            child: Text(premium, style: const TextStyle(color: Color(0xFFFF5252), fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    BillingService billing,
    dynamic product,
    String label,
    String price,
    String period,
    bool recommended,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: recommended ? const Color(0xFFFF5252) : Colors.white.withValues(alpha: 0.1),
          width: recommended ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          if (recommended)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('BEST VALUE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          if (recommended) const SizedBox(height: 12),
          Text(label, style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.7))),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(period, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => billing.buySubscription(product),
              style: ElevatedButton.styleFrom(
                backgroundColor: recommended ? const Color(0xFFFF5252) : Colors.white.withValues(alpha: 0.1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Subscribe $price$period',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
