class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.partnerId,
    this.province = '',
    this.phone = '',
  });

  final int id;
  final String name;
  final String email;
  final int partnerId;
  final String province;
  final String phone;
}

