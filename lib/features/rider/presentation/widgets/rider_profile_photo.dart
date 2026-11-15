import 'package:flutter/material.dart';
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/core/theme/app_colors.dart';

class RiderProfilePhoto extends StatelessWidget {
  const RiderProfilePhoto({
    super.key,
    required this.token,
    this.url,
    this.size = 48,
    this.circular = false,
  });
  final String token;
  final String? url;
  final double size;
  final bool circular;
  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      Icons.person_outline,
      color: AppColors.pink,
      size: size * .55,
    );
    final content = SizedBox(
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
                errorBuilder: (_, _, _) => placeholder,
              )
            : placeholder,
      ),
    );
    return Semantics(
      label: 'Rider profile photo',
      image: true,
      child: circular
          ? ClipOval(child: content)
          : ClipRRect(borderRadius: BorderRadius.circular(8), child: content),
    );
  }
}
