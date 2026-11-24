import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'application/auth_use_cases.dart';
import 'application/cart_use_cases.dart';
import 'application/checkout_use_cases.dart';
import 'application/get_categories.dart';
import 'application/get_products.dart';
import 'application/order_use_cases.dart';
import 'infrastructure/api_auth_repository.dart';
import 'infrastructure/api_checkout_repository.dart';
import 'infrastructure/api_cart_repository.dart';
import 'infrastructure/api_config.dart';
import 'infrastructure/api_category_repository.dart';
import 'infrastructure/api_order_repository.dart';
import 'infrastructure/api_customer_features_repository.dart';
import 'infrastructure/api_product_repository.dart';
import 'infrastructure/local_cart_repository.dart';
import 'infrastructure/stripe_checkout_config.dart';
import 'presentation/main_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (stripePublishableKey.isNotEmpty) {
    Stripe.publishableKey = stripePublishableKey;
    Stripe.urlScheme = 'entrecumbres';
    Stripe.setReturnUrlSchemeOnAndroid = true;
    await Stripe.instance.applySettings();
  }

  final baseUrl = apiBaseUrl;

  // 1. Capa de Infraestructura (Adaptadores HTTP y Almacenamiento)
  final productRepo = ApiProductRepository(baseUrl: baseUrl);
  final categoryRepo = ApiCategoryRepository(baseUrl: baseUrl);
  final authRepo = ApiAuthRepository(baseUrl: baseUrl);
  await authRepo.restoreSession();
  final customerFeaturesRepo = ApiCustomerFeaturesRepository(
    authRepo,
    baseUrl: baseUrl,
  );
  final orderRepo = ApiOrderRepository(authRepo, baseUrl: baseUrl);
  final checkoutRepo = ApiCheckoutRepository(authRepo, baseUrl: baseUrl);
  final localCartRepo = LocalCartRepository();
  final cartRepo = ApiCartRepository(local: localCartRepo, auth: authRepo);

  // 2. Capa de Aplicación (Casos de Uso)
  final getProducts = GetProducts(productRepo);
  final getProductDetail = GetProductDetail(productRepo);
  final getCategories = GetCategories(categoryRepo);

  final getCart = GetCart(cartRepo);
  final addProductToCart = AddProductToCart(cartRepo);
  final setCartQuantity = SetCartQuantity(cartRepo);
  final removeProductFromCart = RemoveProductFromCart(cartRepo);
  final clearCart = ClearCart(cartRepo);

  final registerCustomer = RegisterCustomerUseCase(authRepo);
  final loginCustomer = LoginCustomerUseCase(authRepo);
  final updateCustomerProfile = UpdateCustomerProfileUseCase(authRepo);
  final logoutCustomer = LogoutCustomerUseCase(authRepo);
  final getCurrentCustomer = GetCurrentCustomerUseCase(authRepo);

  final startCheckout = StartCheckoutUseCase(checkoutRepo);
  final getCheckoutStatus = GetCheckoutStatusUseCase(checkoutRepo);
  final getCustomerOrders = GetCustomerOrdersUseCase(orderRepo);
  final getOrderDetail = GetOrderDetailUseCase(orderRepo);
  final markOrderReceived = MarkOrderReceivedUseCase(orderRepo);

  // 3. Capa de Presentación
  runApp(
    ECommerceApp(
      getProducts: getProducts,
      getProductDetail: getProductDetail,
      getCategories: getCategories,
      getCart: getCart,
      addProductToCart: addProductToCart,
      setCartQuantity: setCartQuantity,
      removeProductFromCart: removeProductFromCart,
      clearCart: clearCart,
      registerCustomer: registerCustomer,
      loginCustomer: loginCustomer,
      updateCustomerProfile: updateCustomerProfile,
      logoutCustomer: logoutCustomer,
      getCurrentCustomer: getCurrentCustomer,
      startCheckout: startCheckout,
      getCheckoutStatus: getCheckoutStatus,
      getCustomerOrders: getCustomerOrders,
      getOrderDetail: getOrderDetail,
      markOrderReceived: markOrderReceived,
      syncAccountCart: cartRepo.syncFromAccount,
      customerFeaturesRepository: customerFeaturesRepo,
    ),
  );
}

class ECommerceApp extends StatefulWidget {
  const ECommerceApp({
    required this.getProducts,
    required this.getProductDetail,
    required this.getCategories,
    required this.getCart,
    required this.addProductToCart,
    required this.setCartQuantity,
    required this.removeProductFromCart,
    required this.clearCart,
    required this.registerCustomer,
    required this.loginCustomer,
    required this.updateCustomerProfile,
    required this.logoutCustomer,
    required this.getCurrentCustomer,
    required this.startCheckout,
    required this.getCheckoutStatus,
    required this.getCustomerOrders,
    required this.getOrderDetail,
    required this.markOrderReceived,
    required this.syncAccountCart,
    required this.customerFeaturesRepository,
    super.key,
  });

  final GetProducts getProducts;
  final GetProductDetail getProductDetail;
  final GetCategories getCategories;
  final GetCart getCart;
  final AddProductToCart addProductToCart;
  final SetCartQuantity setCartQuantity;
  final RemoveProductFromCart removeProductFromCart;
  final ClearCart clearCart;
  final RegisterCustomerUseCase registerCustomer;
  final LoginCustomerUseCase loginCustomer;
  final UpdateCustomerProfileUseCase updateCustomerProfile;
  final LogoutCustomerUseCase logoutCustomer;
  final GetCurrentCustomerUseCase getCurrentCustomer;
  final StartCheckoutUseCase startCheckout;
  final GetCheckoutStatusUseCase getCheckoutStatus;
  final GetCustomerOrdersUseCase getCustomerOrders;
  final GetOrderDetailUseCase getOrderDetail;
  final MarkOrderReceivedUseCase markOrderReceived;
  final Future<void> Function() syncAccountCart;
  final ApiCustomerFeaturesRepository customerFeaturesRepository;

  @override
  State<ECommerceApp> createState() => _ECommerceAppState();
}

class _ECommerceAppState extends State<ECommerceApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ENTRE CUMBRES',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF246B5A)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF246B5A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121816),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      home: MainScaffold(
        getProducts: widget.getProducts,
        getProductDetail: widget.getProductDetail,
        getCategories: widget.getCategories,
        getCart: widget.getCart,
        addProductToCart: widget.addProductToCart,
        setCartQuantity: widget.setCartQuantity,
        removeProductFromCart: widget.removeProductFromCart,
        clearCart: widget.clearCart,
        startCheckout: widget.startCheckout,
        getCheckoutStatus: widget.getCheckoutStatus,
        getCustomerOrders: widget.getCustomerOrders,
        getOrderDetail: widget.getOrderDetail,
        markOrderReceived: widget.markOrderReceived,
        loginCustomer: widget.loginCustomer,
        updateCustomerProfile: widget.updateCustomerProfile,
        registerCustomer: widget.registerCustomer,
        logoutCustomer: widget.logoutCustomer,
        getCurrentCustomer: widget.getCurrentCustomer,
        syncAccountCart: widget.syncAccountCart,
        customerFeaturesRepository: widget.customerFeaturesRepository,
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: () => setState(() {
          _themeMode = _themeMode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark;
        }),
      ),
    );
  }
}
