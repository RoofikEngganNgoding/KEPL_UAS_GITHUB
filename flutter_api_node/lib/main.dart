import 'package:flutter/material.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'login_page.dart'; 
import 'dashboard_page.dart'; 
Future<void> main() async { 
// Pastikan inisialisasi Flutter sudah siap 
  WidgetsFlutterBinding.ensureInitialized(); 
 
  // Ambil data token dari SharedPreferences 
  final prefs = await SharedPreferences.getInstance(); 
  final String? token = prefs.getString('token'); 
 
  // Jalankan aplikasi dengan membawa informasi status login 
  runApp(BankSampahApp(isLoggedIn: token != null)); 
} 
class BankSampahApp extends StatelessWidget { 
  const BankSampahApp({super.key, required this.isLoggedIn}); 
  final bool isLoggedIn; 
  @override 
  Widget build(BuildContext context) { 
    return MaterialApp( 
      title: 'Bank Sampah Sungailiat', 
      debugShowCheckedModeBanner: false, 
      theme: ThemeData( 
        primarySwatch: Colors.green, // Tema warna hijau khas bank sampah 
        useMaterial3: true, 
      ), 
      // Rute awal diarahkan ke halaman login 
      initialRoute: isLoggedIn ? '/dashboard' : '/', 
      routes: { 
        '/': (context) => LoginPage(), 
        '/dashboard': (context) => DashboardPage(), 
      }, 
    ); 
  } 
} 