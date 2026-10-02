import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class BuyerAccountPage extends StatelessWidget {
  const BuyerAccountPage({
    super.key,
    required this.displayName,
    required this.email,
    required this.loggingOut,
    required this.onLogout,
  });

  final String displayName;
  final String email;
  final bool loggingOut;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          const Text(
            'My Account',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.grayBorder),
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
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.navy.withValues(alpha: 0.48),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _AccountTile(
            icon: Icons.location_on_outlined,
            title: 'Delivery Addresses',
            subtitle: 'Manage your saved delivery address',
          ),
          const _AccountTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Messages',
            subtitle: 'Chat with sellers and support',
          ),
          const _AccountTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: 'Complaints, disputes, and assistance',
          ),
          const _AccountTile(
            icon: Icons.settings_outlined,
            title: 'Account Settings',
            subtitle: 'Manage your ShopHop profile',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: loggingOut ? null : onLogout,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              side: const BorderSide(color: AppColors.grayBorder),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: loggingOut
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded, size: 19),
            label: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w800),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.tealDark),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: AppColors.navy.withValues(alpha: 0.45),
            fontSize: 10,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
        onTap: () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('$title will be connected in the next Buyer module.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
        },
      ),
    );
  }
}
