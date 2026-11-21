import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/auth_use_cases.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.loginCustomer,
    required this.registerCustomer,
    required this.logoutCustomer,
    required this.getCurrentCustomer,
    this.onAuthSuccess,
    super.key,
  });

  final LoginCustomerUseCase loginCustomer;
  final RegisterCustomerUseCase registerCustomer;
  final LogoutCustomerUseCase logoutCustomer;
  final GetCurrentCustomerUseCase getCurrentCustomer;
  final VoidCallback? onAuthSuccess;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static const _ecuadorProvinces = <String>[
    'Azuay', 'Bolívar', 'Cañar', 'Carchi', 'Chimborazo', 'Cotopaxi',
    'El Oro', 'Esmeraldas', 'Galápagos', 'Guayas', 'Imbabura', 'Loja',
    'Los Ríos', 'Manabí', 'Morona Santiago', 'Napo', 'Orellana', 'Pastaza',
    'Pichincha', 'Santa Elena', 'Santo Domingo de los Tsáchilas',
    'Sucumbíos', 'Tungurahua', 'Zamora Chinchipe',
  ];

  int _activeTab = 0;

  // Login controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Register controllers
  final _regFirstNameController = TextEditingController();
  final _regLastNameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  String? _selectedProvince;
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureLoginPassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _regFirstNameController.dispose();
    _regLastNameController.dispose();
    _regPhoneController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Por favor complete todos los campos.');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _errorMessage = 'Escribe un correo electrónico válido.');
      return;
    }
    if (email.length > 50 ||
        password.length > 50 ||
        _hasRepeatedSpaces(email) ||
        _hasRepeatedSpaces(password)) {
      setState(
        () => _errorMessage =
            'Los campos admiten hasta 50 caracteres y no permiten dos espacios seguidos.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.loginCustomer(email, password);
      if (mounted) {
        widget.onAuthSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión iniciada con éxito.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _errorMessage = e.toString().replaceFirst('HttpException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    final firstName = _capitalizeName(_regFirstNameController.text.trim());
    final lastName = _capitalizeName(_regLastNameController.text.trim());
    final name = '$firstName $lastName';
    final email = _regEmailController.text.trim();
    final password = _regPasswordController.text;
    final confirmPassword = _regConfirmPasswordController.text;
    final province = _selectedProvince;
    final phone = _regPhoneController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        province == null ||
        phone.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() => _errorMessage = 'Por favor complete todos los campos.');
      return;
    }

    if (name.length > 50 ||
        !_isValidName(firstName) ||
        !_isValidName(lastName) ||
        _hasRepeatedSpaces(name)) {
      setState(
        () => _errorMessage =
            'Nombre y apellido admiten letras, espacios, guion o apóstrofo; juntos no deben superar 50 caracteres.',
      );
      return;
    }
    if (!_isValidEmail(email) ||
        email.length > 50 ||
        _hasRepeatedSpaces(email)) {
      setState(
        () => _errorMessage =
            'Escribe un correo válido de máximo 50 caracteres y sin espacios repetidos.',
      );
      return;
    }
    if (!_isStrongPassword(password)) {
      setState(
        () => _errorMessage =
            'La contraseña debe tener 8–50 caracteres, mayúscula, minúscula, número y símbolo; no uses espacios repetidos.',
      );
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden.');
      return;
    }
    if (!RegExp(r'^09\d{8}$').hasMatch(phone)) {
      setState(() => _errorMessage = 'El celular debe tener 10 dígitos y comenzar con 09.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.registerCustomer(name, email, password, province, phone);
      if (mounted) {
        widget.onAuthSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta registrada y sesión iniciada con éxito.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _errorMessage = e.toString().replaceFirst('HttpException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _hasRepeatedSpaces(String value) => value.contains('  ');

  String _capitalizeName(String value) {
    var capitalizeNext = true;
    final result = StringBuffer();
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      if (RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ]').hasMatch(character)) {
        result.write(
          capitalizeNext ? character.toUpperCase() : character.toLowerCase(),
        );
        capitalizeNext = false;
      } else {
        result.write(character);
        capitalizeNext =
            character == ' ' || character == '-' || character == "'";
      }
    }
    return result.toString();
  }

  TextInputFormatter _nameCaseFormatter() => TextInputFormatter.withFunction((
    oldValue,
    newValue,
  ) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final text = _capitalizeName(newValue.text);
    if (text == newValue.text) return newValue;
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final normalizedCursor = _capitalizeName(
      newValue.text.substring(0, cursor),
    ).length;
    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: normalizedCursor),
      composing: TextRange.empty,
    );
  });

  bool _isValidEmail(String value) => RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
  ).hasMatch(value);

  bool _isValidName(String value) => RegExp(
    r"^[A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ]+(?:[ '-][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ]+)*$",
  ).hasMatch(value);

  bool _isStrongPassword(String value) =>
      value.length >= 8 &&
      value.length <= 50 &&
      !RegExp(r'\s').hasMatch(value) &&
      RegExp(r'[A-Z]').hasMatch(value) &&
      RegExp(r'[a-z]').hasMatch(value) &&
      RegExp(r'\d').hasMatch(value) &&
      RegExp(r'[^A-Za-z0-9]').hasMatch(value);

  bool get _loginHasData =>
      _loginEmailController.text.isNotEmpty ||
      _loginPasswordController.text.isNotEmpty;

  bool get _registerHasData => [
    _regFirstNameController,
    _regLastNameController,
    _regEmailController,
    _regPasswordController,
    _regConfirmPasswordController,
  ].any((controller) => controller.text.isNotEmpty);

  Widget _passwordRule(String label, bool met) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 17,
          color: met ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 7),
        Text(label, style: TextStyle(color: met ? Colors.green : Colors.grey)),
      ],
    ),
  );

  Widget _authTabButton(String label, int tab, {required bool enabled}) =>
      OutlinedButton(
        onPressed: enabled ? () => setState(() => _activeTab = tab) : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: _activeTab == tab
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
        ),
        child: Text(label),
      );

  TextInputFormatter _noRepeatedSpacesFormatter() =>
      TextInputFormatter.withFunction(
        (oldValue, newValue) =>
            newValue.text.contains('  ') ? oldValue : newValue,
      );

  List<TextInputFormatter> _limitedTextFormatters({bool name = false}) => [
    if (name) ...[
      FilteringTextInputFormatter.allow(RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ' -]")),
      _nameCaseFormatter(),
    ],
    _noRepeatedSpacesFormatter(),
    LengthLimitingTextInputFormatter(50),
  ];

  @override
  Widget build(BuildContext context) {
    final customer = widget.getCurrentCustomer();
    final colors = Theme.of(context).colorScheme;

    if (customer != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Perfil')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: colors.primary,
                child: Icon(Icons.person, size: 54, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                customer.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                customer.email,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Text(
                  'Contacto Odoo: Partner #${customer.partnerId}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ),
              const Divider(height: 40),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    await widget.logoutCustomer();
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuenta de Cliente'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _authTabButton(
                    'Iniciar sesión',
                    0,
                    enabled: _activeTab == 0 || !_registerHasData,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _authTabButton(
                    'Registrarse',
                    1,
                    enabled: _activeTab == 1 || !_loginHasData,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _activeTab,
        children: [
          // Login
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.error),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                TextField(
                  controller: _loginEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: _limitedTextFormatters(),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _loginPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscureLoginPassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: () => setState(
                        () => _obscureLoginPassword = !_obscureLoginPassword,
                      ),
                      icon: Icon(
                        _obscureLoginPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  obscureText: _obscureLoginPassword,
                  inputFormatters: _limitedTextFormatters(),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Ingresar', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          // Registro
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.error),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                TextField(
                  controller: _regFirstNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: _limitedTextFormatters(name: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _regLastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Apellido',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: _limitedTextFormatters(name: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedProvince,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Provincia',
                    prefixIcon: Icon(Icons.map_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final province in _ecuadorProvinces)
                      DropdownMenuItem(
                        value: province,
                        child: Text(
                          province,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  selectedItemBuilder: (context) => [
                    for (final province in _ecuadorProvinces)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          province,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (province) => setState(() => _selectedProvince = province),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _regPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Celular (10 dígitos, empieza con 09)',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(10),
                    FilteringTextInputFormatter.digitsOnly,
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final number = newValue.text;
                      if ((number.isNotEmpty && !number.startsWith('0')) ||
                          (number.length > 1 && !number.startsWith('09'))) {
                        return oldValue;
                      }
                      return newValue;
                    }),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _regEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: _limitedTextFormatters(),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _regPasswordController,
                  decoration: InputDecoration(
                    labelText:
                        'Contraseña (8–50 caracteres, mayúscula, número y símbolo)',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscureRegisterPassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: () => setState(
                        () => _obscureRegisterPassword =
                            !_obscureRegisterPassword,
                      ),
                      icon: Icon(
                        _obscureRegisterPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  obscureText: _obscureRegisterPassword,
                  inputFormatters: _limitedTextFormatters(),
                  onChanged: (_) => setState(() {}),
                ),
                _passwordRule(
                  'Mínimo 8 caracteres',
                  _regPasswordController.text.length >= 8,
                ),
                _passwordRule(
                  'Al menos una mayúscula',
                  RegExp(r'[A-Z]').hasMatch(_regPasswordController.text),
                ),
                _passwordRule(
                  'Al menos una minúscula',
                  RegExp(r'[a-z]').hasMatch(_regPasswordController.text),
                ),
                _passwordRule(
                  'Al menos un número',
                  RegExp(r'\d').hasMatch(_regPasswordController.text),
                ),
                _passwordRule(
                  'Al menos un símbolo y sin espacios',
                  RegExp(
                        r'[^A-Za-z0-9]',
                      ).hasMatch(_regPasswordController.text) &&
                      !RegExp(r'\s').hasMatch(_regPasswordController.text),
                ),
                _passwordRule(
                  'Máximo 50 caracteres',
                  _regPasswordController.text.length <= 50,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _regConfirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirmPassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  obscureText: _obscureConfirmPassword,
                  inputFormatters: _limitedTextFormatters(),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isLoading ? null : _handleRegister,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Registrar cuenta',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
