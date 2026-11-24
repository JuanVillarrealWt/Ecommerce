import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/customer_features_repository.dart';

class AddressFormPage extends StatefulWidget {
  const AddressFormPage({
    required this.repository,
    this.initialProvince = '',
    this.initialPhone = '',
    this.initialAddress,
    this.isPrimary = false,
    super.key,
  });

  final CustomerFeaturesRepository repository;
  final String initialProvince;
  final String initialPhone;
  final Map<String, dynamic>? initialAddress;
  final bool isPrimary;

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  static const _provinces = <String>[
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
  static const _citiesByProvince = <String, List<String>>{
    'Azuay': ['Cuenca', 'Gualaceo', 'Paute', 'Santa Isabel', 'Sígsig'],
    'Bolívar': ['Guaranda', 'Caluma', 'Chillanes', 'Echeandía', 'San Miguel'],
    'Cañar': ['Azogues', 'Biblián', 'Cañar', 'La Troncal', 'Déleg'],
    'Carchi': ['Tulcán', 'Bolívar', 'Espejo', 'Mira', 'Montúfar'],
    'Chimborazo': ['Riobamba', 'Alausí', 'Chambo', 'Guano', 'Penipe'],
    'Cotopaxi': ['Latacunga', 'La Maná', 'Pangua', 'Pujilí', 'Salcedo'],
    'El Oro': ['Machala', 'Arenillas', 'Huaquillas', 'Pasaje', 'Santa Rosa'],
    'Esmeraldas': [
      'Esmeraldas',
      'Atacames',
      'Eloy Alfaro',
      'Quinindé',
      'Muisne',
    ],
    'Galápagos': ['Puerto Baquerizo Moreno', 'Puerto Ayora', 'Puerto Villamil'],
    'Guayas': ['Guayaquil', 'Daule', 'Durán', 'Milagro', 'Samborondón'],
    'Imbabura': ['Ibarra', 'Cotacachi', 'Otavalo', 'Pimampiro', 'Urcuquí'],
    'Loja': ['Loja', 'Catamayo', 'Cariamanga', 'Macará', 'Saraguro'],
    'Los Ríos': ['Babahoyo', 'Baba', 'Quevedo', 'Ventanas', 'Vinces'],
    'Manabí': ['Portoviejo', 'Chone', 'Jipijapa', 'Manta', 'Montecristi'],
    'Morona Santiago': [
      'Macas',
      'Gualaquiza',
      'Limón Indanza',
      'Palora',
      'Sucúa',
    ],
    'Napo': [
      'Tena',
      'Archidona',
      'El Chaco',
      'Quijos',
      'Carlos Julio Arosemena Tola',
    ],
    'Orellana': [
      'Francisco de Orellana',
      'Aguarico',
      'La Joya de los Sachas',
      'Loreto',
    ],
    'Pastaza': ['Puyo', 'Arajuno', 'Mera', 'Santa Clara'],
    'Pichincha': [
      'Quito',
      'Cayambe',
      'Machachi',
      'Pedro Vicente Maldonado',
      'Sangolquí',
    ],
    'Santa Elena': ['Santa Elena', 'La Libertad', 'Salinas'],
    'Santo Domingo de los Tsáchilas': ['Santo Domingo', 'La Concordia'],
    'Sucumbíos': [
      'Nueva Loja',
      'Cascales',
      'Cuyabeno',
      'Gonzalo Pizarro',
      'Shushufindi',
    ],
    'Tungurahua': ['Ambato', 'Baños', 'Pelileo', 'Píllaro', 'Quero'],
    'Zamora Chinchipe': [
      'Zamora',
      'Yantzaza',
      'Chinchipe',
      'El Pangui',
      'Nangaritza',
    ],
  };

  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(
    text: widget.initialAddress?['label']?.toString() ?? '',
  );
  late final _recipient = TextEditingController(
    text: widget.initialAddress?['recipient']?.toString() ?? '',
  );
  late final _street = TextEditingController(
    text: widget.initialAddress?['street']?.toString() ?? '',
  );
  late final _city = TextEditingController(
    text: widget.initialAddress?['city']?.toString() ?? '',
  );
  late final _postalCode = TextEditingController(
    text: widget.initialAddress?['postalCode']?.toString() ?? '',
  );
  late final _phone = TextEditingController(
    text: widget.initialAddress?['phone']?.toString() ?? widget.initialPhone,
  );
  String? _province;
  bool _otherCity = false;
  bool _saving = false;
  bool _allowPop = false;
  late List<String> _initialValues;

  @override
  void initState() {
    super.initState();
    final initialProvince =
        widget.initialAddress?['province']?.toString() ??
        widget.initialProvince;
    for (final province in _provinces) {
      if (province.toLowerCase() == initialProvince.toLowerCase()) {
        _province = province;
        break;
      }
    }
    _otherCity =
        _city.text.isNotEmpty &&
        !(_citiesByProvince[_province] ?? const <String>[]).contains(
          _city.text,
        );
    _initialValues = _currentValues();
  }

  List<String> _currentValues() => [
    _label.text,
    _recipient.text,
    _street.text,
    _city.text,
    _postalCode.text,
    _phone.text,
    _province ?? '',
    _otherCity.toString(),
  ];

  bool get _hasUnsavedChanges {
    final current = _currentValues();
    for (var index = 0; index < current.length; index++) {
      if (current[index] != _initialValues[index]) return true;
    }
    return false;
  }

  Future<void> _requestClose() async {
    if (_saving) return;
    if (!_hasUnsavedChanges) {
      setState(() => _allowPop = true);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final discard =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('¿Descartar cambios?'),
            content: const Text(
              'Tienes cambios en la dirección. ¿Quieres salir sin guardarlos?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Seguir editando'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Descartar'),
              ),
            ],
          ),
        ) ??
        false;
    if (discard && mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _recipient.dispose();
    _street.dispose();
    _city.dispose();
    _postalCode.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _normalized(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  String _capitalizeWords(String value) {
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

  TextInputFormatter _textFormatter(RegExp allowed) =>
      TextInputFormatter.withFunction((oldValue, newValue) {
        if (!newValue.text.runes.every(
          (rune) => allowed.hasMatch(String.fromCharCode(rune)),
        )) {
          return oldValue;
        }
        if (newValue.text.contains('  ') || newValue.text.startsWith(' ')) {
          return oldValue;
        }
        if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
          return newValue;
        }
        final formatted = _capitalizeWords(newValue.text);
        final cursor = newValue.selection.baseOffset.clamp(
          0,
          newValue.text.length,
        );
        final adjusted = _capitalizeWords(
          newValue.text.substring(0, cursor),
        ).length;
        return newValue.copyWith(
          text: formatted,
          selection: TextSelection.collapsed(offset: adjusted),
          composing: TextRange.empty,
        );
      });

  String? _personValidator(String? value) {
    final text = _normalized(value ?? '');
    if (text.isEmpty) return 'Completa este campo';
    return RegExp(
          r"^[A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ]+(?:[ '-][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ]+)*$",
        ).hasMatch(text)
        ? null
        : 'Usa solo letras, espacios, guion o apóstrofo';
  }

  String? _streetValidator(String? value) {
    final text = _normalized(value ?? '');
    if (text.isEmpty) return 'Completa este campo';
    return RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ0-9#.,/' -]+$").hasMatch(text)
        ? null
        : 'Revisa el formato de la dirección';
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter> formatters = const [],
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      textCapitalization: keyboard == TextInputType.text
          ? TextCapitalization.words
          : TextCapitalization.none,
      inputFormatters: formatters,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator:
          validator ??
          (value) => value == null || value.trim().isEmpty
              ? 'Completa este campo'
              : null,
    ),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'label': _normalized(_label.text),
        'recipient': _normalized(_recipient.text),
        'street': _normalized(_street.text),
        'city': _normalized(_city.text),
        'province': _province,
        'postalCode': _postalCode.text,
        'phone': _phone.text,
        'isDefault': widget.isPrimary,
      };
      final id = widget.initialAddress?['id']?.toString();
      late final Map<String, dynamic> savedAddress;
      if (id == null) {
        savedAddress = await widget.repository.saveAddress(payload);
      } else {
        savedAddress = await widget.repository.updateAddress(id, payload);
      }
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.of(context).pop(savedAddress);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowedLetters = RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ' -]");
    final allowedStreet = RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ0-9#.,/' -]");
    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.initialAddress == null
                ? 'Nueva dirección'
                : 'Editar dirección',
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _field(
                _label,
                'Etiqueta',
                hint: 'Casa',
                formatters: [
                  _textFormatter(allowedStreet),
                  LengthLimitingTextInputFormatter(50),
                ],
              ),
              _field(
                _recipient,
                'Nombre de quien recibe',
                hint: 'Ej. Ana Pérez',
                formatters: [
                  _textFormatter(allowedLetters),
                  LengthLimitingTextInputFormatter(50),
                ],
                validator: _personValidator,
              ),
              _field(
                _street,
                'Calle y número',
                hint: 'Ej. Av. Amazonas N34-120',
                formatters: [
                  _textFormatter(allowedStreet),
                  LengthLimitingTextInputFormatter(50),
                ],
                validator: _streetValidator,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('province-$_province'),
                  initialValue: _province,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Provincia',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final province in _provinces)
                      DropdownMenuItem(value: province, child: Text(province)),
                  ],
                  onChanged: (value) => setState(() {
                    if (value != _province) _city.clear();
                    _otherCity = false;
                    _province = value;
                  }),
                  validator: (value) =>
                      value == null ? 'Selecciona una provincia' : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('city-$_province-${_city.text}'),
                  initialValue: _province == null
                      ? null
                      : (_otherCity
                            ? '__other__'
                            : (_city.text.isEmpty ? null : _city.text)),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ciudad',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final city
                        in _citiesByProvince[_province] ?? const <String>[])
                      DropdownMenuItem(value: city, child: Text(city)),
                    if (_province != null)
                      const DropdownMenuItem(
                        value: '__other__',
                        child: Text('Otra ciudad'),
                      ),
                  ],
                  onChanged: _province == null
                      ? null
                      : (value) => setState(() {
                          _otherCity = value == '__other__';
                          if (value != null && value != '__other__')
                            _city.text = value;
                          if (_otherCity) _city.clear();
                        }),
                  validator: (value) => _province == null
                      ? 'Selecciona primero una provincia'
                      : (value == null ? 'Selecciona una ciudad' : null),
                ),
              ),
              if (_otherCity)
                _field(
                  _city,
                  'Escribe tu ciudad',
                  hint: 'Ej. Shushufindi',
                  formatters: [
                    _textFormatter(allowedLetters),
                    LengthLimitingTextInputFormatter(50),
                  ],
                  validator: _personValidator,
                ),
              _field(
                _postalCode,
                'Código postal',
                hint: 'Ej. 170150',
                keyboard: TextInputType.number,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (value) =>
                    value == null || !RegExp(r'^\d{6}$').hasMatch(value)
                    ? 'El código postal debe tener 6 números'
                    : null,
              ),
              _field(
                _phone,
                'Teléfono',
                hint: '0991234567',
                keyboard: TextInputType.phone,
                formatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    final value = newValue.text;
                    if (value.isEmpty ||
                        value == '0' ||
                        value == '09' ||
                        RegExp(r'^09\d{0,8}$').hasMatch(value)) {
                      return newValue;
                    }
                    return oldValue;
                  }),
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (value) =>
                    value == null || !RegExp(r'^09\d{8}$').hasMatch(value)
                    ? 'Escribe un celular ecuatoriano de 10 dígitos que empiece con 09'
                    : null,
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _requestClose,
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
