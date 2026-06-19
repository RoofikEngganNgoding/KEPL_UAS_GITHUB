import 'package:flutter/material.dart';

import 'app_theme.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _page = 0;

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      icon: Icons.delete_outline,
      title: 'Jual Sampah dengan Mudah',
      description:
          'Pilih jenis sampah seperti plastik, kertas, logam, dan botol.',
      color: AppTheme.primary,
    ),
    _OnboardingItem(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Dapatkan Saldo Digital',
      description: 'Sampah yang sudah diverifikasi akan berubah menjadi saldo.',
      color: AppTheme.info,
    ),
    _OnboardingItem(
      icon: Icons.public_outlined,
      title: 'Bantu Lingkungan Lebih Bersih',
      description: 'Setiap kilogram sampah yang dikelola ikut menjaga bumi.',
      color: AppTheme.orange,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _next() {
    if (_page == _items.length - 1) {
      _goToLogin();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGreen,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _goToLogin,
                  child: const Text('Lewati'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _items.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _FloatingEcoIcon(item: item),
                        const SizedBox(height: 42),
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.darkText,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          item.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.greyText,
                            fontSize: 16,
                            height: 1.45,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _items.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: _page == index ? 28 : 9,
                    height: 9,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _page == index
                          ? AppTheme.primary
                          : AppTheme.primary.withAlpha(55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _next,
                child: Text(
                  _page == _items.length - 1 ? 'Mulai Sekarang' : 'Lanjut',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingEcoIcon extends StatefulWidget {
  const _FloatingEcoIcon({required this.item});

  final _OnboardingItem item;

  @override
  State<_FloatingEcoIcon> createState() => _FloatingEcoIconState();
}

class _FloatingEcoIconState extends State<_FloatingEcoIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  late final Animation<double> _float = Tween<double>(
    begin: -8,
    end: 8,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _float.value),
          child: child,
        );
      },
      child: Container(
        width: 210,
        height: 210,
        decoration: BoxDecoration(
          color: widget.item.color.withAlpha(24),
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 26,
              top: 36,
              child: Icon(
                Icons.eco,
                color: widget.item.color.withAlpha(125),
                size: 30,
              ),
            ),
            Positioned(
              right: 30,
              bottom: 38,
              child: Icon(
                Icons.energy_savings_leaf_outlined,
                color: widget.item.color.withAlpha(120),
                size: 28,
              ),
            ),
            Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                color: widget.item.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.item.color.withAlpha(65),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Icon(widget.item.icon, color: Colors.white, size: 58),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
}
