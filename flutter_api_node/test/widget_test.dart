import 'package:flutter/material.dart';
import 'package:flutter_api_node/app_theme.dart';
import 'package:flutter_api_node/main.dart';
import 'package:flutter_api_node/login_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders the bank sampah splash screen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const BankSampahApp(isLoggedIn: false));
    await tester.pump();

    expect(find.text('Bank Sampah Digital'), findsOneWidget);
    expect(find.byIcon(Icons.recycling_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('login only exposes implemented authentication methods', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.theme, home: const LoginPage()),
    );

    expect(find.text('Masuk ke Akun'), findsOneWidget);
    expect(find.text('Pindai Wajah Otomatis'), findsOneWidget);
    expect(find.text('Daftar'), findsNothing);
  });
}
