import 'package:flutter/material.dart';
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/core/theme/app_colors.dart';

class BuyerProfilePhoto extends StatelessWidget {
  const BuyerProfilePhoto({
    super.key,
    required this.token,
    this.url,
    this.size = 52,
  });
  final String token;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      Icons.person_outline,
      color: AppColors.pink,
      size: size * .55,
    );
    return Semantics(
      label: 'Buyer profile photo',
      image: true,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: ColoredBox(
            color: AppColors.pinkSoft,
            child: url?.isNotEmpty == true
                ? Image.network(
                    ApiConfig.resolveMediaUrl(url),
                    headers: {'Authorization': 'Bearer $token'},
                    fit: BoxFit.cover,
                    cacheWidth: 256,
                    loadingBuilder: (_, child, progress) =>
                        progress == null ? child : placeholder,
                    errorBuilder: (_, error, stack) => placeholder,
                  )
                : placeholder,
          ),
        ),
      ),
    );
  }
}
