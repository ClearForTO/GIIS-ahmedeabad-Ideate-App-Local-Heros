import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

// ── CONFIGURATION ────────────────────────────────────────────────────────────
const String supabaseUrl = 'https://jrtfioiksijpkrpneffe.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpydGZpb2lrc2lqcGtycG5lZmZlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3Mzg4NjksImV4cCI6MjA4MDMxNDg2OX0.aHm2VTbbGqxLoc_qgUCc5sTUwcyEhjPRoC-5wIxvhp0';
const String geminiApiKey = 'AIzaSyBtJYA79fFedjBvlCWAjPtmvamdD964sbQ';
const String geminiApiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

// ── HELPERS ───────────────────────────────────────────────────────────────────
void showLoader(BuildContext context) => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()));

void showSnackbar(BuildContext context, String message, {bool isError = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2)));

Widget buildAvatar(String? base64, String username, {double radius = 24}) {
  ImageProvider? imageProvider;
  if (base64 != null && base64.isNotEmpty) {
    try {
      final bytes = base64Decode(base64);
      imageProvider = MemoryImage(bytes);
    } catch (e) {
      debugPrint('❌ Avatar decode error: $e');
      imageProvider = null;
    }
  }
  
  return CircleAvatar(
    radius: radius,
    backgroundColor: Colors.deepPurple,
    backgroundImage: imageProvider,
    child: imageProvider == null
        ? Text(
            username.isNotEmpty ? username[0].toUpperCase() : '?',
            style: TextStyle(color: Colors.white, fontSize: radius * 0.8),
          )
        : null,
  );
}

// ── MODELS ────────────────────────────────────────────────────────────────────
class UserProfile {
  final String id, username, email;
  final String? displayName, quote, profilePic, themeId, qrCode;
  final int followersCount;
  final int followingCount;
  
  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.quote,
    this.profilePic,
    this.themeId,
    this.qrCode,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'email': email,
        'display_name': displayName,
        'quote': quote,
        'profile_pic': profilePic,
        'theme_id': themeId,
        'qr_code': qrCode,
      };

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        id: m['id'] ?? '',
        username: m['username'] ?? '',
        email: m['email'] ?? '',
        displayName: m['display_name'],
        quote: m['quote'],
        profilePic: m['profile_pic'],
        themeId: m['theme_id'],
        qrCode: m['qr_code'],
        followersCount: m['followers_count'] ?? 0,
        followingCount: m['following_count'] ?? 0,
      );
}

class Post {
  final String id, author, title, content;
  final String? imagePath, bgImagePath;
  final Color? bgColor;
  final DateTime timestamp;
  int salutes;
  bool userSaluted;
  
  Post({
    required this.id,
    required this.author,
    required this.title,
    required this.content,
    this.imagePath,
    this.bgImagePath,
    this.bgColor,
    required this.timestamp,
    this.salutes = 0,
    this.userSaluted = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'author': author,
        'title': title,
        'content': content,
        'image_path': imagePath,
        'bg_image_path': bgImagePath,
        'bg_color': bgColor?.value,
        'timestamp': timestamp.toIso8601String(),
        'salutes': salutes
      };

  factory Post.fromMap(Map<String, dynamic> m) => Post(
        id: m['id'] ?? '',
        author: m['author'] ?? '',
        title: m['title'] ?? '',
        content: m['content'] ?? '',
        imagePath: m['image_path'],
        bgImagePath: m['bg_image_path'],
        bgColor: m['bg_color'] != null ? Color(m['bg_color']) : null,
        timestamp: DateTime.tryParse(m['timestamp'] ?? '') ?? DateTime.now(),
        salutes: m['salutes'] ?? 0,
        userSaluted: false,
      );
}

class AppTheme {
  final String id, name;
  final Color primaryColor;
  final Brightness brightness;
  final bool isCustom;
  final String? userId;
  
  AppTheme({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.brightness,
    this.isCustom = false,
    this.userId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'primary_color': primaryColor.value,
        'brightness': brightness == Brightness.dark ? 'dark' : 'light',
        'is_custom': isCustom,
        'user_id': userId
      };

  factory AppTheme.fromMap(Map<String, dynamic> m) => AppTheme(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        primaryColor: Color(m['primary_color'] ?? Colors.deepPurple.value),
        brightness: m['brightness'] == 'dark' ? Brightness.dark : Brightness.light,
        isCustom: m['is_custom'] ?? false,
        userId: m['user_id'],
      );

  ThemeData toThemeData() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: primaryColor, brightness: brightness),
        useMaterial3: true,
        brightness: brightness,
      );
}

class Message {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  
  Message({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() => {
        'role': isUser ? 'user' : 'model',
        'parts': [{'text': text}]
      };
}

// ── KNOWLEDGE HUB MODELS ────────────────────────────────────────────────────
class Profession {
  final String id;
  final String name;
  final String shortDescription;
  final String whoTheyAre;
  final String hardships;
  final String howToShowRespect;
  final List<String> tags;
  final IconData icon;
  
  Profession({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.whoTheyAre,
    required this.hardships,
    required this.howToShowRespect,
    required this.tags,
    required this.icon,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'shortDescription': shortDescription,
        'whoTheyAre': whoTheyAre,
        'hardships': hardships,
        'howToShowRespect': howToShowRespect,
        'tags': tags,
      };

  factory Profession.fromMap(Map<String, dynamic> m) => Profession(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        shortDescription: m['shortDescription'] ?? '',
        whoTheyAre: m['whoTheyAre'] ?? '',
        hardships: m['hardships'] ?? '',
        howToShowRespect: m['howToShowRespect'] ?? '',
        tags: List<String>.from(m['tags'] ?? []),
        icon: Icons.work,
      );
}

// ── PROVIDERS ─────────────────────────────────────────────────────────────────
class AuthProvider extends ChangeNotifier {
  final supabase = Supabase.instance.client;
  User? _user;
  UserProfile? _profile;
  bool _isInitialized = false;
  List<UserProfile> _searchUsersResults = [];
  final Map<String, bool> _followingStatus = {};
  
  User? get user => _user;
  UserProfile? get profile => _profile;
  String? get username => _profile?.username;
  bool get isLoggedIn => _user != null;
  bool get isInitialized => _isInitialized;
  List<UserProfile> get searchUsersResults => _searchUsersResults;

  Future<void> signup(String email, String password, String username) async {
    try {
      final res = await supabase.auth.signUp(
        email: email, 
        password: password, 
        data: {'username': username}
      );
      _user = res.user;
      if (_user != null) {
        _profile = UserProfile(
          id: _user!.id,
          username: username,
          email: email,
          displayName: username,
        );
        await supabase.from('profiles').insert(_profile!.toMap()).onError((_, __) => null);
      }
      notifyListeners();
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final res = await supabase.auth.signInWithPassword(email: email, password: password);
      _user = res.user;
      if (_user != null) await _loadProfile();
      notifyListeners();
    } on AuthException catch (e) {
      if (e.statusCode == 400) throw Exception('Invalid email or password');
      if (e.message.contains('email not confirmed')) throw Exception('Please confirm your email');
      throw Exception(e.message);
    }
  }

  Future<void> _loadProfile() async {
    if (_user == null) return;
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', _user!.id)
          .maybeSingle();
      _profile = response != null
          ? UserProfile.fromMap(response)
          : UserProfile(
              id: _user!.id,
              username: _user!.email?.split('@')[0] ?? 'user',
              email: _user!.email ?? '',
            );
      if (response == null) await supabase.from('profiles').insert(_profile!.toMap());
    } catch (e) {
      _profile = UserProfile(
        id: _user!.id,
        username: _user!.email?.split('@')[0] ?? 'user',
        email: _user!.email ?? '',
      );
    }
  }

  Future<UserProfile?> loadUserProfile(String userId) async {
    try {
      final profileRes = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (profileRes == null) return null;
      
      return UserProfile.fromMap(profileRes);
    } catch (e) {
      debugPrint('❌ Load user profile error: $e');
      return null;
    }
  }

  Future<String?> getUserIdFromUsername(String username) async {
    try {
      final res = await supabase
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      return res?['id'];
    } catch (e) {
      debugPrint('❌ getUserIdFromUsername error: $e');
      return null;
    }
  }

  Future<void> updateProfile(UserProfile updatedProfile) async {
    await supabase
        .from('profiles')
        .update(updatedProfile.toMap())
        .eq('id', updatedProfile.id);
    _profile = updatedProfile;
    notifyListeners();
  }

  Future<void> updateUserTheme(String themeId) async {
    if (_user == null) return;
    await supabase
        .from('profiles')
        .update({'theme_id': themeId})
        .eq('id', _user!.id);
    _profile = UserProfile(
      id: _profile!.id,
      username: _profile!.username,
      email: _profile!.email,
      displayName: _profile!.displayName,
      quote: _profile!.quote,
      profilePic: _profile!.profilePic,
      qrCode: _profile!.qrCode,
      themeId: themeId,
    );
    notifyListeners();
  }

  Future<void> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      _searchUsersResults = [];
    } else {
      try {
        final response = await supabase
            .from('profiles')
            .select()
            .or('username.ilike.%$query%,display_name.ilike.%$query%');
        _searchUsersResults = [for (var m in response) UserProfile.fromMap(m)];
      } catch (e) {
        debugPrint('❌ Search users error: $e');
        _searchUsersResults = [];
      }
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    _user = null;
    _profile = null;
    _searchUsersResults = [];
    _followingStatus.clear();
    notifyListeners();
  }

  Future<void> checkAuth() async {
    final session = supabase.auth.currentSession;
    _user = session?.user;
    if (_user != null) await _loadProfile();
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> isFollowing(String userId) async {
    if (_user == null) return false;
    if (_followingStatus.containsKey(userId)) {
      return _followingStatus[userId]!;
    }
    final res = await supabase
        .from('followers')
        .select()
        .eq('follower_id', _user!.id)
        .eq('following_id', userId)
        .maybeSingle();
    _followingStatus[userId] = res != null;
    return res != null;
  }

  Future<void> followUser(String userId) async {
    if (_user == null) throw Exception('Not logged in');
    await supabase.from('followers').insert({
      'follower_id': _user!.id,
      'following_id': userId,
    });
    _followingStatus[userId] = true;
    notifyListeners();
  }

  Future<void> unfollowUser(String userId) async {
    if (_user == null) throw Exception('Not logged in');
    await supabase
        .from('followers')
        .delete()
        .eq('follower_id', _user!.id)
        .eq('following_id', userId);
    _followingStatus[userId] = false;
    notifyListeners();
  }
}

class ThemeProvider extends ChangeNotifier {
  final supabase = Supabase.instance.client;
  List<AppTheme> _themes = [];
  AppTheme? _currentTheme;
  String? _userId;
  
  List<AppTheme> get themes => _themes;
  AppTheme? get currentTheme => _currentTheme;

  static final List<AppTheme> _defaultThemes = [
    AppTheme(
        id: 'deep-purple',
        name: 'Deep Purple',
        primaryColor: Colors.deepPurple,
        brightness: Brightness.light),
    AppTheme(
        id: 'dark-mode',
        name: 'Dark Mode',
        primaryColor: Colors.deepPurple,
        brightness: Brightness.dark),
    AppTheme(
        id: 'ocean-blue',
        name: 'Ocean Blue',
        primaryColor: Colors.blue,
        brightness: Brightness.light),
    AppTheme(
        id: 'forest-green',
        name: 'Forest Green',
        primaryColor: Colors.green,
        brightness: Brightness.light),
    AppTheme(
        id: 'sunset-orange',
        name: 'Sunset Orange',
        primaryColor: Colors.orange,
        brightness: Brightness.light),
  ];

  Future<void> loadThemes(String userId) async {
    _userId = userId;
    _themes = [..._defaultThemes];
    try {
      final customThemes = await supabase.from('user_themes').select().eq('user_id', userId);
      final seenIds = <String>{};
      for (var m in customThemes) {
        final theme = AppTheme.fromMap(m);
        if (!seenIds.contains(theme.id)) {
          _themes.add(theme);
          seenIds.add(theme.id);
        }
      }
    } catch (e) {
      debugPrint('❌ Load custom themes error: $e');
    }
    notifyListeners();
  }

  Future<void> loadUserTheme(String? themeId) async {
    _currentTheme = themeId == null
        ? _defaultThemes[0]
        : _themes.firstWhere((t) => t.id == themeId,
            orElse: () => _defaultThemes[0]);
    notifyListeners();
  }

  Future<void> createCustomTheme(
      String name, Color color, Brightness brightness) async {
    if (_userId == null) return;
    
    final existing = _themes.any((t) => 
      t.name.toLowerCase() == name.toLowerCase() && 
      t.userId == _userId
    );
    
    if (existing) {
      throw Exception('A theme with this name already exists!');
    }
    
    final themeId = 'custom_${const Uuid().v4()}';
    final theme = AppTheme(
      id: themeId,
      name: name,
      primaryColor: color,
      brightness: brightness,
      isCustom: true,
      userId: _userId,
    );
    
    try {
      await supabase.from('user_themes').insert(theme.toMap());
      _themes.add(theme);
      _currentTheme = theme;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Create custom theme error: $e');
    }
  }

  void setTheme(AppTheme theme) {
    _currentTheme = theme;
    notifyListeners();
  }
}

class FeedProvider extends ChangeNotifier {
  List<Post> _posts = [], _searchPostsResults = [];
  bool _isLoading = false, _isSearching = false;
  final supabase = Supabase.instance.client;
  String? _currentUserId;
  
  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  List<Post> get searchPostsResults => _searchPostsResults;
  bool get isSearching => _isSearching;

  void setCurrentUser(String userId) => _currentUserId = userId;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await supabase
          .from('posts')
          .select()
          .order('created_at', ascending: false);
      _posts = [for (var m in response) Post.fromMap(m)];
      if (_currentUserId != null) {
        final salutes = await supabase
            .from('post_salutes')
            .select('post_id')
            .eq('user_id', _currentUserId!);
        final salutePostIds = {for (var s in salutes) s['post_id'] as String};
        for (var post in _posts) post.userSaluted = salutePostIds.contains(post.id);
      }
    } catch (e) {
      debugPrint('❌ Load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFollowingPosts() async {
    if (_isLoading || _currentUserId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final following = await supabase
          .from('followers')
          .select('following_id')
          .eq('follower_id', _currentUserId!);
      
      final followingIds = following.map((f) => f['following_id'] as String).toList();
      
      if (followingIds.isEmpty) {
        _posts = [];
      } else {
        final response = await supabase
            .from('posts')
            .select()
            .inFilter('author', followingIds)
            .order('created_at', ascending: false);
        _posts = [for (var m in response) Post.fromMap(m)];
        
        final salutes = await supabase
            .from('post_salutes')
            .select('post_id')
            .eq('user_id', _currentUserId!);
        final salutePostIds = {for (var s in salutes) s['post_id'] as String};
        for (var post in _posts) post.userSaluted = salutePostIds.contains(post.id);
      }
    } catch (e) {
      debugPrint('❌ Load following posts error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserPosts(String username) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await supabase
          .from('posts')
          .select()
          .eq('author', username)
          .order('created_at', ascending: false);
      _posts = [for (var m in response) Post.fromMap(m)];
      if (_currentUserId != null) {
        final salutes = await supabase
            .from('post_salutes')
            .select('post_id')
            .eq('user_id', _currentUserId!);
        final salutePostIds = {for (var s in salutes) s['post_id'] as String};
        for (var post in _posts) post.userSaluted = salutePostIds.contains(post.id);
      }
    } catch (e) {
      debugPrint('❌ Load user posts error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchPosts(String query) async {
    _isSearching = true;
    if (query.trim().isEmpty) {
      _searchPostsResults = [];
    } else {
      try {
        final response = await supabase
            .from('posts')
            .select()
            .or('title.ilike.%$query%,content.ilike.%$query%')
            .order('created_at', ascending: false);
        _searchPostsResults = [for (var m in response) Post.fromMap(m)];
      } catch (e) {
        debugPrint('❌ Search posts error: $e');
        _searchPostsResults = [];
      }
    }
    _isSearching = false;
    notifyListeners();
  }

  Future<void> refresh() async => await load();

  void add(Post p) {
    _posts.insert(0, p);
    notifyListeners();
    supabase.from('posts').insert(p.toMap()).catchError((e) {
      debugPrint('❌ DB save error: $e');
      _posts.removeWhere((x) => x.id == p.id);
      notifyListeners();
    });
  }

  Future<void> salute(String id) async {
    try {
      final i = _posts.indexWhere((x) => x.id == id);
      if (i == -1 || _currentUserId == null) return;
      final post = _posts[i];
      final wasUserSaluted = post.userSaluted;
      post.salutes += wasUserSaluted ? -1 : 1;
      post.userSaluted = !wasUserSaluted;
      notifyListeners();
      try {
        if (wasUserSaluted) {
          await supabase
              .from('post_salutes')
              .delete()
              .eq('post_id', id)
              .eq('user_id', _currentUserId!);
          await supabase
              .from('posts')
              .update({'salutes': post.salutes}).eq('id', id);
        } else {
          await supabase
              .from('post_salutes')
              .insert({'post_id': id, 'user_id': _currentUserId!});
          await supabase
              .from('posts')
              .update({'salutes': post.salutes}).eq('id', id);
        }
      } catch (e) {
        post.salutes = wasUserSaluted ? post.salutes - 1 : post.salutes + 1;
        post.userSaluted = wasUserSaluted;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Salute error: $e');
    }
  }

  void delete(String id) {
    final i = _posts.indexWhere((x) => x.id == id);
    if (i == -1) return;
    _posts.removeAt(i);
    notifyListeners();
    supabase.from('posts').delete().eq('id', id).catchError((e) => debugPrint('❌ Delete error: $e'));
  }
}

class ChatProvider extends ChangeNotifier {
  final List<Message> _messages = [];
  bool _isLoading = false;
  String? _lastError;
  
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    final userMessage = Message(
      id: const Uuid().v4(),
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );
    
    _messages.add(userMessage);
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    
    try {
      final messageHistory = _messages.take(100).map((m) => m.toJson()).toList();
      final response = await ChatService.sendMessage(messageHistory, text.trim());
      
      final aiMessage = Message(
        id: const Uuid().v4(),
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
      );
      
      _messages.add(aiMessage);
    } catch (e) {
      debugPrint('❌ Chat error: $e');
      _lastError = e.toString();
      
      final errorMessage = Message(
        id: const Uuid().v4(),
        text: 'Sorry, I encountered an error. Please try again.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      _messages.add(errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void clearChat() {
    _messages.clear();
    _lastError = null;
    notifyListeners();
  }
}

class KnowledgeHubProvider extends ChangeNotifier {
  List<Profession> _professions = [];
  List<Profession> _filteredProfessions = [];
  bool _isSearching = false;
  
  List<Profession> get professions => _filteredProfessions;
  bool get isSearching => _isSearching;

  KnowledgeHubProvider() {
    _initializeProfessions();
  }

  void _initializeProfessions() {
    _professions = [
      Profession(
        id: 'sanitation_worker',
        name: 'Sanitation Worker',
        shortDescription: 'Guardians of public health who keep our cities clean and livable',
        whoTheyAre: 'The guardians of public health who wake up before dawn to keep our streets clean and our cities livable. They are the unsung heroes who ensure our communities remain hygienic and disease-free.',
        hardships: 'They work in extreme weather conditions, handling hazardous waste with minimal protective gear. Often subjected to social stigma and discrimination despite their crucial role.',
        howToShowRespect: 'Properly segregate waste at source. Make eye contact and greet them warmly. Provide water during hot days. Advocate for better safety equipment and fair wages.',
        tags: ['sanitation', 'health', 'essential', 'public service'],
        icon: Icons.cleaning_services,
      ),
      Profession(
        id: 'street_vendor',
        name: 'Street Vendor',
        shortDescription: 'Backbone of local economies bringing affordable goods to neighborhoods',
        whoTheyAre: 'The backbone of local economies and culture, bringing affordable goods, fresh food, and unique services directly to neighborhoods. They are small entrepreneurs who create their own opportunities despite systemic challenges.',
        hardships: 'Constant threat of eviction and harassment from authorities. Face weather extremes with minimal shelter. No social security or health benefits. Long working hours with low profit margins.',
        howToShowRespect: 'Acknowledge their contribution to local economy. Don\'t bargain excessively. Respect their designated spaces. Support policies for their legal recognition and protection.',
        tags: ['entrepreneur', 'local economy', 'informal sector', 'micro business'],
        icon: Icons.storefront,
      ),
      Profession(
        id: 'construction_worker',
        name: 'Construction Worker',
        shortDescription: 'Builders of our modern world transforming blueprints into reality',
        whoTheyAre: 'The builders of our modern world - from homes to highways, bridges to buildings. These skilled laborers transform blueprints into reality, often with their bare hands and sheer determination.',
        hardships: 'Work at great heights and dangerous conditions with minimal safety equipment. No job security - income depends on daily selection at labor markets. No health insurance despite high injury risk.',
        howToShowRespect: 'Ensure your contractor provides safety equipment and fair wages. Offer water during hot days. Don\'t treat construction sites as dumping grounds. Appreciate the skill involved - it\'s not "unskilled labor."',
        tags: ['construction', 'labor', 'skilled', 'infrastructure'],
        icon: Icons.construction,
      ),
      Profession(
        id: 'domestic_worker',
        name: 'Domestic Worker',
        shortDescription: 'Invisible workforce that keeps households running smoothly',
        whoTheyAre: 'The invisible workforce that keeps households running smoothly. From cooking and cleaning to childcare and eldercare, they provide essential services that enable others to pursue their careers and dreams.',
        hardships: 'Work in isolation with little legal protection. Often face verbal, emotional, and sometimes physical harm. Lack job security and denied basic amenities like proper meals or rest time.',
        howToShowRespect: 'Treat them as professionals, not servants. Provide fair wages, paid time off, and health insurance. Ensure safe working conditions. Respect their boundaries and personal time.',
        tags: ['domestic', 'care', 'household', 'support'],
        icon: Icons.home,
      ),
      Profession(
        id: 'delivery_personnel',
        name: 'Delivery Personnel',
        shortDescription: 'Lifeline of modern convenience delivering everything to your doorstep',
        whoTheyAre: 'The lifeline of modern convenience, delivering everything from food to packages. They navigate through traffic, weather, and tight deadlines to ensure we get what we need when we need it.',
        hardships: 'Risk accidents navigating chaotic traffic in all weather conditions. No fixed working hours or guaranteed income. Pay for vehicle maintenance and fuel from their own earnings.',
        howToShowRespect: 'Order during reasonable hours when possible. Be patient if delivery is delayed. Tip generously, especially in bad weather. Meet them at the door instead of making them wait.',
        tags: ['delivery', 'logistics', 'gig economy', 'service'],
        icon: Icons.delivery_dining,
      ),
      Profession(
        id: 'security_guard',
        name: 'Security Guard',
        shortDescription: 'Silent protectors ensuring safety and security',
        whoTheyAre: 'The silent protectors who stand watch while we sleep, work, and live our lives. They ensure our safety and security, often at the cost of their own comfort and family time.',
        hardships: 'Work 12-hour shifts, often standing throughout. Miss important family moments due to night shifts and holidays. Face health issues from irregular sleep patterns. Receive low wages despite high responsibility.',
        howToShowRespect: 'Greet them warmly when you pass by. Offer water or tea during extreme weather. Don\'t treat them as invisible. Advocate for better facilities like proper rest areas.',
        tags: ['security', 'protection', 'safety', 'service'],
        icon: Icons.security,
      ),
      Profession(
        id: 'agriculture_worker',
        name: 'Agriculture Worker',
        shortDescription: 'Cultivators who feed the nation through backbreaking labor',
        whoTheyAre: 'The backbone of our food security, working from dawn to dusk to cultivate crops and raise livestock. They feed the nation through backbreaking labor and deep connection to the land.',
        hardships: 'Exposed to harmful pesticides and extreme weather. No access to healthcare or insurance despite high injury risk. Face exploitation from middlemen and volatile market prices.',
        howToShowRespect: 'Buy directly from farmers when possible. Support fair trade products. Don\'t waste food - remember the effort that went into growing it. Advocate for better MSP and insurance coverage.',
        tags: ['agriculture', 'farming', 'food security', 'rural'],
        icon: Icons.agriculture,
      ),
      Profession(
        id: 'healthcare_support',
        name: 'Healthcare Support Staff',
        shortDescription: 'Essential support staff keeping healthcare facilities running',
        whoTheyAre: 'The essential support staff in hospitals and clinics - from ward boys and sanitation staff to pharmacy assistants. They keep healthcare facilities running smoothly behind the scenes.',
        hardships: 'Exposed to infections and hazardous medical waste. Work long hours with minimal protective equipment. Low wages despite working in life-critical environments. Emotional trauma from patient suffering.',
        howToShowRespect: 'Acknowledge their contribution to patient care. Provide proper safety equipment. Ensure fair wages and mental health support. Treat them with dignity, not as secondary staff.',
        tags: ['healthcare', 'support', 'hospital', 'essential'],
        icon: Icons.medical_services,
      ),
      Profession(
        id: 'rickshaw_puller',
        name: 'Rickshaw Puller',
        shortDescription: 'Human-powered transport providers navigating city streets',
        whoTheyAre: 'Human-powered transport providers who navigate city streets with strength and endurance, providing affordable mobility to millions in urban and rural areas.',
        hardships: 'Physical exhaustion from pulling heavy loads all day. Exposed to pollution and traffic dangers. No health insurance or social security. Income depends on daily earnings.',
        howToShowRespect: 'Pay fair fares without excessive bargaining. Offer help on steep slopes. Respect their physical limits. Support transition to e-rickshaws with subsidies.',
        tags: ['transport', 'manual labor', 'mobility', 'urban'],
        icon: Icons.directions_walk,
      ),
      Profession(
        id: 'taxi_driver',
        name: 'Taxi Driver',
        shortDescription: 'Navigators providing essential urban transportation services',
        whoTheyAre: 'Professional drivers who navigate complex city routes, providing essential transportation services and local knowledge to residents and visitors.',
        hardships: 'Long hours sitting causing health issues. Deal with difficult passengers and traffic stress. Rising fuel costs eating into earnings. Face competition from ride-sharing apps.',
        howToShowRespect: 'Be clear with directions and destinations. Don\'t slam doors. Pay promptly and tip for good service. Be respectful during fare negotiations.',
        tags: ['transport', 'driving', 'urban', 'service'],
        icon: Icons.local_taxi,
      ),
      Profession(
        id: 'auto_rickshaw_driver',
        name: 'Auto Rickshaw Driver',
        shortDescription: 'Three-wheeler operators providing last-mile connectivity',
        whoTheyAre: 'Three-wheeler operators who provide crucial last-mile connectivity in congested urban areas, mastering narrow lanes and heavy traffic.',
        hardships: 'Breathe exhaust fumes all day. Back pain from constant vibration. Pay high rental fees for vehicles. Face harassment from traffic police.',
        howToShowRespect: 'Don\'t bargain excessively for short distances. Be patient in traffic. Share rides when possible. Ensure they follow meter rates.',
        tags: ['transport', 'urban', 'auto', 'connectivity'],
        icon: Icons.electric_rickshaw,
      ),
      Profession(
        id: 'car_washer',
        name: 'Car Washer',
        shortDescription: 'Detailers keeping vehicles clean in all weather conditions',
        whoTheyAre: 'Detailers who keep vehicles spotless, working in all weather conditions to maintain the appearance and hygiene of cars.',
        hardships: 'Hands constantly in water causing skin problems. Work in extreme heat and cold. Chemical exposure without protection. Low pay per vehicle.',
        howToShowRespect: 'Tip for good work. Provide shade and water. Don\'t expect instant service during bad weather. Respect their time and effort.',
        tags: ['service', 'automotive', 'manual labor', 'outdoor'],
        icon: Icons.local_car_wash,
      ),
      Profession(
        id: 'house_painter',
        name: 'House Painter',
        shortDescription: 'Artists transforming spaces with color and precision',
        whoTheyAre: 'Skilled artisans who transform spaces with color and precision, working at heights to beautify homes and buildings.',
        hardships: 'Inhale paint fumes and dust daily. Risk falls from heights. Skin problems from chemical exposure. Irregular work based on season.',
        howToShowRespect: 'Pay fair wages for quality work. Provide proper safety equipment. Give adequate time for quality finishing. Clear payment terms.',
        tags: ['painting', 'construction', 'skill', 'artisan'],
        icon: Icons.format_paint,
      ),
      Profession(
        id: 'plumber',
        name: 'Plumber',
        shortDescription: 'Problem solvers ensuring clean water and sanitation',
        whoTheyAre: 'Essential service providers who ensure clean water supply and proper sanitation, solving complex piping issues in homes and buildings.',
        hardships: 'Work in cramped, unhygienic spaces. Emergency calls disrupt personal life. Exposure to contaminated water. Physically demanding work.',
        howToShowRespect: 'Pay promptly for emergency services. Respect their expertise. Provide clean working conditions. Don\'t negotiate during emergencies.',
        tags: ['maintenance', 'sanitation', 'technical', 'essential'],
        icon: Icons.plumbing,
      ),
      Profession(
        id: 'electrician',
        name: 'Electrician',
        shortDescription: 'Technicians keeping the lights on and power flowing',
        whoTheyAre: 'Technical experts who install and maintain electrical systems, ensuring safe and reliable power supply to homes and businesses.',
        hardships: 'Risk of electric shocks and burns. Work in dangerous conditions. Must stay updated with changing technology. On-call for emergencies.',
        howToShowRespect: 'Don\'t attempt DIY with electrical work. Pay fair rates for licensed work. Respect safety protocols. Provide timely payments.',
        tags: ['electrical', 'technical', 'safety', 'maintenance'],
        icon: Icons.electrical_services,
      ),
      Profession(
        id: 'cobbler',
        name: 'Cobbler',
        shortDescription: 'Craftspeople repairing footwear with traditional skills',
        whoTheyAre: 'Traditional craftspeople who repair and restore footwear, preserving shoes and saving resources through their skilled hands.',
        hardships: 'Diminishing demand due to cheap footwear. Work in poor lighting conditions. Inhale glue fumes and leather dust. Low income despite skill.',
        howToShowRespect: 'Repair instead of replacing shoes. Pay fair price for craftsmanship. Don\'t rush them. Appreciate their traditional skills.',
        tags: ['craft', 'repair', 'traditional', 'artisan'],
        icon: Icons.shopping_bag,
      ),
      Profession(
        id: 'tailor',
        name: 'Tailor',
        shortDescription: 'Designers creating perfect fits with fabric and thread',
        whoTheyAre: 'Skilled designers who transform fabric into perfectly fitted garments, combining creativity with precise technical skills.',
        hardships: 'Eye strain from detailed work. Back pain from long hours sitting. Competition from ready-made garments. Pressure for quick deliveries.',
        howToShowRespect: 'Give adequate time for quality work. Pay fitting charges promptly. Respect their design suggestions. Don\'t bargain excessively.',
        tags: ['fashion', 'craft', 'design', 'artisan'],
        icon: Icons.content_cut,
      ),
      Profession(
        id: 'dhobi',
        name: 'Dhobi (Laundry Worker)',
        shortDescription: 'Laundry experts keeping clothes clean and fresh',
        whoTheyAre: 'Traditional laundry experts who wash, dry, and iron clothes, providing essential services to households and establishments.',
        hardships: 'Hands constantly in water causing skin diseases. Back pain from heavy lifting. Work in extreme heat near boilers. Low margins.',
        howToShowRespect: 'Pay fair rates per piece. Don\'t give extremely dirty clothes regularly. Tip for good service. Provide timely pickup.',
        tags: ['laundry', 'service', 'traditional', 'household'],
        icon: Icons.local_laundry_service,
      ),
      Profession(
        id: 'barber',
        name: 'Barber',
        shortDescription: 'Grooming professionals boosting confidence daily',
        whoTheyAre: 'Grooming professionals who boost confidence through haircuts and styling, often serving as informal counselors to customers.',
        hardships: 'Long hours standing causing leg problems. Inhale hair and chemical particles. No health insurance.Competition from salons.',
        howToShowRespect: 'Tip for good service. Don\'t rush them. Respect their styling suggestions. Be a regular customer. Refer others.',
        tags: ['grooming', 'service', 'beauty', 'community'],
        icon: Icons.content_cut,
      ),
      Profession(
        id: 'gardener',
        name: 'Gardener',
        shortDescription: 'Green thumbs nurturing nature in urban spaces',
        whoTheyAre: 'Plant experts who nurture nature in urban spaces, creating green oases and maintaining landscapes with their botanical knowledge.',
        hardships: 'Work in extreme heat. Pesticide exposure. Back pain from constant bending. Seasonal employment insecurity. Low wages.',
        howToShowRespect: 'Provide protective gear. Pay fair wages. Offer water during hot days. Respect their plant knowledge. Give regular employment.',
        tags: ['gardening', 'landscaping', 'nature', 'outdoor'],
        icon: Icons.grass,
      ),
      Profession(
        id: 'waiter',
        name: 'Waiter',
        shortDescription: 'Service professionals ensuring dining experiences',
        whoTheyAre: 'Front-line service professionals who ensure pleasant dining experiences, balancing multiple tasks with patience and efficiency.',
        hardships: 'Long standing hours causing health issues. Deal with difficult customers. Low base salary dependent on tips. Work during holidays and weekends.',
        howToShowRespect: 'Tip generously for good service. Be patient during busy times. Speak politely. Complain respectfully if needed. Acknowledge their hard work.',
        tags: ['hospitality', 'service', 'food', 'customer service'],
        icon: Icons.restaurant,
      ),
      Profession(
        id: 'cook',
        name: 'Cook',
        shortDescription: 'Culinary artists creating flavors and nourishment',
        whoTheyAre: 'Culinary artists who create flavors and nourishment, working in hot kitchens to prepare meals that bring people together.',
        hardships: 'Work near hot stoves causing heat stress. Burn and cut injuries. Long hours during holidays. No recognition for creativity. Low wages.',
        howToShowRespect: 'Appreciate their cooking. Compliment good meals. Don\'t waste food. Respect their recipes. Pay fairly for catering services.',
        tags: ['cooking', 'food', 'culinary', 'hospitality'],
        icon: Icons.ramen_dining,
      ),
      Profession(
        id: 'dishwasher',
        name: 'Dishwasher',
        shortDescription: 'Essential workers keeping kitchens hygienic',
        whoTheyAre: 'Essential kitchen staff who maintain hygiene by washing dishes, utensils, and equipment, preventing food contamination.',
        hardships: 'Hands constantly in water causing skin issues. Inhale steam and chemical fumes. Lowest paid in kitchen hierarchy. No recognition.',
        howToShowRespect: 'Acknowledge their importance in food safety. Tip share from kitchen staff. Provide protective gloves. Respect their role.',
        tags: ['kitchen', 'hospitality', 'hygiene', 'support'],
        icon: Icons.water_drop,
      ),
      Profession(
        id: 'garbage_collector',
        name: 'Garbage Collector',
        shortDescription: 'Waste management workers maintaining urban hygiene',
        whoTheyAre: 'Essential waste management workers who maintain urban hygiene by collecting and disposing of garbage from homes and businesses.',
        hardships: 'Exposure to toxic waste and biohazards. Work in all weather conditions. Social stigma. Risk of injuries from sharp objects. Early morning shifts.',
        howToShowRespect: 'Segregate waste properly. Don\'t overfill bins. Wrap sharp objects safely. Greet them respectfully. Advocate for protective equipment.',
        tags: ['waste', 'sanitation', 'urban', 'essential'],
        icon: Icons.delete_sweep,
      ),
      Profession(
        id: 'beggar',
        name: 'Person Experiencing Homelessness',
        shortDescription: 'Individuals surviving without shelter or stable income',
        whoTheyAre: 'Individuals experiencing extreme poverty and homelessness, often due to circumstances beyond their control, trying to survive without shelter or stable income.',
        hardships: 'No shelter from weather extremes. Constant hunger and health issues. Social stigma and police harassment. No access to healthcare. Mental health challenges untreated.',
        howToShowRespect: 'Give food instead of money when possible. Donate to shelters. Volunteer at NGOs. Don\'t judge their situation. Acknowledge them as human beings.',
        tags: ['poverty', 'homelessness', 'social issue', 'humanity'],
        icon: Icons.sanitizer,
      ),
      Profession(
        id: 'begging_child',
        name: 'Child Laborer',
        shortDescription: 'Children forced to work instead of studying',
        whoTheyAre: 'Children forced into labor due to poverty, missing education and childhood while working in dangerous conditions to support their families.',
        hardships: 'No education or childhood. Physical and emotional abuse. Health hazards from adult work. Exploitation by employers. Psychological trauma. No future prospects.',
        howToShowRespect: 'Report child labor to authorities. Donate to education NGOs. Don\'t give money that encourages begging. Support midday meal programs. Create awareness.',
        tags: ['child rights', 'education', 'exploitation', 'human rights'],
        icon: Icons.child_care,
      ),
      Profession(
        id: 'rag_picker',
        name: 'Rag Picker',
        shortDescription: 'Waste pickers recycling materials from dumps',
        whoTheyAre: 'Informal waste pickers who recycle valuable materials from garbage dumps, contributing significantly to waste management while earning meager incomes.',
        hardships: 'Constant exposure to toxins and biohazards. No protective gear. Social ostracization. Health problems from hazardous waste. Exploitation by scrap dealers.',
        howToShowRespect: 'Donate usable items instead of trashing them. Support organizations that help ragpickers. Advocate for their recognition and rights. Treat them with dignity.',
        tags: ['waste', 'recycling', 'informal sector', 'environment'],
        icon: Icons.recycling,
      ),
      Profession(
        id: 'mechanic',
        name: 'Mechanic',
        shortDescription: 'Problem solvers keeping vehicles running smoothly',
        whoTheyAre: 'Skilled technicians who diagnose and repair vehicles, keeping transportation running smoothly with their mechanical expertise and problem-solving skills.',
        hardships: 'Exposure to oil, grease, and chemicals. Risk of injuries from tools. Constant bending causing back problems. No formal recognition of skills. Competition from authorized service centers.',
        howToShowRespect: 'Don\'t negotiate excessively. Pay for diagnosis time. Provide clear problem descriptions. Recommend them for good work. Trust their expertise.',
        tags: ['automotive', 'repair', 'technical', 'skill'],
        icon: Icons.build,
      ),
      Profession(
        id: 'carpenter',
        name: 'Carpenter',
        shortDescription: 'Woodworkers creating functional art from timber',
        whoTheyAre: 'Skilled woodworkers who transform timber into functional furniture and structures, combining traditional craftsmanship with modern design sensibilities.',
        hardships: 'Dust inhalation causing respiratory issues. Risk of cuts and injuries. Eye strain from detailed work. Competition from factory-made furniture. Undervalued craftsmanship.',
        howToShowRespect: 'Pay for craftsmanship, not just materials. Give adequate time for quality work. Don\'t compare with factory prices. Appreciate their design skills. Recommend their work.',
        tags: ['carpentry', 'woodwork', 'craft', 'artisan'],
        icon: Icons.carpenter,
      ),
      Profession(
        id: 'welder',
        name: 'Welder',
        shortDescription: 'Metal workers joining materials with precision',
        whoTheyAre: 'Metal workers who join materials using high heat, creating structures and products with precision and skill in various industries.',
        hardships: 'Exposure to intense light damaging eyes. Inhale toxic fumes. Risk of burns and injuries. No proper ventilation in workshops. Long-term respiratory issues.',
        howToShowRespect: 'Ensure proper safety equipment. Pay premium rates for quality welding. Don\'t rush critical joints. Provide adequate ventilation. Value their precision work.',
        tags: ['welding', 'metalwork', 'industrial', 'skilled'],
        icon: Icons.construction,
      ),
      Profession(
        id: 'mason',
        name: 'Mason',
        shortDescription: 'Masons building structures brick by brick',
        whoTheyAre: 'Traditional builders who construct structures brick by brick, creating durable walls and foundations with their knowledge of materials and techniques.',
        hardships: 'Heavy lifting causing musculoskeletal problems. Work at heights. Dust inhalation. Weather-dependent income. No job security. Undervalued traditional skills.',
        howToShowRespect: 'Pay fair wages for skilled work. Provide proper scaffolding and safety gear. Respect their material knowledge. Don\'t rush quality construction. Ensure timely payments.',
        tags: ['construction', 'masonry', 'traditional', 'building'],
        icon: Icons.foundation,
      ),
      Profession(
        id: 'housemaid',
        name: 'Housemaid',
        shortDescription: 'Domestic helpers managing household chores',
        whoTheyAre: 'Domestic helpers who manage household chores, cooking, cleaning, and childcare, enabling families to maintain work-life balance.',
        hardships: 'Long working hours with minimal rest. Low wages despite multiple responsibilities. No job security or benefits. Sometimes face exploitation and abuse. Live-in maids have no personal space.',
        howToShowRespect: 'Provide fair salary and time off. Respect their personal space and time. Don\'t overburden with excessive work. Give festival bonuses. Treat them as family members.',
        tags: ['domestic', 'household', 'support', 'care'],
        icon: Icons.home_work,
      ),
      Profession(
        id: 'call_center',
        name: 'Call Center Agent',
        shortDescription: 'Customer service professionals handling queries',
        whoTheyAre: 'Customer service professionals who handle queries and complaints, maintaining brand reputation through patience and communication skills.',
        hardships: 'High stress from angry customers. Night shifts disrupting health. Strict call targets causing anxiety. No job satisfaction. Voice problems from continuous talking.',
        howToShowRespect: 'Be patient and polite when calling. Understand they follow scripts. Don\'t shout or abuse. Give positive feedback. Respect their time constraints.',
        tags: ['customer service', 'BPO', 'communication', 'support'],
        icon: Icons.phone_in_talk,
      ),
      Profession(
        id: 'hotel_staff',
        name: 'Hotel Staff',
        shortDescription: 'Hospitality professionals ensuring guest comfort',
        whoTheyAre: 'Hospitality professionals across departments ensuring guest comfort, from housekeeping to room service and concierge.',
        hardships: 'Long hours during peak seasons. Deal with difficult guests. Low base salary dependent on tips. Work when others holiday. High stress to maintain standards.',
        howToShowRespect: 'Tip generously for good service. Be respectful in interactions. Don\'t damage hotel property. Appreciate their effort. Give positive reviews mentioning staff.',
        tags: ['hospitality', 'service', 'tourism', 'guest relations'],
        icon: Icons.hotel,
      ),
      Profession(
        id: 'mall_staff',
        name: 'Mall Staff',
        shortDescription: 'Retail support maintaining shopping environments',
        whoTheyAre: 'Retail support staff maintaining shopping environments, from cleaners to security and customer service personnel.',
        hardships: 'Long standing hours. Deal with crowds and difficult shoppers. Low wages in expensive urban areas. Work evenings, weekends and holidays. No job security.',
        howToShowRespect: 'Be polite to all staff. Don\'t litter. Follow mall rules. Acknowledge their help. Be patient during busy times. Don\'t treat them as inferior.',
        tags: ['retail', 'service', 'shopping', 'support'],
        icon: Icons.shopping_bag,
      ),
      Profession(
        id: 'bus_conductor',
        name: 'Bus Conductor',
        shortDescription: 'Ticketing and passenger management professionals',
        whoTheyAre: 'Public transport staff managing ticketing, passenger safety, and smooth operations of bus services across routes.',
        hardships: 'Handle cash and difficult passengers. Work in crowded buses. Risk of accidents. No fixed working hours. Deal with traffic stress. Low salaries.',
        howToShowRespect: 'Buy tickets honestly. Don\'t argue over fares. Be polite during rush hour. Follow their instructions. Report issues respectfully. Acknowledge their service.',
        tags: ['transport', 'public service', 'ticketing', 'customer service'],
        icon: Icons.directions_bus,
      ),
      Profession(
        id: 'truck_driver',
        name: 'Truck Driver',
        shortDescription: 'Long-haul transporters keeping supply chains moving',
        whoTheyAre: 'Long-haul transporters who keep supply chains moving, delivering goods across cities and states under tight schedules.',
        hardships: 'Away from family for weeks. Sleep deprivation from long drives. Risk of accidents. Health issues from sitting. No proper restrooms on highways. Exploitation by brokers.',
        howToShowRespect: 'Don\'t overload trucks. Allow them rest stops. Pay promptly for services. Respect their delivery timelines. Advocate for better highway facilities.',
        tags: ['transport', 'logistics', 'supply chain', 'long haul'],
        icon: Icons.local_shipping,
      ),
      Profession(
        id: 'coolie',
        name: 'Coolie (Porter)',
        shortDescription: 'Porters carrying luggage at transport hubs',
        whoTheyAre: 'Porters who carry luggage at railway stations and bus terminals, providing essential service to travelers with heavy baggage.',
        hardships: 'Carry heavy loads causing back problems. Work in all weather. No fixed income - dependent on customers. Competition from trolleys. No social security.',
        howToShowRespect: 'Pay fair wages for their labor. Don\'t overload them. Be polite. Tip generously for heavy loads. Use their service instead of trolleys when possible.',
        tags: ['porter', 'labor', 'transport', 'manual work'],
        icon: Icons.backpack,
      ),
      Profession(
        id: 'newspaper_vendor',
        name: 'Newspaper Vendor',
        shortDescription: 'Early morning distributors ensuring daily news delivery',
        whoTheyAre: 'Early morning distributors who ensure daily newspapers reach homes and stands before dawn, regardless of weather conditions.',
        hardships: 'Wake up extremely early daily. Work in darkness and all weather. Low commission per paper. Dependent on timely delivery. No holidays. Physical strain from distribution.',
        howToShowRespect: 'Pay subscription on time. Tip during festivals. Be understanding of occasional delays. Don\'t cancel subscription over minor issues. Acknowledge their reliability.',
        tags: ['media', 'distribution', 'early morning', 'service'],
        icon: Icons.article,
      ),
      Profession(
        id: 'milkman',
        name: 'Milkman',
        shortDescription: 'Dairy distributors delivering fresh milk daily',
        whoTheyAre: 'Dairy distributors who deliver fresh milk daily before sunrise, ensuring households have essential dairy products.',
        hardships: 'Extremely early morning routine. Work 365 days a year - no holidays. Spoilage risk in hot weather. Low margins. Physical strain from carrying heavy cans.',
        howToShowRespect: 'Pay monthly bills promptly. Return empty bottles carefully. Tip during festivals. Inform in advance for vacations. Don\'t argue over price fluctuations.',
        tags: ['dairy', 'delivery', 'essential', 'daily service'],
        icon: Icons.water,
      ),
      Profession(
        id: 'dhobi',
        name: 'Laundry Worker (Dhobi)',
        shortDescription: 'Traditional laundry experts washing and pressing clothes',
        whoTheyAre: 'Traditional laundry experts who wash, dry, and press clothes by hand or basic machines, providing affordable laundry services.',
        hardships: 'Hands constantly in water causing skin diseases. Extreme heat near irons and boilers. Back pain from heavy wet clothes. Low income per piece. No health insurance.',
        howToShowRespect: 'Pay fair rates per piece. Don\'t give extremely dirty clothes regularly. Tip for good service. Provide timely pickup. Don\'t rush quality work.',
        tags: ['laundry', 'traditional', 'service', 'household'],
        icon: Icons.iron,
      ),
      Profession(
        id: 'peon',
        name: 'Office Peon',
        shortDescription: 'Office support staff managing essential tasks',
        whoTheyAre: 'Office support staff who manage essential tasks like file movement, serving tea, maintaining cleanliness, and assisting all departments.',
        hardships: 'Lowest paid in office hierarchy. Treated as invisible by many. No career growth. Physically demanding running around. No recognition for contributions. No skill development.',
        howToShowRespect: 'Greet them warmly. Learn their name. Acknowledge their help. Include them in office celebrations. Don\'t shout or demean. Tip during festivals.',
        tags: ['office', 'support', 'administration', 'service'],
        icon: Icons.badge,
      ),
      Profession(
        id: 'sweeper',
        name: 'Sweeper',
        shortDescription: 'Cleanliness workers maintaining public spaces',
        whoTheyAre: 'Workers who maintain cleanliness of public spaces like streets, parks, and buildings, often working early morning or late night shifts.',
        hardships: 'Social stigma associated with work. Low wages. Exposure to dust and pollution. No protective equipment. Early morning or late night shifts affecting health.',
        howToShowRespect: 'Don\'t litter - respect their work. Greet them when you see them. Advocate for proper equipment. Support their children\'s education. Treat with dignity.',
        tags: ['cleaning', 'public service', 'sanitation', 'dignity'],
        icon: Icons.cleaning_services,
      ),
      Profession(
        id: 'porters',
        name: 'Hospital Porter',
        shortDescription: 'Medical facility support moving patients and supplies',
        whoTheyAre: 'Essential support staff in hospitals who move patients, deliver supplies, and ensure smooth movement within medical facilities.',
        hardships: 'Risk of infections. Physical strain from moving patients. Witness trauma and death regularly. Low wages despite critical role. No emotional support.',
        howToShowRespect: 'Acknowledge their role in patient care. Be cooperative during transfers. Don\'t treat them as unimportant. Support mental health initiatives. Tip for extra help.',
        tags: ['healthcare', 'support', 'hospital', 'patient care'],
        icon: Icons.local_hospital,
      ),
      Profession(
        id: 'janitor',
        name: 'Janitor',
        shortDescription: 'Building maintenance staff ensuring clean environments',
        whoTheyAre: 'Building maintenance staff who ensure clean environments in schools, offices, and public buildings, working after hours.',
        hardships: 'Work after hours when buildings empty. Exposure to cleaning chemicals. Deal with unpleasant waste. Invisible to building users. Low wages. No health benefits.',
        howToShowRespect: 'Acknowledge their presence. Don\'t make extra mess intentionally. Use bins properly. Tip during festivals. Advocate for their benefits.',
        tags: ['cleaning', 'maintenance', 'facilities', 'support'],
        icon: Icons.apartment,
      ),
      Profession(
        id: 'telecaller',
        name: 'Telecaller',
        shortDescription: 'Phone-based sales and support professionals',
        whoTheyAre: 'Professionals who handle phone-based sales, support, and surveys, dealing with hundreds of calls daily with patience and persuasion.',
        hardships: 'High rejection rates affecting morale. Voice strain. Stress from targets. Night shifts disrupting health. Abusive calls affecting mental health. Low basic salary.',
        howToShowRespect: 'Be polite even if not interested. Don\'t hang up abruptly. Give feedback if they\'re good. Understand they have targets. Don\'t abuse for marketing calls.',
        tags: ['sales', 'customer service', 'telemarketing', 'communication'],
        icon: Icons.phone_android,
      ),
      Profession(
        id: 'data_entry',
        name: 'Data Entry Operator',
        shortDescription: 'Computer operators digitizing information accurately',
        whoTheyAre: 'Computer operators who digitize information accurately, spending long hours typing and verifying data with high concentration.',
        hardships: 'Eye strain from screens. Carpal tunnel syndrome. Back and neck pain. Monotonous work affecting mental health. Low wages. No career growth.',
        howToShowRespect: 'Provide ergonomic chairs. Allow regular breaks. Don\'t pressure for unrealistic targets. Acknowledge accuracy. Pay fair wages for skilled typing.',
        tags: ['computer', 'data', 'office', 'clerical'],
        icon: Icons.keyboard,
      ),
      Profession(
        id: 'security',
        name: 'Private Security Guard',
        shortDescription: 'Property protection personnel ensuring safety',
        whoTheyAre: 'Security personnel who protect residential complexes, offices, and commercial establishments, working long shifts to ensure safety.',
        hardships: 'Boredom from monotonous watching. Risk of confrontation. Work night shifts affecting health. Low pay despite responsibility. No proper weapons or training.',
        howToShowRespect: 'Greet them daily. Offer tea/water. Don\'t treat them as furniture. Respect their instructions. Tip during festivals. Advocate for better equipment.',
        tags: ['security', 'safety', 'property', 'protection'],
        icon: Icons.security,
      ),
      Profession(
        id: 'lift_operator',
        name: 'Lift Operator',
        shortDescription: 'Elevator operators managing vertical transport',
        whoTheyAre: 'Operators who manage elevators in high-rise buildings, assisting residents and ensuring safe vertical transport throughout the day.',
        hardships: 'Confined space all day. Repetitive work causing boredom. Must stay alert for safety. No bathroom breaks during long shifts. Low wages. No skill development.',
        howToShowRespect: 'Greet them politely. Don\'t overcrowd lifts. Be patient during peak hours. Don\'t press buttons randomly. Tip during festivals.',
        tags: ['building', 'service', 'vertical transport', 'assistance'],
        icon: Icons.elevator,
      ),
      Profession(
        id: 'parking_attendant',
        name: 'Parking Attendant',
        shortDescription: 'Vehicle parking managers organizing spaces',
        whoTheyAre: 'Parking managers who organize vehicle spaces, guide drivers, and ensure efficient use of limited parking areas.',
        hardships: 'Work in polluted underground areas. Deal with angry drivers. No shade from sun or rain. Low wages. No job security. Risk of accidents.',
        howToShowRespect: 'Follow their instructions. Don\'t argue over parking rules. Tip for good spots. Don\'t honk unnecessarily. Be patient during busy times.',
        tags: ['parking', 'vehicle', 'management', 'outdoor'],
        icon: Icons.local_parking,
      ),
      Profession(
        id: 'street_cleaner',
        name: 'Street Cleaner',
        shortDescription: 'Urban sanitation workers maintaining public cleanliness',
        whoTheyAre: 'Urban sanitation workers who maintain public cleanliness by sweeping streets, removing litter, and ensuring clean public spaces.',
        hardships: 'Start work very early morning. Breathe vehicle pollution. Social stigma. Low wages. No protective equipment. Work in all weather conditions.',
        howToShowRespect: 'Don\'t litter. Use bins properly. Greet them when you see them. Advocate for better equipment. Support their rights. Treat with dignity.',
        tags: ['sanitation', 'urban', 'public service', 'cleanliness'],
        icon: Icons.streetview,
      ),
      Profession(
        id: 'public_toilet_attendant',
        name: 'Public Toilet Attendant',
        shortDescription: 'Sanitation workers maintaining public facilities',
        whoTheyAre: 'Sanitation workers who maintain public toilet facilities, ensuring cleanliness and availability of essential hygiene amenities.',
        hardships: 'Constant exposure to foul smells and germs. Social stigma. Low wages. Work without proper cleaning equipment. Health risks from bacteria and viruses.',
        howToShowRespect: 'Keep facilities clean after use. Pay user fees promptly. Don\'t vandalize. Acknowledge their work. Advocate for better working conditions.',
        tags: ['sanitation', 'public facilities', 'maintenance', 'hygiene'],
        icon: Icons.wc,
      ),
      Profession(
        id: 'cable_tv',
        name: 'Cable TV Technician',
        shortDescription: 'Entertainment service installers and repairers',
        whoTheyAre: 'Technicians who install and repair cable TV and internet connections, climbing poles and crawling through spaces to ensure connectivity.',
        hardships: 'Climb poles in dangerous conditions. Work in cramped ceiling spaces. Emergency calls at odd hours. Low per-installation pay. Competition from streaming services.',
        howToShowRespect: 'Be available for appointments. Don\'t complain about minor signal issues. Pay service charges promptly. Tip for quick service. Recommend good technicians.',
        tags: ['technology', 'entertainment', 'service', 'installation'],
        icon: Icons.connected_tv,
      ),
      Profession(
        id: 'water_tanker',
        name: 'Water Tanker Driver',
        shortDescription: 'Emergency water suppliers for water-scarce areas',
        whoTheyAre: 'Drivers who supply emergency water to water-scarce areas, navigating narrow lanes to deliver essential water supplies.',
        hardships: 'Drive heavy vehicles in difficult areas. Deal with water scarcity affecting many. Early morning and late night deliveries. Low margins. Risk of accidents on narrow roads.',
        howToShowRespect: 'Be ready when they arrive. Don\'t waste water. Pay promptly. Tip for timely delivery. Don\'t hoard water unnecessarily. Coordinate with neighbors.',
        tags: ['water', 'essential', 'delivery', 'emergency service'],
        icon: Icons.water,
      ),
      Profession(
        id: 'internet',
        name: 'Internet Technician',
        shortDescription: 'Connectivity experts ensuring digital access',
        whoTheyAre: 'Technicians who ensure digital connectivity by installing and maintaining internet infrastructure, climbing towers and laying cables.',
        hardships: 'Work at heights on towers. Exposure to radiation risks. Emergency repairs in bad weather. On-call 24/7. Low pay despite technical skills. No recognition.',
        howToShowRespect: 'Be patient during outages. Don\'t complain about minor speed issues. Provide easy access to equipment. Tip for emergency repairs. Acknowledge their technical skills.',
        tags: ['technology', 'internet', 'connectivity', 'digital'],
        icon: Icons.wifi,
      ),
      Profession(
        id: 'mobile_repair',
        name: 'Mobile Repair Technician',
        shortDescription: 'Gadget doctors fixing smartphones and tablets',
        whoTheyAre: 'Gadget doctors who fix smartphones and tablets, requiring precision and up-to-date knowledge of rapidly changing technology.',
        hardships: 'Eye strain from tiny components. Constant learning for new models. Low margins on repairs. Competition from authorized centers. Customer complaints for complex issues.',
        howToShowRespect: 'Don\'t expect instant repairs. Pay for diagnostic time. Backup data before repair. Don\'t negotiate excessively. Recommend them for good work.',
        tags: ['technology', 'repair', 'mobile', 'electronics'],
        icon: Icons.phone_iphone,
      ),
      Profession(
        id: 'press_wala',
        name: 'Presswala (Ironing Service)',
        shortDescription: 'Clothing pressers providing crisp garments',
        whoTheyAre: 'Ironing service providers who press clothes to perfection, working with hot irons for long hours to provide crisp garments.',
        hardships: 'Extreme heat from irons causing burns. Back pain from standing. Inhale steam and spray fumes. Low income per piece. Eye strain for detailing.',
        howToShowRespect: 'Pay fair rates per piece. Bring clothes on time. Don\'t bring extremely wrinkled clothes regularly. Tip for good finishing. Recommend their service.',
        tags: ['laundry', 'service', 'clothing', 'household'],
        icon: Icons.iron,
      ),
      Profession(
        id: 'cobbler',
        name: 'Shoe Repair Artisan',
        shortDescription: 'Footwear restoration experts extending shoe life',
        whoTheyAre: 'Artisans who repair and restore footwear, extending the life of shoes through skilled craftsmanship and traditional techniques.',
        hardships: 'Diminishing demand due to cheap shoes. Work in poor lighting. Inhale glue and leather dust. Low income despite skill. No formal training recognition.',
        howToShowRespect: 'Repair instead of replacing. Pay for skill not just material. Don\'t rush quality work. Appreciate their craft. Recommend them for good work.',
        tags: ['repair', 'craft', 'footwear', 'traditional'],
        icon: Icons.shopping_bag,
      ),
      Profession(
        id: 'key_maker',
        name: 'Key Maker',
        shortDescription: 'Locksmiths providing security solutions',
        whoTheyAre: 'Locksmiths who craft keys and repair locks, providing security solutions with precision and trustworthiness.',
        hardships: 'Fine work causing eye strain. Low margins. Competition from hardware stores. Emergency calls at odd hours. No formal recognition of skill.',
        howToShowRespect: 'Don\'t lose keys frequently. Pay for emergency service. Trust their expertise. Recommend for good work. Don\'t negotiate for precision work.',
        tags: ['security', 'locksmith', 'craft', 'precision'],
        icon: Icons.key,
      ),
      Profession(
        id: 'grocery_delivery',
        name: 'Grocery Delivery Person',
        shortDescription: 'Essential shoppers delivering daily necessities',
        whoTheyAre: 'Shoppers who deliver daily necessities, navigating stores and traffic to ensure households have essential groceries.',
        hardships: 'Heavy lifting of grocery bags. Shop and deliver in traffic. Deal with out-of-stock items and customer frustration. Low margins. No health insurance.',
        howToShowRespect: 'Tip generously. Be flexible with substitutions. Provide clear delivery instructions. Don\'t cancel orders last minute. Acknowledge their effort.',
        tags: ['delivery', 'grocery', 'essential', 'shopping'],
        icon: Icons.shopping_cart,
      ),
      Profession(
        id: 'florist',
        name: 'Florist',
        shortDescription: 'Flower arrangers creating beauty for celebrations',
        whoTheyAre: 'Artists who arrange flowers for celebrations and daily beauty, working early mornings to provide fresh blooms.',
        hardships: 'Start work before dawn at flower markets. Deal with perishable inventory. Allergies from constant flower handling. Low margins. Competition from online sellers.',
        howToShowRespect: 'Pay for arrangement skill. Place orders in advance. Don\'t haggle over artistic work. Recommend for events. Appreciate their creativity.',
        tags: ['flowers', 'art', 'celebrations', 'creativity'],
        icon: Icons.local_florist,
      ),
      Profession(
        id: 'pan_wala',
        name: 'Pan Shop Owner',
        shortDescription: 'Betel leaf vendors providing traditional refreshments',
        whoTheyAre: 'Vendors who prepare and sell traditional betel leaf preparations, often serving as neighborhood gathering spots.',
        hardships: 'Long hours at small stalls. Health issues from tobacco exposure. Low margins. Police harassment. Competition from modern shops.',
        howToShowRespect: 'Be a regular customer. Pay promptly. Don\'t bargain excessively. Respect their space. Acknowledge their role in community.',
        tags: ['traditional', 'betel', 'vendor', 'community'],
        icon: Icons.store,
      ),
      Profession(
        id: 'chai_wala',
        name: 'Tea Vendor',
        shortDescription: 'Tea brewers fueling daily life with chai',
        whoTheyAre: 'Makers of India\'s favorite beverage, brewing tea at street corners and stalls, fueling daily life with their chai.',
        hardships: 'Stand for long hours. Burn injuries from hot tea. Inhale smoke from stoves. Low margins per cup. Competition from cafes.',
        howToShowRespect: 'Pay fairly per cup. Don\'t expect premium service at street prices. Be a regular. Acknowledge their brewing skill. Tip for extra service.',
        tags: ['tea', 'beverage', 'street', 'traditional'],
        icon: Icons.coffee,
      ),
      Profession(
        id: 'juice_wala',
        name: 'Fresh Juice Vendor',
        shortDescription: 'Beverage makers providing fresh fruit juices',
        whoTheyAre: 'Vendors who provide fresh fruit juices, cutting and squeezing fruits daily for healthy beverages.',
        hardships: 'Early morning market visits. Hand strain from squeezing. Fruit spoilage losses. Competition from packaged juices. Low margins.',
        howToShowRespect: 'Pay for fresh juice premium. Don\'t bargain over health. Tip for hygiene. Be patient during rush. Recommend for quality.',
        tags: ['juice', 'beverage', 'healthy', 'fresh'],
        icon: Icons.water_drop,
      ),
      Profession(
        id: 'fruit_vendor',
        name: 'Fruit Vendor',
        shortDescription: 'Fresh fruit sellers providing healthy options',
        whoTheyAre: 'Sellers who provide fresh fruits, visiting wholesale markets early morning to bring quality produce to neighborhoods.',
        hardships: 'Early morning wholesale market visits. Fruit spoilage losses. Competition from supermarkets. Low margins. Physical strain from loading.',
        howToShowRespect: 'Buy regularly for freshness. Don\'t squeeze and damage fruits. Pay fair prices. Tip for good selection. Recommend for quality produce.',
        tags: ['fruit', 'healthy', 'fresh', 'vendor'],
        icon: Icons.apple,
      ),
      Profession(
        id: 'vegetable_vendor',
        name: 'Vegetable Vendor',
        shortDescription: 'Green grocers providing daily vegetables',
        whoTheyAre: 'Green grocers who provide daily fresh vegetables, bridging the gap between farmers and urban consumers.',
        hardships: 'Early morning market visits. Vegetable perishability. Price fluctuations. Competition from organized retail. Physical strain.',
        howToShowRespect: 'Buy daily for freshness. Don\'t waste their time selecting. Pay market rates. Tip for cleaning/processing. Recommend for fresh stock.',
        tags: ['vegetables', 'fresh', 'daily', 'vendor'],
        icon: Icons.grass,
      ),
      Profession(
        id: 'fish_monger',
        name: 'Fish Seller',
        shortDescription: 'Seafood vendors providing fresh catch',
        whoTheyAre: 'Vendors who provide fresh fish and seafood, often waking before dawn to get the best catch from fishing harbors.',
        hardships: 'Extremely early harbor visits. Strong odors affecting social life. Ice costs for preservation. Perishability losses. Competition from supermarkets.',
        howToShowRespect: 'Pay for freshness premium. Don\'t bargain excessively. Buy regularly. Tip for cleaning. Recommend for fresh catch.',
        tags: ['seafood', 'fresh', 'early morning', 'perishable'],
        icon: Icons.water,
      ),
      Profession(
        id: 'egg_vendor',
        name: 'Egg Seller',
        shortDescription: 'Poultry product distributors providing protein',
        whoTheyAre: 'Vendors who distribute eggs and poultry products, providing essential protein sources to neighborhoods.',
        hardships: 'Careful handling to prevent breakage. Perishability concerns. Low margins per egg. Competition from stores. Physical strain from cartons.',
        howToShowRespect: 'Buy regularly for freshness. Handle cartons carefully. Pay promptly. Don\'t complain about minor price changes. Tip for delivery.',
        tags: ['poultry', 'protein', 'daily', 'essential'],
        icon: Icons.egg,
      ),
      Profession(
        id: 'baker',
        name: 'Baker',
        shortDescription: 'Bread makers creating fresh baked goods',
        whoTheyAre: 'Bread makers who create fresh baked goods, working through early morning hours to provide fresh bread and snacks.',
        hardships: 'Work through night for morning freshness. Extreme oven heat. Flour dust causing respiratory issues. Competition from branded bakeries. Low margins.',
        howToShowRespect: 'Buy daily for freshness. Pay for quality ingredients. Don\'t compare with packaged bread. Tip for custom orders. Recommend for freshness.',
        tags: ['baking', 'fresh', 'early morning', 'food'],
        icon: Icons.bakery_dining,
      ),
      Profession(
        id: 'sweeper',
        name: 'Sweeper',
        shortDescription: 'Street sweepers maintaining urban cleanliness',
        whoTheyAre: 'Workers who sweep streets and public areas, maintaining urban cleanliness despite social stigma and low pay.',
        hardships: 'Social stigma. Low wages. Exposure to dust and pollution. No protective gear. Early morning work. No job security.',
        howToShowRespect: 'Don\'t litter. Use bins. Greet them respectfully. Advocate for protective equipment. Support their children\'s education. Treat with dignity.',
        tags: ['sanitation', 'public service', 'urban', 'cleanliness'],
        icon: Icons.cleaning_services,
      ),
      Profession(
        id: 'waitstaff',
        name: 'Waitstaff',
        shortDescription: 'Restaurant servers ensuring dining experiences',
        whoTheyAre: 'Servers in restaurants who ensure pleasant dining experiences, managing orders, service, and customer satisfaction.',
        hardships: 'Long standing hours. Deal with difficult customers. Low base pay dependent on tips. Work holidays and weekends. High stress during rush.',
        howToShowRespect: 'Tip generously. Be polite. Be patient during busy times. Compliment good service. Don\'t blame them for kitchen mistakes.',
        tags: ['hospitality', 'service', 'food', 'restaurant'],
        icon: Icons.restaurant,
      ),
      Profession(
        id: 'kitchen_helper',
        name: 'Kitchen Helper',
        shortDescription: 'Kitchen support staff assisting chefs',
        whoTheyAre: 'Support staff in kitchens who assist chefs with prep, cleaning, and basic cooking tasks.',
        hardships: 'Lowest paid in kitchen. No recognition. Extreme heat and pressure. Burn and cut risks. Long hours. No skill development opportunities.',
        howToShowRespect: 'Acknowledge their role in meal preparation. Share tips from kitchen pool. Provide protective gear. Respect their work. Give opportunities to learn.',
        tags: ['kitchen', 'hospitality', 'support', 'food'],
        icon: Icons.soup_kitchen,
      ),
      Profession(
        id: 'dabbawala',
        name: 'Dabbawala',
        shortDescription: 'Lunch box delivery experts ensuring timely meals',
        whoTheyAre: 'Lunch box delivery experts in cities like Mumbai, ensuring timely delivery of home-cooked meals to offices.',
        hardships: 'Extreme time pressure. Heavy tiffin boxes. Train travel in rush hour. Work in all weather. Low margins per box. No error margin allowed.',
        howToShowRespect: 'Pay on time. Don\'t complain about minor delays. Tip for consistent service. Appreciate their precision. Don\'t overload boxes.',
        tags: ['delivery', 'food', 'logistics', 'traditional'],
        icon: Icons.lunch_dining,
      ),
      Profession(
        id: 'dispenser',
        name: 'Pharmacy Assistant',
        shortDescription: 'Medical shop assistants dispensing medicines',
        whoTheyAre: 'Assistants in pharmacies who dispense medicines, manage inventory, and help customers with basic medical queries.',
        hardships: 'Long hours standing. Deal with anxious customers. No formal pharmacy training. Low wages. Responsibility for wrong dispensing. No recognition.',
        howToShowRespect: 'Be patient while they check prescriptions. Don\'t pressure for medicines without prescription. Tip for home delivery. Acknowledge their knowledge.',
        tags: ['pharmacy', 'healthcare', 'medicines', 'retail'],
        icon: Icons.medication,
      ),
      Profession(
        id: 'typist',
        name: 'Typist',
        shortDescription: 'Document preparation experts typing accurately',
        whoTheyAre: 'Document preparation experts who type accurately and fast, often in government offices and courts.',
        hardships: 'Eye strain. Carpal tunnel syndrome. No job security. Competition from computers. Low pay. No benefits. Monotonous work.',
        howToShowRespect: 'Pay per page fairly. Give clear instructions. Don\'t rush quality work. Appreciate accuracy. Provide regular work.',
        tags: ['typing', 'office', 'clerical', 'documentation'],
        icon: Icons.keyboard,
      ),
    ];
    _filteredProfessions = _professions;
  }

  void searchProfessions(String query) {
    if (query.isEmpty) {
      _filteredProfessions = _professions;
    } else {
      _filteredProfessions = _professions
          .where((profession) => 
              profession.name.toLowerCase().contains(query.toLowerCase()) ||
              profession.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase())))
          .toList();
    }
    _isSearching = false;
    notifyListeners();
  }

  void clearSearch() {
    _filteredProfessions = _professions;
    _isSearching = false;
    notifyListeners();
  }

  Profession? getProfessionById(String id) {
    try {
      return _professions.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}

// ── SERVICES ──────────────────────────────────────────────────────────────────
class ChatService {
  static Future<String> sendMessage(List<Map<String, dynamic>> history, String newMessage) async {
    final url = Uri.parse('$geminiApiUrl?key=$geminiApiKey');
    
    final contents = [...history];
    contents.last['parts'] = [{'text': newMessage}];
    
    final body = {
      "contents": contents,
      "safetySettings": [
        {
          "category": "HARM_CATEGORY_HARASSMENT",
          "threshold": "BLOCK_MEDIUM_AND_ABOVE"
        },
        {
          "category": "HARM_CATEGORY_HATE_SPEECH",
          "threshold": "BLOCK_MEDIUM_AND_ABOVE"
        },
        {
          "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
          "threshold": "BLOCK_MEDIUM_AND_ABOVE"
        },
        {
          "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
          "threshold": "BLOCK_MEDIUM_AND_ABOVE"
        }
      ],
      "generationConfig": {
        "temperature": 0.7,
        "topK": 40,
        "topP": 0.95,
        "maxOutputTokens": 1024,
      }
    };
    
    try {
      debugPrint('🤖 Sending request to Gemini API with ${history.length} messages of context...');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );
      
      debugPrint('🤖 Response Status: ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('🤖 Response Body: ${response.body}');
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['error'] != null) {
          throw Exception('API Error: ${data['error']['message']}');
        }
        
        if (data['candidates'] != null && 
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          final text = data['candidates'][0]['content']['parts'][0]['text']?.trim();
          if (text != null && text.isNotEmpty) {
            return text;
          }
        }
        
        if (data['candidates'] != null && 
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['finishReason'] != null) {
          final reason = data['candidates'][0]['finishReason'];
          if (reason == 'SAFETY') {
            return "I can't respond to that due to safety policies. Try asking something else!";
          }
        }
        
        return 'I received a response but couldn\'t understand it. Please try rephrasing.';
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Chat Service Error: $e');
      rethrow;
    }
  }
}

// ── WIDGETS ───────────────────────────────────────────────────────────────────
class PostCard extends StatefulWidget {
  final Post post;
  final String currentUsername;
  final VoidCallback onSalute;
  final VoidCallback onDelete;
  
  const PostCard({
    super.key,
    required this.post,
    required this.currentUsername,
    required this.onSalute,
    required this.onDelete,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isExpanded = false;

  ImageProvider? _getImage(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(base64String));
    } catch (e) {
      debugPrint('❌ Image decode error: $e');
      return null;
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isAuthor = widget.post.author == widget.currentUsername;
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Card(
        margin: const EdgeInsets.all(12),
        elevation: 4,
        child: Container(
          decoration: BoxDecoration(
            color: widget.post.bgColor,
            borderRadius: BorderRadius.circular(12),
            image: widget.post.bgImagePath != null
                ? DecorationImage(
                    image: _getImage(widget.post.bgImagePath!) ??
                        const AssetImage('assets/placeholder.png'),
                    fit: BoxFit.cover)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: buildAvatar(null, widget.post.author, radius: 24),
                title: GestureDetector(
                  onTap: () async {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final userId = await auth.getUserIdFromUsername(widget.post.author);
                    if (userId != null && mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileView(
                            userId: userId,
                            username: widget.post.author,
                          ),
                        ),
                      );
                    } else if (mounted) {
                      showSnackbar(context, 'User not found', isError: true);
                    }
                  },
                  child: Text(
                    widget.post.author,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                subtitle: Text(_formatTime(widget.post.timestamp),
                    style: const TextStyle(fontSize: 12)),
                trailing: isAuthor
                    ? IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: widget.onDelete)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(widget.post.title,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.grey,
                        )
                      ],
                    ),
                    if (_isExpanded) ...[
                      const SizedBox(height: 8),
                      Text(widget.post.content),
                      if (widget.post.imagePath != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _getImage(widget.post.imagePath!) != null
                              ? Image.memory(
                                  base64Decode(widget.post.imagePath!),
                                  width: double.infinity,
                                  fit: BoxFit.cover)
                              : _buildPlaceholder(),
                        )
                      ]
                    ] else
                      const SizedBox(height: 4)
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        widget.post.userSaluted
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: widget.post.userSaluted ? Colors.red : null,
                      ),
                      onPressed: widget.onSalute,
                    ),
                    Text('${widget.post.salutes} salutes')
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() => Container(
        height: 200,
        color: Colors.grey[300],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 50, color: Colors.grey),
              SizedBox(height: 8),
              Text('Image not available')
            ],
          ),
        ),
      );
}

class CreatePostModal extends StatefulWidget {
  const CreatePostModal({super.key});
  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  String? _base64Image;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _base64Image = base64Encode(bytes));
  }

  void _submit() {
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty) {
      showSnackbar(context, 'Please fill in title and content', isError: true);
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final feed = Provider.of<FeedProvider>(context, listen: false);
    feed.add(Post(
      id: const Uuid().v4(),
      author: auth.username ?? 'Anonymous',
      title: _title.text.trim(),
      content: _content.text.trim(),
      imagePath: _base64Image,
      timestamp: DateTime.now(),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Create Post',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _content,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_base64Image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(_base64Image!),
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Add Image'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                  child: const Text('Post', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 16)
          ],
        ),
      );

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        Provider.of<FeedProvider>(context, listen: false).searchPosts('');
        Provider.of<AuthProvider>(context, listen: false).searchUsers('');
      } else {
        Provider.of<FeedProvider>(context, listen: false).searchPosts(query);
        Provider.of<AuthProvider>(context, listen: false).searchUsers(query);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search posts and heroes...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.white70),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.article), text: 'Posts'),
              Tab(icon: Icon(Icons.people), text: 'Users')
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [SearchPostsTab(), SearchUsersTab()],
        ),
      );
}

class SearchPostsTab extends StatelessWidget {
  const SearchPostsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final feed = Provider.of<FeedProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    if (feed.isSearching) return const Center(child: CircularProgressIndicator());
    if (feed.searchPostsResults.isEmpty)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No posts found')
          ],
        ),
      );
    return ListView.builder(
      itemCount: feed.searchPostsResults.length,
      itemBuilder: (ctx, i) => PostCard(
        post: feed.searchPostsResults[i],
        currentUsername: auth.username ?? '',
        onSalute: () => feed.salute(feed.searchPostsResults[i].id),
        onDelete: () => feed.delete(feed.searchPostsResults[i].id),
      ),
    );
  }
}

class SearchUsersTab extends StatelessWidget {
  const SearchUsersTab({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (auth.searchUsersResults.isEmpty)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No users found')
          ],
        ),
      );
    return ListView.builder(
      itemCount: auth.searchUsersResults.length,
      itemBuilder: (ctx, i) {
        final user = auth.searchUsersResults[i];
        return ListTile(
          leading: buildAvatar(user.profilePic, user.username, radius: 24),
          title: Text(user.displayName ?? user.username,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            '@${user.username}${user.quote != null ? ' • ${user.quote}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 18),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileView(userId: user.id, username: user.username),
            ),
          ),
        );
      },
    );
  }
}

class UserProfileView extends StatefulWidget {
  final String userId, username;
  const UserProfileView({
    super.key,
    required this.userId,
    required this.username,
  });
  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isCurrentUser = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).addListener(_onAuthChange);
    });
  }

  @override
  void dispose() {
    if (mounted) {
      Provider.of<AuthProvider>(context, listen: false).removeListener(_onAuthChange);
    }
    super.dispose();
  }

  void _onAuthChange() {
    if (!_isCurrentUser && mounted) {
      setState(() {
        _isLoading = true;
      });
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final feed = Provider.of<FeedProvider>(context, listen: false);
    
    setState(() {
      _isCurrentUser = auth.user?.id == widget.userId;
    });
    
    try {
      if (_isCurrentUser) {
        _userProfile = auth.profile;
        if (_userProfile != null) {
          await feed.loadUserPosts(_userProfile!.username);
        }
      } else {
        final profile = await auth.loadUserProfile(widget.userId);
        if (profile != null) {
          await feed.loadUserPosts(profile.username);
          final following = await auth.isFollowing(widget.userId);
          setState(() {
            _isFollowing = following;
          });
        }
        _userProfile = profile;
      }
    } catch (e) {
      debugPrint('❌ Load profile error: $e');
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      if (_isFollowing) {
        await auth.unfollowUser(widget.userId);
      } else {
        await auth.followUser(widget.userId);
      }
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        await _loadProfile();
              setState(() {
                _isFollowing = !_isFollowing;
              });
            }
          } catch (e) {
            if (mounted) showSnackbar(context, 'Error: $e', isError: true);
          }
        }
      
        // FIXED: Non-flickering QR code modal
        void _showDonateModal() {
          if (_userProfile?.qrCode != null && _userProfile!.qrCode!.isNotEmpty) {
            // Pre-decode the image to prevent modal flicker
            ImageProvider? qrImage;
            try {
              qrImage = MemoryImage(base64Decode(_userProfile!.qrCode!));
            } catch (e) {
              debugPrint('❌ QR decode error: $e');
              showSnackbar(context, 'Invalid QR code image', isError: true);
              return;
            }
      
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text('Donate to @${widget.username}'),
                content: SizedBox(
                  width: 300,
                  height: 350,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Scan QR code to donate'),
                        const SizedBox(height: 16),
                        // Use a pre-built image widget with fixed size
                        Image(
                          image: qrImage!,
                          fit: BoxFit.contain,
                          width: 250,
                          height: 250,
                          errorBuilder: (context, error, stackTrace) {
                            return const Column(
                              children: [
                                Icon(Icons.error, color: Colors.red, size: 50),
                                SizedBox(height: 8),
                                Text('Failed to load QR code'),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          } else {
            showSnackbar(context, 'No donation QR code available', isError: true);
          }
        }
      
        @override
        Widget build(BuildContext context) {
          final auth = Provider.of<AuthProvider>(context);
          
          return Scaffold(
            appBar: AppBar(title: Text('@${widget.username}')),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _userProfile == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            const Text('User not found'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadProfile,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  buildAvatar(_userProfile!.profilePic, _userProfile!.username,
                                      radius: 80),
                                  const SizedBox(height: 16),
                                  Text(_userProfile!.displayName ?? _userProfile!.username,
                                      style: const TextStyle(
                                          fontSize: 28, fontWeight: FontWeight.bold)),
                                  Text('@${_userProfile!.username}',
                                      style: const TextStyle(fontSize: 16, color: Colors.grey)),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Column(
                                        children: [
                                          Text('${(_userProfile!.followersCount)}',
                                              style: const TextStyle(
                                                  fontSize: 20, fontWeight: FontWeight.bold)),
                                          const Text('Followers', style: TextStyle(color: Colors.grey)),
                                        ],
                                      ),
                                      const SizedBox(width: 32),
                                      Column(
                                        children: [
                                          Text('${(_userProfile!.followingCount)}',
                                              style: const TextStyle(
                                                  fontSize: 20, fontWeight: FontWeight.bold)),
                                          const Text('Following', style: TextStyle(color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (!_isCurrentUser) ...[
                                        ElevatedButton.icon(
                                          onPressed: _toggleFollow,
                                          icon: Icon(_isFollowing ? Icons.person_remove : Icons.person_add),
                                          label: Text(_isFollowing ? 'Unfollow' : 'Follow'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _isFollowing ? Colors.grey : Colors.deepPurple,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // NEW: Donate button
                                        if (_userProfile!.qrCode != null && _userProfile!.qrCode!.isNotEmpty)
                                          ElevatedButton.icon(
                                            onPressed: _showDonateModal,
                                            icon: const Icon(Icons.payment),
                                            label: const Text('Donate'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                  if (_userProfile!.quote != null &&
                                      _userProfile!.quote!.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          '"${_userProfile!.quote}"',
                                          style: const TextStyle(
                                              fontStyle: FontStyle.italic, fontSize: 16),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    )
                                  ]
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text('Posts',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Consumer<FeedProvider>(builder: (context, feed, child) {
                              if (feed.isLoading && feed.posts.isEmpty)
                                return const Center(child: CircularProgressIndicator());
                              if (feed.posts.isEmpty)
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Text('No posts yet'),
                                  ),
                                );
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: feed.posts.length,
                                itemBuilder: (ctx, i) => PostCard(
                                  post: feed.posts[i],
                                  currentUsername: auth.username ?? '',
                                  onSalute: () => feed.salute(feed.posts[i].id),
                                  onDelete: _isCurrentUser
                                      ? () => feed.delete(feed.posts[i].id)
                                      : () {},
                                ),
                              );
                            })
                          ],
                        ),
                      ),
          );
        }
      }
      
      class ThemeTab extends StatelessWidget {
        const ThemeTab({super.key});
      
        @override
        Widget build(BuildContext context) {
          final theme = Provider.of<ThemeProvider>(context);
          final auth = Provider.of<AuthProvider>(context);
      
          return Scaffold(
            appBar: AppBar(title: const Text('Themes'), actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showCreateCustomTheme(context),
              )
            ]),
            body: ListView.builder(
              itemCount: theme.themes.length,
              itemBuilder: (ctx, i) {
                final t = theme.themes[i];
                final isSelected = t.id == theme.currentTheme?.id;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: t.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    title: Text(t.name),
                    subtitle: Text(t.brightness == Brightness.dark ? 'Dark' : 'Light'),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () async {
                      theme.setTheme(t);
                      if (auth.user != null) {
                        await auth.updateUserTheme(t.id);
                      }
                    },
                  ),
                );
              },
            ),
          );
        }
      
        void _showCreateCustomTheme(BuildContext context) {
          final nameController = TextEditingController();
          Color selectedColor = Colors.deepPurple;
          Brightness brightness = Brightness.light;
      
          showDialog(
            context: context,
            builder: (_) => StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Create Custom Theme'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Theme Name'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('Primary Color:'),
                            const SizedBox(width: 16),
                            Container(width: 40, height: 40, color: selectedColor),
                            TextButton(
                              onPressed: () async {
                                final color = await showDialog<Color>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Pick a color'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ColorSlider(
                                            label: 'Red',
                                            value: selectedColor.red.toDouble(),
                                            onChanged: (v) {
                                              setState(() {
                                                selectedColor = Color.fromRGBO(
                                                  v.toInt(),
                                                  selectedColor.green,
                                                  selectedColor.blue,
                                                  1,
                                                );
                                              });
                                            },
                                          ),
                                          ColorSlider(
                                            label: 'Green',
                                            value: selectedColor.green.toDouble(),
                                            onChanged: (v) {
                                              setState(() {
                                                selectedColor = Color.fromRGBO(
                                                  selectedColor.red,
                                                  v.toInt(),
                                                  selectedColor.blue,
                                                  1,
                                                );
                                              });
                                            },
                                          ),
                                          ColorSlider(
                                            label: 'Blue',
                                            value: selectedColor.blue.toDouble(),
                                            onChanged: (v) {
                                              setState(() {
                                                selectedColor = Color.fromRGBO(
                                                  selectedColor.red,
                                                  selectedColor.green,
                                                  v.toInt(),
                                                  1,
                                                );
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, selectedColor),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                                if (color != null) {
                                  setState(() => selectedColor = color);
                                }
                              },
                              child: const Text('Pick Color'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('Mode:'),
                            const SizedBox(width: 16),
                            ChoiceChip(
                              label: const Text('Light'),
                              selected: brightness == Brightness.light,
                              onSelected: (v) =>
                                  setState(() => brightness = Brightness.light),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Dark'),
                              selected: brightness == Brightness.dark,
                              onSelected: (v) =>
                                  setState(() => brightness = Brightness.dark),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) return;
                        final theme = Provider.of<ThemeProvider>(context, listen: false);
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        try {
                          await theme.createCustomTheme(
                            nameController.text.trim(),
                            selectedColor,
                            brightness,
                          );
                          if (auth.user != null) {
                            await auth.updateUserTheme(theme.currentTheme!.id);
                          }
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context);
                            showSnackbar(context, e.toString(), isError: true);
                          }
                        }
                      },
                      child: const Text('Create'),
                    ),
                  ],
                );
              },
            ),
          );
        }
      }
      
      class ColorSlider extends StatelessWidget {
        final String label;
        final double value;
        final ValueChanged<double> onChanged;
        
        const ColorSlider({
          super.key,
          required this.label,
          required this.value,
          required this.onChanged,
        });
        
        @override
        Widget build(BuildContext context) => Row(
              children: [
                SizedBox(width: 60, child: Text(label)),
                Expanded(
                  child: Slider(
                    value: value,
                    min: 0,
                    max: 255,
                    divisions: 255,
                    onChanged: onChanged,
                  ),
                ),
                SizedBox(width: 40, child: Text(value.toInt().toString()))
              ],
            );
      }
      
      class FeedTab extends StatefulWidget {
        const FeedTab({super.key});
        @override
        State<FeedTab> createState() => _FeedTabState();
      }
      
      class _FeedTabState extends State<FeedTab> {
        bool _showFollowingOnly = false;
      
        void _showCreatePost(BuildContext context) => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => const CreatePostModal(),
            );
      
        Future<void> _toggleFeedMode() async {
          final feed = Provider.of<FeedProvider>(context, listen: false);
          setState(() {
            _showFollowingOnly = !_showFollowingOnly;
          });
          
          if (_showFollowingOnly) {
            await feed.loadFollowingPosts();
          } else {
            await feed.load();
          }
        }
      
        @override
        Widget build(BuildContext context) {
          final feed = Provider.of<FeedProvider>(context);
          final auth = Provider.of<AuthProvider>(context);
      
          return Scaffold(
            appBar: AppBar(
              title: const Text('Local Heroes'),
              actions: [
                IconButton(
                  icon: Icon(_showFollowingOnly ? Icons.people : Icons.public),
                  onPressed: _toggleFeedMode,
                  tooltip: _showFollowingOnly ? 'Show all posts' : 'Show following only',
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                )
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () => _showFollowingOnly ? feed.loadFollowingPosts() : feed.load(),
              child: feed.isLoading && feed.posts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : feed.posts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _showFollowingOnly ? Icons.people_outline : Icons.post_add,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(_showFollowingOnly 
                                ? 'No posts from users you follow' 
                                : 'No posts yet. Be the first hero!'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => _showCreatePost(context),
                                child: const Text('Create Post'),
                              )
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: feed.posts.length,
                          itemBuilder: (ctx, i) => PostCard(
                            post: feed.posts[i],
                            currentUsername: auth.username ?? '',
                            onSalute: () => feed.salute(feed.posts[i].id),
                            onDelete: () => feed.delete(feed.posts[i].id),
                          ),
                        ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showCreatePost(context),
              child: const Icon(Icons.add),
            ),
          );
        }
      }
      
      class ProfileTab extends StatelessWidget {
        const ProfileTab({super.key});
      
        @override
        Widget build(BuildContext context) {
          final auth = Provider.of<AuthProvider>(context);
          final profile = auth.profile;
      
          if (profile == null) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading profile...'),
                  ],
                ),
              ),
            );
          }
      
          return Scaffold(
            appBar: AppBar(
              title: const Text('Profile'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      auth.logout();
                    }
                  },
                )
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        buildAvatar(profile.profilePic, profile.username, radius: 60),
                        const SizedBox(height: 16),
                        Text(
                          profile.displayName ?? profile.username,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '@${profile.username}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (profile.quote != null && profile.quote!.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '"${profile.quote}"',
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${profile.followersCount}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('Followers'),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${profile.followingCount}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('Following'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.email),
                      title: const Text('Email'),
                      subtitle: Text(profile.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showEditProfile(context, profile),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      
        Future<void> _changeProfilePicture(
            BuildContext context, UserProfile profile) async {
          final picker = ImagePicker();
          final pickedFile = await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 512,
            maxHeight: 512,
            imageQuality: 85,
          );
          if (pickedFile == null) return;
      
          showLoader(context);
          try {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            final base64String = base64Encode(await pickedFile.readAsBytes());
            await auth.updateProfile(UserProfile(
              id: profile.id,
              username: profile.username,
              email: profile.email,
              displayName: profile.displayName,
              quote: profile.quote,
              profilePic: base64String,
              qrCode: profile.qrCode,
              themeId: profile.themeId,
            ));
            if (context.mounted) showSnackbar(context, '✅ Profile picture updated!');
          } catch (e) {
            if (context.mounted)
              showSnackbar(context, '❌ Failed to update: $e', isError: true);
          } finally {
            if (context.mounted) Navigator.of(context).pop();
          }
        }
      
        // NEW: Change QR code method
        Future<void> _changeQRCode(BuildContext context, UserProfile profile) async {
          final picker = ImagePicker();
          final pickedFile = await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 512,
            maxHeight: 512,
            imageQuality: 85,
          );
          if (pickedFile == null) return;
      
          showLoader(context);
          try {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            final base64String = base64Encode(await pickedFile.readAsBytes());
            await auth.updateProfile(UserProfile(
              id: profile.id,
              username: profile.username,
              email: profile.email,
              displayName: profile.displayName,
              quote: profile.quote,
              profilePic: profile.profilePic,
              qrCode: base64String,
              themeId: profile.themeId,
            ));
            if (context.mounted) showSnackbar(context, '✅ QR code updated!');
          } catch (e) {
            if (context.mounted)
              showSnackbar(context, '❌ Failed to update: $e', isError: true);
          } finally {
            if (context.mounted) Navigator.of(context).pop();
          }
        }
      
        void _showEditProfile(BuildContext context, UserProfile profile) {
          final nameController = TextEditingController(text: profile.displayName);
          final quoteController = TextEditingController(text: profile.quote);
      
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Display Name'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: quoteController,
                      decoration: const InputDecoration(labelText: 'Quote'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _changeProfilePicture(context, profile);
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Change Profile Picture'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                    ),
                    const SizedBox(height: 12),
                    // NEW: QR code upload button with preview
                    if (profile.qrCode != null && profile.qrCode!.isNotEmpty) ...[
                      const Text('Current QR Code:'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        width: 100,
                        child: Image.memory(
                          base64Decode(profile.qrCode!),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.error, color: Colors.red);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _changeQRCode(context, profile);
                      },
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Change Donation QR Code'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    await auth.updateProfile(UserProfile(
                      id: profile.id,
                      username: profile.username,
                      email: profile.email,
                      displayName: nameController.text.trim().isNotEmpty
                          ? nameController.text.trim()
                          : null,
                      quote: quoteController.text.trim().isNotEmpty
                          ? quoteController.text.trim()
                          : null,
                      profilePic: profile.profilePic,
                      qrCode: profile.qrCode,
                      themeId: profile.themeId,
                    ));
                    if (context.mounted) {
                      Navigator.pop(context);
                      showSnackbar(context, '✅ Profile updated!');
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        }
      }
      
      // ── KNOWLEDGE HUB WIDGETS ────────────────────────────────────────────────────
      class KnowledgeHubTab extends StatelessWidget {
        const KnowledgeHubTab({super.key});
      
        @override
        Widget build(BuildContext context) {
          final knowledgeHub = Provider.of<KnowledgeHubProvider>(context);
      
          return Scaffold(
            appBar: AppBar(
              title: const Text('Knowledge Hub'),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search professions...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    onChanged: (query) {
                      knowledgeHub.searchProfessions(query);
                    },
                  ),
                ),
                Expanded(
                  child: knowledgeHub.isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: knowledgeHub.professions.length,
                          itemBuilder: (context, index) {
                            final profession = knowledgeHub.professions[index];
                            return _ProfessionCard(profession: profession);
                          },
                        ),
                ),
              ],
            ),
          );
        }
      }
      
      class _ProfessionCard extends StatelessWidget {
        final Profession profession;
      
        const _ProfessionCard({required this.profession});
      
        @override
        Widget build(BuildContext context) {
          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfessionDetailScreen(profession: profession),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(
                        profession.icon,
                        size: 32,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profession.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profession.shortDescription,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: profession.tags.take(2).map((tag) => 
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.deepPurple[700],
                            ),
                          ),
                        ),
                      ).toList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }
      
      class ProfessionDetailScreen extends StatelessWidget {
        final Profession profession;
      
        const ProfessionDetailScreen({super.key, required this.profession});
      
        @override
        Widget build(BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(profession.name),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Who They Are
                  _buildSectionCard(
                    icon: Icons.groups,
                    title: 'Who They Are',
                    content: profession.whoTheyAre,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  
                  // Hardships They Face
                  _buildSectionCard(
                    icon: Icons.warning,
                    title: 'Hardships They Face',
                    content: profession.hardships,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  
                  // How to Show Respect
                  _buildSectionCard(
                    icon: Icons.volunteer_activism,
                    title: 'How to Show Respect',
                    content: profession.howToShowRespect,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  
                  // Tags
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tags',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: profession.tags.map((tag) => 
                              Chip(
                                label: Text(tag),
                                backgroundColor: Colors.deepPurple.withOpacity(0.1),
                              ),
                            ).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _shareProfession(context),
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _takeQuiz(context),
                        icon: const Icon(Icons.quiz),
                        label: const Text('Take Quiz'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        }
      
        Widget _buildSectionCard({
          required IconData icon,
          required String title,
          required String content,
          required Color color,
        }) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      
        void _shareProfession(BuildContext context) {
          // For now, show a snackbar. You can integrate share plugin later
          showSnackbar(context, 'Sharing feature coming soon!');
        }
      
        void _takeQuiz(BuildContext context) {
          // For now, show a snackbar. You can implement quiz feature later
          showSnackbar(context, 'Quiz feature coming soon!');
        }
      }
      
      class ChatScreen extends StatefulWidget {
        const ChatScreen({super.key});
        @override
        State<ChatScreen> createState() => _ChatScreenState();
      }
      
      class _ChatScreenState extends State<ChatScreen> {
        final _messageController = TextEditingController();
        final _scrollController = ScrollController();
      
        @override
        void dispose() {
          _messageController.dispose();
          _scrollController.dispose();
          super.dispose();
        }
      
        void _sendMessage() {
          if (_messageController.text.trim().isEmpty) return;
          
          final chat = Provider.of<ChatProvider>(context, listen: false);
          chat.sendMessage(_messageController.text);
          _messageController.clear();
          
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      
        @override
        Widget build(BuildContext context) {
          final chat = Provider.of<ChatProvider>(context);
          
          return Scaffold(
            appBar: AppBar(
              title: const Row(
                children: [
                  Icon(Icons.smart_toy, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text('AI Assistant'),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => chat.clearChat(),
                  tooltip: 'Clear chat',
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: chat.messages.length,
                    itemBuilder: (context, index) {
                      final message = chat.messages[index];
                      return Align(
                        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: message.isUser ? Colors.deepPurple : Colors.grey[300],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.text,
                                style: TextStyle(
                                  color: message.isUser ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: message.isUser ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (chat.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Ask anything...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _sendMessage,
                        color: Colors.deepPurple,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      }
      
      class AuthPage extends StatefulWidget {
        const AuthPage({super.key});
        @override
        State<AuthPage> createState() => _AuthPageState();
      }
      
      class _AuthPageState extends State<AuthPage> {
        bool _isLogin = true;
        final _email = TextEditingController();
        final _password = TextEditingController();
        final _username = TextEditingController();
        bool _loading = false;
      
        Future<void> _submit() async {
          if (_email.text.trim().isEmpty || _password.text.trim().isEmpty) {
            showSnackbar(context, 'Please fill in all fields', isError: true);
            return;
          }
          if (!_isLogin && _username.text.trim().isEmpty) {
            showSnackbar(context, 'Please enter a hero name', isError: true);
            return;
          }
      
          setState(() => _loading = true);
          try {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            _isLogin
                ? await auth.login(_email.text.trim(), _password.text.trim())
                : await auth.signup(
                    _email.text.trim(), _password.text.trim(), _username.text.trim());
            if (mounted)
              showSnackbar(context, _isLogin ? '✅ Welcome back!' : '✅ Account created!');
          } catch (e) {
            if (mounted)
              showSnackbar(context, e.toString().replaceAll('Exception: ', ''),
                  isError: true);
          } finally {
            if (mounted) setState(() => _loading = false);
          }
        }
      
        @override
        Widget build(BuildContext context) {
          return Scaffold(
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.shield, size: 80, color: Colors.deepPurple),
                    const SizedBox(height: 40),
                    Text(_isLogin ? 'WELCOME BACK' : 'BECOME A HERO',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 40),
                    TextField(
                      controller: _email,
                      enabled: !_loading,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _password,
                      enabled: !_loading,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    if (!_isLogin) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _username,
                        enabled: !_loading,
                        decoration: InputDecoration(
                          labelText: 'Hero Name',
                          prefixIcon: const Icon(Icons.star),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      )
                    ],
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(60),
                        backgroundColor: Colors.deepPurple,
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_isLogin ? 'LOGIN' : 'REGISTER',
                              style: const TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _loading ? null : () => setState(() => _isLogin = !_isLogin),
                      child: Text(_isLogin
                          ? 'Don\'t have an account? Register'
                          : 'Already have an account? Login'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      
        @override
        void dispose() {
          _email.dispose();
          _password.dispose();
          _username.dispose();
          super.dispose();
        }
      }
      
      class HomePage extends StatefulWidget {
        const HomePage({super.key});
        @override
        State<HomePage> createState() => _HomePageState();
      }
      
      class _HomePageState extends State<HomePage> {
        int _selectedIndex = 0;
      
        @override
        void initState() {
          super.initState();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            final feed = Provider.of<FeedProvider>(context, listen: false);
            final theme = Provider.of<ThemeProvider>(context, listen: false);
            if (auth.user != null) {
              feed.setCurrentUser(auth.user!.id);
              feed.load();
              theme.loadThemes(auth.user!.id);
              if (auth.profile?.themeId != null)
                theme.loadUserTheme(auth.profile!.themeId);
            }
          });
        }
      
        @override
        Widget build(BuildContext context) => Scaffold(
              body: IndexedStack(
                index: _selectedIndex,
                children: const [
                  FeedTab(), 
                  ProfileTab(), 
                  ThemeTab(), 
                  KnowledgeHubTab(), // NEW: Added Knowledge Hub
                  ChatScreen(),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home), label: 'Feed'),
                  NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
                  NavigationDestination(icon: Icon(Icons.palette), label: 'Themes'),
                  NavigationDestination(icon: Icon(Icons.lightbulb), label: 'Knowledge'), // NEW
                  NavigationDestination(icon: Icon(Icons.smart_toy), label: 'Assistant'),
                ],
              ),
            );
      }
      
      class LocalHeroesApp extends StatelessWidget {
        const LocalHeroesApp({super.key});
      
        @override
        Widget build(BuildContext context) {
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuth()),
              ChangeNotifierProvider(create: (_) => FeedProvider()),
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
              ChangeNotifierProvider(create: (_) => ChatProvider()),
              ChangeNotifierProvider(create: (_) => KnowledgeHubProvider()), // NEW
            ],
            child: Consumer3<AuthProvider, FeedProvider, ThemeProvider>(
              builder: (_, auth, feed, theme, __) {
                if (!auth.isInitialized)
                  return const MaterialApp(
                    debugShowCheckedModeBanner: false,
                    home: Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading...')
                          ],
                        ),
                      ),
                    ),
                  );
                if (auth.isLoggedIn && auth.user != null) {
                  feed.setCurrentUser(auth.user!.id);
                  if (theme.currentTheme == null) {
                    theme.loadThemes(auth.user!.id);
                    if (auth.profile?.themeId != null)
                      theme.loadUserTheme(auth.profile!.themeId);
                  }
                }
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  title: 'Local Heroes',
                  theme: theme.currentTheme?.toThemeData() ??
                      ThemeData(
                        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
                        useMaterial3: true,
                      ),
                  home: auth.isLoggedIn ? const HomePage() : const AuthPage(),
                );
              },
            ),
          );
        }
      }
      
      void main() async {
        WidgetsFlutterBinding.ensureInitialized();
        await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
        runApp(const LocalHeroesApp());
      }