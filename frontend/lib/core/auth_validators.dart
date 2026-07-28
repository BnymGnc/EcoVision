abstract final class AuthValidators {
  static final RegExp _email = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@"
    r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
  );

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'E-posta zorunludur';
    if (email.length > 254 || !_email.hasMatch(email)) {
      return 'Geçerli bir e-posta adresi girin';
    }
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.length < 8 || password.length > 72) {
      return 'Parola 8-72 karakter olmalıdır';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'En az bir büyük harf ekleyin';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'En az bir küçük harf ekleyin';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'En az bir rakam ekleyin';
    }
    if (!RegExp(r'[^A-Za-z0-9\s]').hasMatch(password)) {
      return 'En az bir özel karakter ekleyin';
    }
    return null;
  }
}
