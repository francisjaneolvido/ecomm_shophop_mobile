import 'package:flutter/material.dart';

import '../../buyer/buyer_home_screen.dart';

/// Backward-compatible entry point kept for older references.
/// New buyer logins now open [BuyerHomeScreen] directly.
class BuyerSessionScreen extends StatelessWidget {
  const BuyerSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BuyerHomeScreen();
  }
}
