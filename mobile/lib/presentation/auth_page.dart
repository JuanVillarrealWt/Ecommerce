import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/auth_use_cases.dart';
import '../application/cart_use_cases.dart';
import '../application/customer_features_repository.dart';
import '../application/get_products.dart';
import 'customer_features_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.loginCustomer,
    required this.updateCustomerProfile,
    required this.registerCustomer,
    required this.logoutCustomer,
    required this.getCurrentCustomer,
    required this.getProductDetail,
    required this.getCart,
    required this.addProductToCart,
    required this.onCartChanged,
    this.customerFeaturesRepository,
    this.onAuthSuccess,
    super.key,
  });

  final LoginCustomerUseCase loginCustomer;
  final UpdateCustomerProfileUseCase updateCustomerProfile;
  final RegisterCustomerUseCase registerCustomer;
  final LogoutCustomerUseCase logoutCustomer;
  final GetCurrentCustomerUseCase getCurrentCustomer;
  final GetProductDetail getProductDetail;
  final GetCart getCart;
  final AddProductToCart addProductToCart;
  final VoidCallback onCartChanged;
  final CustomerFeaturesRepository? customerFeaturesRepository;
  final Future<void> Function()? onAuthSuccess;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static const _ecuadorProvinces = <String>[
    'Azuay',
    'Bolívar',
    'Cañar',
    'Carchi',
    'Chimborazo',
    'Cotopaxi',
    'El Oro',
    'Esmeraldas',
    'Galápagos',
    'Guayas',
    'Imbabura',
    'Loja',
    'Los Ríos',
    'Manabí',
    'Morona Santiago',
    'Napo',
    'Orellana',
    'Pastaza',
    'Pichincha',
    'Santa Elena',
    'Santo Domingo de los Tsáchilas',
    'Sucumbíos',
    'Tungurahua',
    'Zamora Chinchipe',
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
  final Set<String> _touchedFields = {};
  bool _showFieldErrors = false;

  void _markFieldTouched(String field) {
    if (_touchedFields.add(field) && mounted) setState(() {});
  }

  String? _fieldError(String field) {
    if (!_showFieldErrors &&
        !_touchedFields.contains(field) &&
        !_fieldHasValue(field)) {
      return null;
    }
    String? requiredOr(String value) =>
        value.trim().isEmpty ? 'Este campo no puede estar vacío.' : null;
    switch (field) {
      case 'loginEmail':
        return requiredOr(_loginEmailController.text) ??
            (_isValidEmail(_loginEmailController.text.trim())
                ? null
                : 'Escribe un correo electrónico válido.');
      case 'loginPassword':
        return _loginPasswordController.text.isEmpty
            ? 'Este campo no puede estar vacío.'
            : null;
      case 'firstName':
        final value = _regFirstNameController.text.trim();
        return requiredOr(value) ??
            (_isValidName(value) ? null : 'Escribe un nombre válido.');
      case 'lastName':
        final value = _regLastNameController.text.trim();
        return requiredOr(value) ??
            (_isValidName(value) ? null : 'Escribe un apellido válido.');
      case 'province':
        return _selectedProvince == null ? 'Selecciona una provincia.' : null;
      case 'phone':
        final value = _regPhoneController.text.trim();
        return requiredOr(value) ??
            (RegExp(r'^09\d{8}$').hasMatch(value)
                ? null
                : 'Usa 10 dígitos y comienza con 09.');
      case 'registerEmail':
        final value = _regEmailController.text.trim();
        return requiredOr(value) ??
            (_isValidEmail(value) ? null : 'Escribe un correo válido.');
      case 'registerPassword':
        final value = _regPasswordController.text;
        return value.isEmpty
            ? 'Este campo no puede estar vacío.'
            : (_isStrongPassword(value)
                  ? null
                  : 'Usa 8–50 caracteres con mayúscula, minúscula, número y símbolo.');
      case 'confirmPassword':
        final value = _regConfirmPasswordController.text;
        return value.isEmpty
            ? 'Este campo no puede estar vacío.'
            : (value == _regPasswordController.text
                  ? null
                  : 'Las contraseñas no coinciden.');
      default:
        return null;
    }
  }

  bool _fieldHasValue(String field) => switch (field) {
    'loginEmail' => _loginEmailController.text.trim().isNotEmpty,
    'loginPassword' => _loginPasswordController.text.isNotEmpty,
    'firstName' => _regFirstNameController.text.trim().isNotEmpty,
    'lastName' => _regLastNameController.text.trim().isNotEmpty,
    'province' => _selectedProvince != null,
    'phone' => _regPhoneController.text.trim().isNotEmpty,
    'registerEmail' => _regEmailController.text.trim().isNotEmpty,
    'registerPassword' => _regPasswordController.text.isNotEmpty,
    'confirmPassword' => _regConfirmPasswordController.text.isNotEmpty,
    _ => false,
  };

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

  Future<void> _editProfile(
    String currentName,
    String currentProvince,
    String currentPhone,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProfileEditDialog(
        currentName: currentName,
        currentProvince: currentProvince,
        currentPhone: currentPhone,
        provinces: _ecuadorProvinces,
        onSave: widget.updateCustomerProfile,
      ),
    );
    if (result == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil actualizado.')));
    }
  }

  Future<void> _handleLogin() async {
    setState(() => _showFieldErrors = true);
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
        await widget.onAuthSuccess?.call();
        if (!mounted) return;
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
    setState(() => _showFieldErrors = true);
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
      setState(
        () => _errorMessage =
            'El celular debe tener 10 dígitos y comenzar con 09.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.registerCustomer(name, email, password, province, phone);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_first_name', firstName);
        await prefs.setString('auth_last_name', lastName);
      } catch (_) {}
      if (mounted) {
        await widget.onAuthSuccess?.call();
        if (!mounted) return;
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

  Future<void> _handleLogout() async {
    await widget.logoutCustomer();
    if (!mounted) return;

    _loginEmailController.clear();
    _loginPasswordController.clear();
    _regFirstNameController.clear();
    _regLastNameController.clear();
    _regPhoneController.clear();
    _regEmailController.clear();
    _regPasswordController.clear();
    _regConfirmPasswordController.clear();
    setState(() {
      _activeTab = 0;
      _selectedProvince = null;
      _errorMessage = null;
      _obscureLoginPassword = true;
      _obscureRegisterPassword = true;
      _obscureConfirmPassword = true;
    });
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

  bool get _registerHasData =>
      [
        _regFirstNameController,
        _regLastNameController,
        _regPhoneController,
        _regEmailController,
        _regPasswordController,
        _regConfirmPasswordController,
      ].any((controller) => controller.text.isNotEmpty) ||
      _selectedProvince != null;

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
      TextInputFormatter.withFunction((oldValue, newValue) {
        if (newValue.text.contains('  ') || newValue.text.startsWith(' ')) {
          return oldValue;
        }
        return newValue;
      });

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
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                    ListTile(
                      leading: const Icon(Icons.manage_accounts_outlined),
                      title: const Text('Editar mi perfil'),
                      subtitle: const Text(
                        'Actualiza tu nombre, provincia y teléfono',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editProfile(
                        customer.name,
                        customer.province,
                        customer.phone,
                      ),
                    ),
                    const Divider(height: 24),
                    if (widget.customerFeaturesRepository != null) ...[
                      ListTile(
                        leading: const Icon(Icons.favorite_border),
                        title: const Text('Favoritos y direcciones'),
                        subtitle: const Text(
                          'Guarda tus preferencias en tu cuenta',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CustomerFeaturesPage(
                                repository: widget.customerFeaturesRepository!,
                                getProductDetail: widget.getProductDetail,
                                getCart: widget.getCart,
                                addProductToCart: widget.addProductToCart,
                                onCartChanged: widget.onCartChanged,
                                initialProvince: customer.province,
                                initialPhone: customer.phone,
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 24),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar sesión'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                  child: _authTabButton('Registrarse', 1, enabled: true),
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
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    hintText: 'ejemplo@correo.com',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                    errorText: _fieldError('loginEmail'),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: _limitedTextFormatters(),
                  onChanged: (_) => setState(() {}),
                  onTapOutside: (_) => _markFieldTouched('loginEmail'),
                  onSubmitted: (_) => _markFieldTouched('loginEmail'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _loginPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Escribe tu contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                    errorText: _fieldError('loginPassword'),
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
                  onTapOutside: (_) => _markFieldTouched('loginPassword'),
                  onSubmitted: (_) => _markFieldTouched('loginPassword'),
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
                Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) _markFieldTouched('firstName');
                  },
                  child: TextField(
                    controller: _regFirstNameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre',
                      hintText: 'Ej. Ana',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                      errorText: _fieldError('firstName'),
                    ),
                    inputFormatters: _limitedTextFormatters(name: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 16),
                Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) _markFieldTouched('lastName');
                  },
                  child: TextField(
                    controller: _regLastNameController,
                    decoration: InputDecoration(
                      labelText: 'Apellido',
                      hintText: 'Ej. Pérez',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                      errorText: _fieldError('lastName'),
                    ),
                    inputFormatters: _limitedTextFormatters(name: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 16),
                Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) _markFieldTouched('province');
                  },
                  child: DropdownButtonFormField<String>(
                    value: _selectedProvince,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Provincia',
                      hintText: 'Selecciona una provincia',
                      prefixIcon: Icon(Icons.map_outlined),
                      border: OutlineInputBorder(),
                      errorText: _fieldError('province'),
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
                    hint: const Text('Selecciona una provincia'),
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
                    onChanged: (province) => setState(() {
                      _selectedProvince = province;
                      _touchedFields.add('province');
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _regPhoneController,
                  decoration: InputDecoration(
                    labelText: 'Celular (10 dígitos, empieza con 09)',
                    hintText: '0991234567',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                    errorText: _fieldError('phone'),
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
                  onTapOutside: (_) => _markFieldTouched('phone'),
                  onSubmitted: (_) => _markFieldTouched('phone'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _regEmailController,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    hintText: 'ejemplo@correo.com',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                    errorText: _fieldError('registerEmail'),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: _limitedTextFormatters(),
                  onChanged: (_) => setState(() {}),
                  onTapOutside: (_) => _markFieldTouched('registerEmail'),
                  onSubmitted: (_) => _markFieldTouched('registerEmail'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _regPasswordController,
                  decoration: InputDecoration(
                    labelText:
                        'Contraseña (8–50 caracteres, mayúscula, número y símbolo)',
                    hintText: 'Ej. Montana2026!',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                    errorText: _fieldError('registerPassword'),
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
                  onTapOutside: (_) => _markFieldTouched('registerPassword'),
                  onSubmitted: (_) => _markFieldTouched('registerPassword'),
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
                    hintText: 'Repite la contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    errorText: _fieldError('confirmPassword'),
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
                  onTapOutside: (_) => _markFieldTouched('confirmPassword'),
                  onSubmitted: (_) => _markFieldTouched('confirmPassword'),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        _regConfirmPasswordController.text.isEmpty
                            ? Icons.info_outline
                            : _regPasswordController.text ==
                                  _regConfirmPasswordController.text
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        size: 18,
                        color: _regConfirmPasswordController.text.isEmpty
                            ? colors.onSurfaceVariant
                            : _regPasswordController.text ==
                                  _regConfirmPasswordController.text
                            ? Colors.green
                            : colors.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _regConfirmPasswordController.text.isEmpty
                            ? 'Confirma tu contraseña'
                            : _regPasswordController.text ==
                                  _regConfirmPasswordController.text
                            ? 'Las contraseñas coinciden'
                            : 'Las contraseñas no coinciden',
                        style: TextStyle(
                          color: _regConfirmPasswordController.text.isEmpty
                              ? colors.onSurfaceVariant
                              : _regPasswordController.text ==
                                    _regConfirmPasswordController.text
                              ? Colors.green
                              : colors.error,
                        ),
                      ),
                    ],
                  ),
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

class _ProfileEditDialog extends StatefulWidget {
  const _ProfileEditDialog({
    required this.currentName,
    required this.currentProvince,
    required this.currentPhone,
    required this.provinces,
    required this.onSave,
  });

  final String currentName;
  final String currentProvince;
  final String currentPhone;
  final List<String> provinces;
  final Future<Object?> Function(String name, String province, String phone)
  onSave;

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final String _initialFirst;
  late final String _initialLast;
  late final String _initialPhone;
  late final String? _initialProvince;
  String? _province;
  String _error = '';
  bool _saving = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    final parts = widget.currentName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    String first;
    String last;
    if (parts.length >= 3) {
      first = parts.take(2).join(' ');
      last = parts.skip(2).join(' ');
    } else if (parts.length == 2) {
      first = parts[0];
      last = parts[1];
    } else if (parts.length == 1) {
      first = parts[0];
      last = '';
    } else {
      first = '';
      last = '';
    }
    _firstName = TextEditingController(text: first);
    _lastName = TextEditingController(text: last);
    _phone = TextEditingController(text: widget.currentPhone);
    _initialFirst = _firstName.text;
    _initialLast = _lastName.text;
    _initialPhone = _phone.text;
    _initialProvince = widget.provinces.contains(widget.currentProvince)
        ? widget.currentProvince
        : null;
    _province = _initialProvince;
    _loadSavedSplit();
  }

  Future<void> _loadSavedSplit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFirst = prefs.getString('auth_first_name');
      final savedLast = prefs.getString('auth_last_name');
      if (savedFirst != null && savedLast != null) {
        final combined = '$savedFirst $savedLast'.trim();
        if (combined == widget.currentName.trim() && mounted) {
          setState(() {
            _firstName.text = savedFirst;
            _lastName.text = savedLast;
            _initialFirst = savedFirst;
            _initialLast = savedLast;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _firstName.text != _initialFirst ||
      _lastName.text != _initialLast ||
      _phone.text != _initialPhone ||
      _province != _initialProvince;

  void _close(bool result) {
    if (_allowPop || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  Future<void> _requestClose() async {
    if (_saving) return;
    if (!_dirty) {
      _close(false);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text(
          'Tienes cambios en tu perfil. ¿Quieres salir sin guardarlos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Seguir editando'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) _close(false);
  }

  TextInputFormatter get _nameFormatter =>
      TextInputFormatter.withFunction((oldValue, newValue) {
        if (!RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ' -]*$").hasMatch(newValue.text) ||
            newValue.text.startsWith(' ') ||
            newValue.text.contains('  ')) {
          return oldValue;
        }
        return newValue;
      });

  TextInputFormatter get _ecuadorPhoneFormatter =>
      TextInputFormatter.withFunction((oldValue, newValue) {
        final value = newValue.text;
        if (value.isEmpty ||
            value == '0' ||
            value == '09' ||
            RegExp(r'^09\d{0,8}$').hasMatch(value)) {
          return newValue;
        }
        return oldValue;
      });

  Future<void> _save() async {
    final first = _firstName.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final last = _lastName.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final phone = _phone.text;
    final namePattern = RegExp(
      r"^[A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ]+(?:[ '-][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ]+)*$",
    );
    if (first.length > 50 ||
        last.length > 50 ||
        !namePattern.hasMatch(first) ||
        !namePattern.hasMatch(last) ||
        _province == null ||
        !RegExp(r'^09\d{8}$').hasMatch(phone)) {
      setState(() {
        _error =
            'Revisa nombre y apellido (máximo 50 caracteres), provincia y celular de 10 dígitos desde 09.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await widget.onSave('$first $last', _province!, phone);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_first_name', first);
        await prefs.setString('auth_last_name', last);
      } catch (_) {}
      if (mounted) _close(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString().replaceFirst('HttpException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _requestClose();
    },
    child: AlertDialog(
      title: const Text('Editar perfil'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _firstName,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                _nameFormatter,
                LengthLimitingTextInputFormatter(50),
              ],
              textInputAction: TextInputAction.none,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastName,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [
                _nameFormatter,
                LengthLimitingTextInputFormatter(50),
              ],
              textInputAction: TextInputAction.none,
              decoration: const InputDecoration(labelText: 'Apellido'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _province,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Provincia'),
              items: [
                for (final item in widget.provinces)
                  DropdownMenuItem(value: item, child: Text(item)),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _province = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _ecuadorPhoneFormatter,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                hintText: '0991234567',
              ),
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : _requestClose,
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    ),
  );
}
