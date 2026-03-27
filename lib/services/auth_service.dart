import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'youtube_service.dart';

class AuthService extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: AppConstants.youtubeScopes,
    clientId: '682566361571-0l049imldscm5n2tke4rup724ut91jqm.apps.googleusercontent.com',
    serverClientId: '682566361571-1vk8mggcr2k0ooqi2nk879u4443v2eq3.apps.googleusercontent.com',
  );

  GoogleSignInAccount? _currentUser;
  http.Client? _authClient;
  bool _isLoading = false;
  String? _channelName;
  String? _channelAvatar;
  String? _channelId;
  String? _channelSubscribers;
  String? _channelViews;
  String? _channelVideos;
  bool _isAppleUser = false;

  GoogleSignInAccount? get currentUser => _currentUser;
  http.Client? get authClient => _authClient;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null || _isAppleUser;
  bool get isAppleUser => _isAppleUser;
  bool get isYoutubeConnected => _authClient != null;
  String? get channelName => _channelName;
  String? get channelAvatar => _channelAvatar;
  String? get channelId => _channelId;
  String? get channelSubscribers => _channelSubscribers;
  String? get channelViews => _channelViews;
  String? get channelVideos => _channelVideos;

  AuthService() {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      _currentUser = account;
      notifyListeners();
    });
    _tryAutoSignIn();
  }

  Future<void> _tryAutoSignIn() async {
    try {
      await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        await _setupAuthClient();
      }
    } catch (e) {
      debugPrint('Auto sign-in failed: $e');
    }
  }

  String? _lastError;
  String? get lastError => _lastError;

  Future<bool> signIn() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _currentUser = account;
        await _setupAuthClient();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _lastError = 'Sign-in cancelled';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Sign-in error: $e');
      _lastError = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _setupAuthClient() async {
    try {
      final client = await _googleSignIn.authenticatedClient();
      _authClient = client as http.Client?;
      _channelName = _currentUser?.displayName ?? 'YouTube Channel';
      _channelAvatar = _currentUser?.photoUrl;
      debugPrint('Auth client setup OK: ${_authClient != null}');

      // Fetch channel ID from YouTube API
      if (_authClient != null) {
        _fetchChannelId();
      }
    } catch (e) {
      debugPrint('Auth client setup error: $e');
      _authClient = null;
    }
  }

  Future<void> _fetchChannelId() async {
    try {
      if (_authClient == null) return;
      final info = await YoutubeService.getChannelInfo(_authClient!);
      if (info['id'] != null) {
        _channelId = info['id'];
        _channelSubscribers = info['subscribers'];
        _channelViews = info['views'];
        _channelVideos = info['videos'];
        debugPrint('Channel ID fetched: $_channelId');
        debugPrint('Channel stats: $_channelVideos videos, $_channelViews views, $_channelSubscribers subs');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Fetch channel ID error: $e');
    }
  }

  /// Gets a fresh auth client, always refreshing the token
  Future<http.Client?> getValidAuthClient() async {
    // Always get fresh tokens before API calls
    try {
      // Re-authenticate silently to refresh tokens
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = account;
        // Get a fresh authenticated client with new tokens
        final client = await _googleSignIn.authenticatedClient();
        _authClient = client as http.Client?;
        debugPrint('Fresh auth client obtained: ${_authClient != null}');
        return _authClient;
      }
    } catch (e) {
      debugPrint('Token refresh failed: $e');
    }

    // If silent sign-in failed, try with the current user
    if (_currentUser != null) {
      try {
        final client = await _googleSignIn.authenticatedClient();
        _authClient = client as http.Client?;
        debugPrint('Auth client from current user: ${_authClient != null}');
        return _authClient;
      } catch (e) {
        debugPrint('Auth client from current user failed: $e');
      }
    }

    return null;
  }

  Future<bool> signInWithApple() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      _isAppleUser = true;
      _channelName = [
        credential.givenName,
        credential.familyName,
      ].where((n) => n != null).join(' ');
      if (_channelName == null || _channelName!.isEmpty) {
        _channelName = 'Apple User';
      }
      _channelAvatar = null;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Apple Sign-in error: $e');
      _lastError = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Connect YouTube channel for Apple users (Google OAuth for YouTube API only)
  Future<bool> connectYouTube() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _currentUser = account;
        await _setupAuthClient();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _lastError = 'YouTube connection cancelled';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('YouTube connect error: $e');
      _lastError = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _authClient = null;
    _channelName = null;
    _channelAvatar = null;
    _channelId = null;
    _channelSubscribers = null;
    _channelViews = null;
    _channelVideos = null;
    _isAppleUser = false;
    notifyListeners();
  }
}
