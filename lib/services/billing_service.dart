import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'usage_limit_service.dart';

/// Manages premium subscriptions via Google Play / App Store.
class BillingService extends ChangeNotifier {
  static const String monthlyId = 'premium_monthly';
  static const String yearlyId = 'premium_yearly';
  static const Set<String> _productIds = {monthlyId, yearlyId};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _available = false;
  bool _isPremium = false;
  bool _loading = true;
  List<ProductDetails> _products = [];
  String? _error;

  bool get available => _available;
  bool get isPremium => _isPremium;
  bool get loading => _loading;
  List<ProductDetails> get products => _products;
  String? get error => _error;

  BillingService() {
    _init();
  }

  Future<void> _init() async {
    // Check if billing is available on this device
    _available = await _iap.isAvailable();
    if (!_available) {
      _loading = false;
      debugPrint('[Billing] Store not available');
      notifyListeners();
      return;
    }

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) => debugPrint('[Billing] Stream error: $error'),
    );

    // Load products
    await _loadProducts();

    // Restore previous purchases
    await restorePurchases();

    _loading = false;
    notifyListeners();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(_productIds);

      if (response.error != null) {
        _error = response.error!.message;
        debugPrint('[Billing] Error loading products: ${response.error!.message}');
        return;
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('[Billing] Products not found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      debugPrint('[Billing] Loaded ${_products.length} products');
      for (final p in _products) {
        debugPrint('[Billing] Product: ${p.id} - ${p.title} - ${p.price}');
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('[Billing] Error: $e');
    }
  }

  /// Buy a subscription
  Future<bool> buySubscription(ProductDetails product) async {
    try {
      _error = null;
      final purchaseParam = PurchaseParam(productDetails: product);
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      debugPrint('[Billing] Purchase initiated: $success');
      return success;
    } catch (e) {
      _error = e.toString();
      debugPrint('[Billing] Purchase error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[Billing] Restore error: $e');
    }
  }

  /// Handle purchase updates from the store
  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      debugPrint('[Billing] Purchase update: ${purchase.productID} - ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _verifyAndActivate(purchase);
          break;
        case PurchaseStatus.error:
          _error = purchase.error?.message ?? 'Purchase failed';
          debugPrint('[Billing] Purchase error: ${purchase.error?.message}');
          notifyListeners();
          break;
        case PurchaseStatus.canceled:
          debugPrint('[Billing] Purchase canceled');
          notifyListeners();
          break;
        case PurchaseStatus.pending:
          debugPrint('[Billing] Purchase pending');
          break;
      }

      // Complete pending purchases
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  /// Verify purchase and activate premium
  Future<void> _verifyAndActivate(PurchaseDetails purchase) async {
    // In production, you should verify the purchase on a backend server.
    // For now, we trust the store receipt.
    if (_productIds.contains(purchase.productID)) {
      _isPremium = true;
      await UsageLimitService.setPremium(true);
      debugPrint('[Billing] Premium ACTIVATED for ${purchase.productID}');
      notifyListeners();
    }
  }

  /// Check premium status from local storage (for app restart)
  Future<void> checkPremiumStatus() async {
    _isPremium = await UsageLimitService.isPremium();
    notifyListeners();
  }

  /// Get monthly product
  ProductDetails? get monthlyProduct {
    try {
      return _products.firstWhere((p) => p.id == monthlyId);
    } catch (_) {
      return null;
    }
  }

  /// Get yearly product
  ProductDetails? get yearlyProduct {
    try {
      return _products.firstWhere((p) => p.id == yearlyId);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
