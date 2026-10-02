import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/auth_session_service.dart';
import '../../theme/app_colors.dart';
import '../authentication/login_screen.dart';
import '../../services/buyer_catalog_service.dart';
import 'pages/buyer_account_page.dart';
import 'pages/buyer_empty_feature_page.dart';
import 'pages/buyer_catalog_page.dart';
import 'pages/buyer_cart_page.dart';
import 'pages/buyer_checkout_page.dart';
import 'pages/buyer_home_page.dart';
import 'pages/buyer_my_likes_page.dart';
import 'pages/buyer_product_detail_page.dart';
import 'widgets/buyer_bottom_navigation.dart';

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  bool _loading = true;
  bool _loggingOut = false;
  int _currentIndex = 0;
  int _likesRefreshVersion = 0;
  int _homeRefreshVersion = 0;
  String _token = '';
  String _email = '';
  String _displayName = 'Shopper';

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final session = await AuthSessionService.readSession().timeout(
        const Duration(seconds: 3),
      );

      if (!mounted) {
        return;
      }

      if (session == null || session.accountType != 'buyer') {
        await AuthSessionService.clearSession();
        _returnToLogin();
        return;
      }

      setState(() {
        _token = session.token;
        _email = session.email;
        _displayName = _fallbackNameFromEmail(session.email);
        _loading = false;
      });

      _refreshProfile(session.token);
    } catch (_) {
      if (!mounted) {
        return;
      }

      await AuthSessionService.clearSession();
      _returnToLogin();
    }
  }

  Future<void> _refreshProfile(String token) async {
    try {
      final result = await AuthService.me(token: token).timeout(
        const Duration(seconds: 8),
      );

      if (!mounted) {
        return;
      }

      if (!result.success) {
        if (result.statusCode == 401 || result.statusCode == 403) {
          await _expireSession();
        }
        return;
      }

      final accountType = result.data['account_type']?.toString();
      if (accountType != null && accountType != 'buyer') {
        await _expireSession();
        return;
      }

      final firstName = result.data['first_name']?.toString().trim();
      final email = result.data['email']?.toString().trim();

      if (!mounted) {
        return;
      }

      setState(() {
        if (email != null && email.isNotEmpty) {
          _email = email;
        }
        if (firstName != null && firstName.isNotEmpty) {
          _displayName = firstName;
        }
      });
    } catch (_) {
      // Keep Buyer Home usable if the profile refresh temporarily fails.
    }
  }

  Future<void> _expireSession() async {
    await AuthSessionService.clearSession();
    if (mounted) {
      _returnToLogin();
    }
  }

  String _fallbackNameFromEmail(String email) {
    final localPart = email.split('@').first.trim();

    if (localPart.isEmpty) {
      return 'Shopper';
    }

    final normalized = localPart
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');

    return normalized.isEmpty ? 'Shopper' : normalized;
  }

  Future<void> _logout() async {
    if (_loggingOut) {
      return;
    }

    setState(() {
      _loggingOut = true;
    });

    final token = await AuthSessionService.readToken();

    if (token != null && token.isNotEmpty) {
      await AuthService.logout(token: token);
    }

    await AuthSessionService.clearSession();

    if (!mounted) {
      return;
    }

    _returnToLogin();
  }

  void _returnToLogin() {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _openTab(int index) {
    if (index == _currentIndex) {
      return;
    }

    setState(() {
      _currentIndex = index;
      if (index == 1) {
        _likesRefreshVersion++;
      }
    });
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BuyerCatalogPage(
          token: _token,
          onSessionExpired: _expireSession,
          onOpenProduct: _openProduct,
        ),
      ),
    );
  }

  void _openCategory(BuyerCategoryData category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BuyerCatalogPage(
          token: _token,
          category: category,
          onSessionExpired: _expireSession,
          onOpenProduct: _openProduct,
        ),
      ),
    );
  }

  void _openProduct(BuyerProductData product) {
    _openProductById(product.id);
  }

  void _openProductById(int productId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BuyerProductDetailPage(
          token: _token,
          productId: productId,
          onSessionExpired: _expireSession,
          onOpenProduct: _openProduct,
          onOpenSearch: _openSearch,
          onOpenCart: _openCart,
          onCartCountChanged: _cartChanged,
        ),
      ),
    );
  }

  void _openCart({String? buyNowLineKey}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BuyerCartPage(
          token: _token,
          buyNowLineKey: buyNowLineKey,
          onSessionExpired: _expireSession,
          onOpenProductId: _openProductById,
          onContinueShopping: () {
            Navigator.of(context).maybePop();
            _openTab(0);
          },
          onCheckout: _openCheckout,
          onCartCountChanged: _cartChanged,
        ),
      ),
    );
  }

  void _openCheckout(Map<String, int> items) {
    if (items.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BuyerCheckoutPage(
          token: _token,
          items: items,
          onSessionExpired: _expireSession,
          onOrderPlaced: _orderPlaced,
          onCartCountChanged: _cartChanged,
        ),
      ),
    );
  }

  void _orderPlaced() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _currentIndex = 2;
      _homeRefreshVersion++;
    });
  }

  void _cartChanged(int _) {
    if (!mounted) return;
    setState(() => _homeRefreshVersion++);
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature will be connected to the ShopHop web backend next.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.grayBg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
      );
    }

    final pages = <Widget>[
      BuyerHomePage(
        key: ValueKey<String>('buyer-home-$_homeRefreshVersion'),
        token: _token,
        onSessionExpired: _expireSession,
        onOpenSearch: _openSearch,
        onOpenCategory: _openCategory,
        onOpenProduct: _openProduct,
        onOpenCart: () => _openCart(),
        onOpenOrders: () => _openTab(2),
        onOpenMessages: () => _showComingSoon('Chat/Messaging'),
      ),
      BuyerMyLikesPage(
        key: ValueKey<int>(_likesRefreshVersion),
        token: _token,
        onSessionExpired: _expireSession,
        onOpenSearch: _openSearch,
        onOpenCart: () => _openCart(),
        onOpenProduct: _openProduct,
      ),
      BuyerEmptyFeaturePage(
        title: 'My Orders',
        description:
            'Track orders from seller confirmation through pickup, sorting, delivery, and receipt confirmation.',
        icon: Icons.receipt_long_outlined,
        actionLabel: 'Browse Products',
        onAction: () => _openTab(0),
      ),
      BuyerEmptyFeaturePage(
        title: 'Notifications',
        description:
            'Order updates, seller confirmations, shipment events, and delivery alerts will appear here.',
        icon: Icons.notifications_none_rounded,
        actionLabel: 'Back to Home',
        onAction: () => _openTab(0),
      ),
      BuyerAccountPage(
        displayName: _displayName,
        email: _email,
        loggingOut: _loggingOut,
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.grayBg,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BuyerBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _openTab,
        notificationCount: 0,
      ),
    );
  }
}
