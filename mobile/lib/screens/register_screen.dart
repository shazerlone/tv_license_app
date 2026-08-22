// Registration now starts at AccountTypeScreen
export 'account_type_screen.dart' show AccountTypeScreen;

import 'package:flutter/material.dart';
import 'account_type_screen.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AccountTypeScreen();
  }
}
