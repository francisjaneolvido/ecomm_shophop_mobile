import 'package:shophop/features/buyer/presentation/widgets/buyer_icon_tile.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_messages_page.dart';
import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_address_editor_page.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_account_settings_page.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';

class BuyerAccountPage extends StatelessWidget {
  const BuyerAccountPage({
    super.key,
    required this.displayName,
    required this.token,
    required this.email,
    required this.loggingOut,
    required this.onLogout,
    required this.onOpenOrders,
    required this.onOpenLikes,
    required this.onOpenCart,
    this.onDisplayNameChanged,
    this.onSessionExpired,
  });
  final String displayName, token, email;
  final bool loggingOut;
  final VoidCallback onLogout, onOpenLikes, onOpenCart;
  final ValueChanged<String?> onOpenOrders;
  final ValueChanged<String>? onDisplayNameChanged;
  final Future<void> Function()? onSessionExpired;

  Future<void> _confirmLogout(BuildContext context) async {
    if (loggingOut) return;
    final confirmed = await showShopHopConfirmation(
      context,
      title: 'Sign out of ShopHop?',
      message: 'You can sign back in anytime to continue shopping.',
      confirmLabel: 'Sign out',
    );
    if (confirmed) onLogout();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 28),
    children: [
      Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navy, Color(0xFF303C67)],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'My account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.5,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'My cart',
                    onPressed: onOpenCart,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .10),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .16),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size(46, 46),
                    ),
                    icon: const Icon(
                      Icons.shopping_bag_outlined,
                      size: 23,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.pinkSoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: AppColors.navy,
                      size: 38,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          email,
                          style: const TextStyle(
                            color: Color(0xFFD9DDEA),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Column(
          children: [
            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('My purchases'),
                  InkWell(
                    onTap: () => onOpenOrders(null),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'View all orders',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final largeText =
                          MediaQuery.textScalerOf(context).scale(12) > 17;
                      final columns = constraints.maxWidth < 300 || largeText
                          ? 2
                          : 4;
                      const options = [
                        ('To ship', 'to-ship', Icons.inventory_2_outlined),
                        (
                          'To receive',
                          'to-receive',
                          Icons.local_shipping_outlined,
                        ),
                        ('To rate', 'to-rate', Icons.star_outline_rounded),
                        ('Completed', 'completed', Icons.verified_outlined),
                      ];
                      return Wrap(
                        spacing: 8,
                        runSpacing: 12,
                        children: [
                          for (final option in options)
                            SizedBox(
                              width:
                                  (constraints.maxWidth - (columns - 1) * 8) /
                                  columns,
                              child: InkWell(
                                key: ValueKey('account-${option.$2}'),
                                onTap: () => onOpenOrders(option.$2),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Column(
                                    children: [
                                      _AccountIcon(
                                        icon: option.$3,
                                        prominent: true,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        option.$1,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.navy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('My shopping'),
                  const SizedBox(height: 8),
                  _AccountTile(
                    icon: Icons.favorite_border,
                    title: 'My likes',
                    subtitle: 'Products you saved for later',
                    onTap: onOpenLikes,
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _AccountTile(
                    icon: Icons.shopping_bag_outlined,
                    title: 'My cart',
                    subtitle: 'Continue with your selected items',
                    onTap: onOpenCart,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('My account'),
                  const SizedBox(height: 8),
                  _AccountTile(
                    icon: Icons.location_on_outlined,
                    title: 'Delivery addresses',
                    subtitle: 'Manage your default delivery address',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BuyerAddressEditorPage(token: token),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _AccountTile(
                    icon: Icons.chat_bubble_outline,
                    title: 'Messages',
                    subtitle: 'Your conversations with shops',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => BuyerMessagesPage(
                          token: token,
                          onSessionExpired: onSessionExpired,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  const _AccountTile(
                    icon: Icons.help_outline,
                    title: 'Help & support',
                    subtitle: 'Get help with your orders',
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _AccountTile(
                    icon: Icons.settings_outlined,
                    title: 'Account settings',
                    subtitle: 'Edit your profile and password',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BuyerAccountSettingsPage(
                          token: token,
                          email: email,
                          onSessionExpired: onSessionExpired,
                          onProfileSaved: (profile) =>
                              onDisplayNameChanged?.call(profile.name),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: loggingOut ? null : () => _confirmLogout(context),
                icon: loggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_outlined, size: 20),
                label: Text(loggingOut ? 'Signing out...' : 'Sign out'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.navy,
    ),
  );
}

class _AccountIcon extends StatelessWidget {
  const _AccountIcon({required this.icon, this.prominent = false});

  final IconData icon;
  final bool prominent;

  @override
  Widget build(BuildContext context) => BuyerIconTile(
    icon: icon,
    dimension: prominent ? 52 : 44,
    iconSize: prominent ? 26 : 24,
  );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap:
        onTap ??
        () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('$title is not connected in the mobile app yet.'),
              ),
            );
        },
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          _AccountIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 14, color: AppColors.textMuted),
        ],
      ),
    ),
  );
}
