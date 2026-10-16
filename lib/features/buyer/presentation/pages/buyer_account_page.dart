import 'package:shophop/features/buyer/presentation/pages/buyer_address_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/shared/widgets/shop_hop_ui.dart';

class BuyerAccountPage extends StatelessWidget {
  const BuyerAccountPage({
    super.key,
    required this.displayName,
    required this.token,
    required this.email,
    required this.loggingOut,
    required this.onLogout,
  });

  final String displayName;
  final String token;
  final String email;
  final bool loggingOut;
  final VoidCallback onLogout;

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
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          const Text(
            'My account',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 23,
              letterSpacing: -.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Profile and account preferences',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.navy.withValues(alpha: .57),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.tealDark,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .72),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const ShopHopSectionHeading(
            title: 'Manage your account',
            subtitle: 'Additional self-service options are being connected.',
          ),
          const SizedBox(height: 12),
          _AccountTile(
            icon: Icons.location_on_outlined,
            title: 'Delivery addresses',
            subtitle: 'Edit the default address used for new orders',
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BuyerAddressEditorPage(token: token),
              ));
            },
          ),
          const _AccountTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Messages',
            subtitle: 'Talk to shops and support',
          ),
          const _AccountTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & support',
            subtitle: 'Get help with your orders',
          ),
          const _AccountTile(
            icon: Icons.settings_outlined,
            title: 'Account settings',
            subtitle: 'Your profile and preferences',
          ),
          const SizedBox(height: 16),
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
                  : const Icon(Icons.logout_rounded, size: 19),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ?? () {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text('$title is not connected in the mobile app yet.')),
              );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.grayBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: AppColors.tealDark, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.navy.withValues(alpha: .54),
                          fontSize: 10.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF526177)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
