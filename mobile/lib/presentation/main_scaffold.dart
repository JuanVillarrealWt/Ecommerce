import 'dart:async';

import 'package:flutter/material.dart';

import '../application/auth_use_cases.dart';
import '../application/cart_use_cases.dart';
import '../application/get_categories.dart';
import '../application/get_products.dart';
import '../application/order_use_cases.dart';
import 'auth_page.dart';
import 'catalog_page.dart';
import 'orders_page.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({
    required this.getProducts,
    required this.getCategories,
    required this.getCart,
    required this.addProductToCart,
    required this.setCartQuantity,
    required this.removeProductFromCart,
    required this.clearCart,
    required this.createOrder,
    required this.getCustomerOrders,
    required this.getOrderDetail,
    required this.loginCustomer,
    required this.registerCustomer,
    required this.logoutCustomer,
    required this.getCurrentCustomer,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.syncAccountCart,
    super.key,
  });

  final GetProducts getProducts;
  final GetCategories getCategories;
  final GetCart getCart;
  final AddProductToCart addProductToCart;
  final SetCartQuantity setCartQuantity;
  final RemoveProductFromCart removeProductFromCart;
  final ClearCart clearCart;
  final CreateOrderUseCase createOrder;
  final GetCustomerOrdersUseCase getCustomerOrders;
  final GetOrderDetailUseCase getOrderDetail;
  final LoginCustomerUseCase loginCustomer;
  final RegisterCustomerUseCase registerCustomer;
  final LogoutCustomerUseCase logoutCustomer;
  final GetCurrentCustomerUseCase getCurrentCustomer;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final Future<void> Function() syncAccountCart;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  int _cartSyncVersion = 0;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  void _onAuthSuccess() {
    _navigateToTab(0);
    unawaited(_syncAccountCart());
  }

  Future<void> _syncAccountCart() async {
    try {
      await widget.syncAccountCart();
      if (mounted) setState(() => _cartSyncVersion++);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo actualizar el carrito de tu cuenta.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CatalogPage(
        cartSyncVersion: _cartSyncVersion,
        getProducts: widget.getProducts,
        getCategories: widget.getCategories,
        getCart: widget.getCart,
        addProductToCart: widget.addProductToCart,
        setCartQuantity: widget.setCartQuantity,
        removeProductFromCart: widget.removeProductFromCart,
        clearCart: widget.clearCart,
        createOrder: widget.createOrder,
        getCurrentCustomer: widget.getCurrentCustomer,
        onNavigateToAuth: () => _navigateToTab(2),
        onNavigateToOrders: () => _navigateToTab(1),
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
      ),
      OrdersPage(
        getCustomerOrders: widget.getCustomerOrders,
        getOrderDetail: widget.getOrderDetail,
        getCurrentCustomer: widget.getCurrentCustomer,
        onNavigateToAuth: () => _navigateToTab(2),
      ),
      AuthPage(
        loginCustomer: widget.loginCustomer,
        registerCustomer: widget.registerCustomer,
        logoutCustomer: widget.logoutCustomer,
        getCurrentCustomer: widget.getCurrentCustomer,
        onAuthSuccess: _onAuthSuccess,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _navigateToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Catálogo',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Mis Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Mi Cuenta',
          ),
        ],
      ),
    );
  }
}
