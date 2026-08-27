import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Everything the app knows about the server.
///
/// One base URL, one bearer token, one error shape. The token is a real Connect
/// session — the same one the browser uses — so signing out on either side ends it
/// on both, and every permission and visibility rule already applies to these calls.
class ApiException implements Exception {
  ApiException(this.code, this.message, {this.status});
  final String code;
  final String message;
  final int? status;

  bool get isAuth => status == 401 || code == 'UNAUTHORIZED';

  @override
  String toString() => message;
}

class Session {
  Session({
    required this.token,
    required this.userName,
    required this.userEmail,
    required this.tenantName,
    required this.currency,
    required this.workspace,
    required this.role,
    required this.persona,
    required this.permissions,
  });

  final String token;
  final String userName;
  final String userEmail;
  final String tenantName;

  /// What money is counted in here — amounts are never shown bare.
  final String currency;
  final String workspace;
  final String role;
  final String persona;
  final List<String> permissions;

  bool can(String permission) => permissions.contains(permission);

  Map<String, dynamic> toJson() => {
        'token': token,
        'userName': userName,
        'userEmail': userEmail,
        'tenantName': tenantName,
        'currency': currency,
        'workspace': workspace,
        'role': role,
        'persona': persona,
        'permissions': permissions,
      };

  static Session fromJson(Map<String, dynamic> json) => Session(
        token: json['token'] as String,
        userName: (json['userName'] ?? '') as String,
        userEmail: (json['userEmail'] ?? '') as String,
        tenantName: (json['tenantName'] ?? '') as String,
        currency: (json['currency'] ?? '') as String,
        workspace: (json['workspace'] ?? 'HYBRID') as String,
        role: (json['role'] ?? '') as String,
        persona: (json['persona'] ?? 'agent') as String,
        permissions: ((json['permissions'] ?? []) as List).map((e) => e.toString()).toList(),
      );
}

class Api {
  Api._();
  static final Api instance = Api._();

  /// Points at production by default; override at launch with
  /// `--dart-define=MAKUTANO_API_URL=http://10.0.2.2:5188` for a local server.
  static const defaultBaseUrl = String.fromEnvironment(
    'MAKUTANO_API_URL',
    defaultValue: 'https://connect.makutano.co.tz',
  );

  String _baseUrl = defaultBaseUrl;
  Session? _session;

  String get baseUrl => _baseUrl;
  Session? get session => _session;
  bool get signedIn => _session != null;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl/api/mobile/v1$path').replace(queryParameters: query);

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (_session != null) 'authorization': 'Bearer ${_session!.token}',
      };

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('baseUrl') ?? defaultBaseUrl;
    final raw = prefs.getString('session');
    if (raw != null) {
      try {
        _session = Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _session = null;
      }
    }
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseUrl', _baseUrl);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_session == null) {
      await prefs.remove('session');
    } else {
      await prefs.setString('session', jsonEncode(_session!.toJson()));
    }
  }

  Map<String, dynamic> _unwrap(http.Response res) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('BAD_RESPONSE', 'The server sent something unexpected.', status: res.statusCode);
    }
    if (body['success'] == true) return (body['data'] ?? const {}) as Map<String, dynamic>;
    final error = (body['error'] ?? const {}) as Map<String, dynamic>;
    throw ApiException(
      (error['code'] ?? 'ERROR').toString(),
      (error['message'] ?? 'Something went wrong.').toString(),
      status: res.statusCode,
    );
  }

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) async {
    final res = await http.get(_uri(path, query), headers: _headers).timeout(const Duration(seconds: 20));
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http
        .post(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    return _unwrap(res);
  }

  // ── auth ──────────────────────────────────────────────────────────────────
  Future<Session> signIn(String email, String password, {String device = 'Makutano mobile'}) async {
    final data = await _post('/auth/login', {'email': email, 'password': password, 'device': device});
    final user = data['user'] as Map<String, dynamic>;
    final tenant = data['tenant'] as Map<String, dynamic>;
    _session = Session(
      token: data['token'] as String,
      userName: (user['name'] ?? '') as String,
      userEmail: (user['email'] ?? '') as String,
      tenantName: (tenant['name'] ?? '') as String,
      currency: (tenant['currency'] ?? '') as String,
      workspace: (tenant['workspace'] ?? 'HYBRID') as String,
      role: (data['role'] ?? '') as String,
      persona: (data['persona'] ?? 'agent') as String,
      permissions: ((data['permissions'] ?? []) as List).map((e) => e.toString()).toList(),
    );
    await _persist();
    return _session!;
  }

  Future<void> signOut() async {
    try {
      if (_session != null) await _post('/auth/logout', {});
    } catch (_) {
      // Signing out locally must succeed even when the network does not.
    }
    _session = null;
    await _persist();
  }

  /// Called when any request comes back 401: the session died elsewhere.
  Future<void> forgetSession() async {
    _session = null;
    await _persist();
  }

  // ── data ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> me() => _get('/me');

  Future<Map<String, dynamic>> inbox({String filter = 'all'}) =>
      _get('/inbox', filter == 'all' ? null : {'filter': filter});

  Future<Map<String, dynamic>> thread(String id) => _get('/inbox/$id');

  Future<Map<String, dynamic>> send(String id, String text) => _post('/inbox/$id/messages', {'text': text});

  Future<Map<String, dynamic>> assignToMe(String id) => _post('/inbox/$id/assign', {});

  Future<Map<String, dynamic>> registerDevice(String token, {String platform = 'android', String? deviceName}) =>
      _post('/devices', {'token': token, 'platform': platform, 'deviceName': deviceName});

  /// Lifecycle objects with the next step already resolved by the server.
  Future<Map<String, dynamic>> work() => _get('/work');

  /// Log an enquiry. Returns the reference and the thread it belongs to.
  Future<Map<String, dynamic>> createEnquiry({
    required String name,
    String? phone,
    String? email,
    String? notes,
    int? adults,
    int? children,
    bool acknowledge = false,
  }) =>
      _post('/enquiries', {
        'name': name,
        'phone': phone,
        'email': email,
        'notes': notes,
        'adults': adults,
        'children': children,
        'acknowledge': acknowledge,
      });
}
