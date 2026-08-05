/// Environment variables configured via --dart-define-from-file
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const googleWebClientId = String.fromEnvironment('WEB_CLIENT_ID');
  static const proxyUrl = String.fromEnvironment('PROXY_URL');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasProxy => proxyUrl.isNotEmpty;
}
