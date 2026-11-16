import 'package:shophop/features/buyer/presentation/widgets/buyer_page_chrome.dart';
import 'package:shophop/features/buyer/data/services/buyer_account_service.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_device_settings_page.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_messages_page.dart';
import 'package:flutter/material.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_profile_photo.dart';
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
    this.avatarUrl,
    this.onAvatarChanged,
  });
  final String displayName, token, email;
  final String? avatarUrl;
  final ValueChanged<String?>? onAvatarChanged;
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

  void _profileSaved(BuyerAccountProfile profile) {
    onDisplayNameChanged?.call(profile.name);
    onAvatarChanged?.call(profile.avatarUrl);
  }

  void _openSettings(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BuyerAccountSettingsPage(
        token: token,
        email: email,
        onSessionExpired: onSessionExpired,
        onProfileSaved: _profileSaved,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => BuyerScaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.page,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.navy,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 68,
      title: const Text(
        'Account',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      leadingWidth: 68,
      leading: Padding(
        padding: const EdgeInsets.only(left: 18),
        child: Center(
          child: _HeaderButton(
            icon: Icons.settings_outlined,
            tooltip: 'Account settings',
            onTap: () => _openSettings(context),
          ),
        ),
      ),
      actions: [
        _HeaderButton(
          icon: Icons.shopping_bag_outlined,
          tooltip: 'Shopping cart',
          onTap: onOpenCart,
        ),
        const SizedBox(width: 18),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(
            child: InkWell(
              key: const ValueKey('account-profile'),
              borderRadius: BorderRadius.circular(24),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BuyerAccountSecurityPage(
                    token: token,
                    onProfileSaved: _profileSaved,
                    onSessionExpired: onSessionExpired,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    BuyerProfilePhoto(token: token, url: avatarUrl, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Edit profile & photo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.pink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(26),
            ),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            child: Column(
              children: [
                InkWell(
                  onTap: () => onOpenOrders(null),
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'My purchases',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            'View all orders',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        constraints.maxWidth < 270 ||
                            MediaQuery.textScalerOf(context).scale(12) > 17
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
                      runSpacing: 14,
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
                                  vertical: 6,
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: .09,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        option.$3,
                                        color: const Color(0xFFFFA8BB),
                                        size: 23,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      option.$1,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
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
          const SizedBox(height: 22),
          const _GroupLabel('SHOPPING'),
          _Section(
            child: Column(
              children: [
                _AccountTile(
                  icon: Icons.favorite_border_rounded,
                  title: 'My likes',
                  onTap: onOpenLikes,
                ),
                const _MenuDivider(),
                _AccountTile(
                  icon: Icons.shopping_bag_outlined,
                  title: 'My cart',
                  onTap: onOpenCart,
                ),
                const _MenuDivider(),
                _AccountTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Messages',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BuyerMessagesPage(
                        token: token,
                        onSessionExpired: onSessionExpired,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _GroupLabel('ACCOUNT & PREFERENCES'),
          _Section(
            child: Column(
              children: [
                _AccountTile(
                  icon: Icons.settings_outlined,
                  title: 'Account settings',
                  onTap: () => _openSettings(context),
                ),
                const _MenuDivider(),
                _AccountTile(
                  icon: Icons.location_on_outlined,
                  title: 'Delivery addresses',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => BuyerAddressEditorPage(token: token),
                    ),
                  ),
                ),
                const _MenuDivider(),
                _AccountTile(
                  icon: Icons.tune_rounded,
                  title: 'Order preferences',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BuyerOrderSettingsPage(email: email),
                    ),
                  ),
                ),
                const _MenuDivider(),
                _AccountTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BuyerNotificationSettingsPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _GroupLabel('SUPPORT'),
          _Section(
            child: Column(
              children: [
                _AccountTile(
                  icon: Icons.shield_outlined,
                  title: 'Privacy & sign-in',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BuyerPrivacySettingsPage(),
                    ),
                  ),
                ),
                const _MenuDivider(),
                _AccountTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & support',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BuyerHelpPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _Section(
            child: _AccountTile(
              icon: Icons.logout_rounded,
              title: loggingOut ? 'Signing out...' : 'Sign out',
              destructive: true,
              onTap: loggingOut ? null : () => _confirmLogout(context),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'ShopHop ? A little hop, a better find.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon, size: 21),
    style: IconButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.navy,
      minimumSize: const Size(42, 42),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6, bottom: 10),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
    ),
  );
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(left: 52, right: 16),
    child: Divider(height: 1, thickness: .6, color: Color(0xFFEFEFF2)),
  );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.pink : AppColors.navy;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: destructive ? AppColors.pink : AppColors.textMuted,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (!destructive)
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}
