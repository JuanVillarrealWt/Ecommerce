import 'package:flutter/material.dart';

import 'application/auth_use_cases.dart';
import 'application/cart_use_cases.dart';
import 'application/get_categories.dart';
import 'application/get_products.dart';
import 'application/order_use_cases.dart';
import 'infrastructure/api_auth_repository.dart';
import 'infrastructure/api_category_repository.dart';
import 'infrastructure/api_order_repository.dart';
import 'infrastructure/api_product_repository.dart';
import 'infrastructure/in_memory_cart_repository.dart';
import 'presentation/main_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Capa de Infraestructura (Adaptadores HTTP y Almacenamiento)
  final productRepo = ApiProductRepository();
  final categoryRepo = ApiCategoryRepository();
  final authRepo = ApiAuthRepository();
  final orderRepo = ApiOrderRepository(authRepo);
  final cartRepo = InMemoryCartRepository();

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
  final logoutCustomer = LogoutCustomerUseCase(authRepo);
  final getCurrentCustomer = GetCurrentCustomerUseCase(authRepo);

  final createOrder = CreateOrderUseCase(orderRepo);
  final getCustomerOrders = GetCustomerOrdersUseCase(orderRepo);
  final getOrderDetail = GetOrderDetailUseCase(orderRepo);

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
      logoutCustomer: logoutCustomer,
      getCurrentCustomer: getCurrentCustomer,
      createOrder: createOrder,
      getCustomerOrders: getCustomerOrders,
      getOrderDetail: getOrderDetail,
    ),
  );
}

class ECommerceApp extends StatelessWidget {
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
    required this.logoutCustomer,
    required this.getCurrentCustomer,
    required this.createOrder,
    required this.getCustomerOrders,
    required this.getOrderDetail,
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
  final LogoutCustomerUseCase logoutCustomer;
  final GetCurrentCustomerUseCase getCurrentCustomer;
  final CreateOrderUseCase createOrder;
  final GetCustomerOrdersUseCase getCustomerOrders;
  final GetOrderDetailUseCase getOrderDetail;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Commerce Odoo',
      debugShowCheckedModeBanner: false,
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
      home: MainScaffold(
        getProducts: getProducts,
        getCategories: getCategories,
        getCart: getCart,
        addProductToCart: addProductToCart,
        setCartQuantity: setCartQuantity,
        removeProductFromCart: removeProductFromCart,
        clearCart: clearCart,
        createOrder: createOrder,
        getCustomerOrders: getCustomerOrders,
        getOrderDetail: getOrderDetail,
        loginCustomer: loginCustomer,
        registerCustomer: registerCustomer,
        logoutCustomer: logoutCustomer,
        getCurrentCustomer: getCurrentCustomer,
      ),
    );
  }
}
