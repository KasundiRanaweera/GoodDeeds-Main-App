import 'package:flutter/material.dart';

import '../widgets/safe_avatar.dart';
import 'login_screen.dart';
import 'register_screen.dart';

const _kPrimaryColor = Color(0xFF0DF233);
const _kBackgroundLight = Color(0xFFF8F6F6);
const _kBackgroundDark = Color(0xFF221610);

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? _kBackgroundDark : _kBackgroundLight;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _kPrimaryColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: _kPrimaryColor.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.volunteer_activism,
                            color: Colors.black,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'GoodDeeds',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _HeroImage(isWide: isWide),
                        const SizedBox(height: 28),
                        Text(
                          'Track your good deeds.\nInspire the world.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Welcome to GoodDeeds',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isWide ? 44 : 36,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 540),
                          child: Text(
                            'Join events, support communities, and inspire others through your actions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                              fontSize: isWide ? 18 : 16,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FilledButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const LoginScreen(),
                                        ),
                                      );
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _kPrimaryColor,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const RegisterScreen(),
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark
                                          ? Colors.white
                                          : Colors.black,
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade300,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text(
                                      'Register',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 30),
                              Column(
                                children: [
                                  _AvatarStack(isDark: isDark),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Join 2,000+ others helping their local community',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[600],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                  const Divider(height: 0),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 20,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _FooterLink(label: 'Privacy', onTap: () {}),
                            const SizedBox(width: 24),
                            _FooterLink(label: 'Terms', onTap: () {}),
                            const SizedBox(width: 24),
                            _FooterLink(label: 'Support', onTap: () {}),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '© 2026 GoodDeeds. All rights reserved.',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 250,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuDfL5IgjyvQa2lF6bMFxcUGnr2B2OPhWwEWMNvYQRHZuwaheYvJ7fnL2cpdsNAGnu0-FixetBAJveFmQPiHjSSvGLK2isKrryxmzyCDU-StKh9QUWgGlmdr2d1SEFFdv_0sw3afUbJerul1LhHtrj_IShbrMhvAeulV26MZByu7kvod1gRFjlHgKiw5gYixtup7yjthLVSfl40AcywABEx8aoYfDrT3RR1QoUrfepsS63vnG5mmnI4d_wX7YuX2QXzr4b2jMBF632I',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black38, Colors.transparent],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.isDark});

  final bool isDark;
  static const double _avatarSpacing = 28;
  static const double _avatarRadius = 20;
  static const double _badgeSize = 40;

  static const _avatars = [
    'https://lh3.googleusercontent.com/aida-public/AB6AXuC3GO1QtXSC2SUr0HfPtYlO4_mjj6zTR3xPgbsetyI4FbIz_81CqGNhUg3iI6VDEXnUdvLAOrm3Pp6bZI42ng183f2fy6P4tuY1EcIwxwiD755hbQJzJL6R6EjVNAl2ppQB7Iqs14R5eMkn4D97fRtCrE_r0EjGZxRowNZTMtHNJD3HHoBmY6id9WefkHMPjYxoXno7AmuZQycxGWRpX7q7JabX9nEZ2urlZbv48zl18ffjQD-mFV7efAL7Yph8rR26lDGR9T-asnY',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuA-YS_o1qoLZI4wf5YBUGyFveOkuaTA1vK9Gql_1KhbGbQspASf23lhEbTHQq-l9cfZQ_J4CokL5Zfw9lPFSRzPPQ7Za9gM8CgdFkCePj4mOaVLqlloJzRwFUUEcCk7_PQYlDm2V6a31tSJHwaocos5HzVMcHeqI7Vft1te-3MsNoXgTmsFM6G9lNMp-Lek1KfZbo250y0smYF7FAbWYvW7ByhsqRr_DKmFxpdMb1b8irnO72dSSMcDdULL1I4os2KQ19CN8T25tCA',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuCojX8Jks4QNkWaErWYJm8hg8CO8alcxEo4nGTaF-qJrSvaVoD5iPGONR3braQI3t4cAKt4Lht-YsvjZrlOIWBtdc14tBxUmhff6YmVbMCnzeJ_aKWq9HmuQNvI5VUZsk4DovPBoegEcRSgBqk7kiET1NiwV6ppgL_4AeWFKMHHCeWjSpOqIDy9fQC2M7LPfgwK0Kl0UaZd_FLZMPlNTfc3C4h7zkIhz3pnfSFXOzpiIZ6t4cktz8gbLg9W5J4mW5ob9gmz4kFoUSg',
  ];

  @override
  Widget build(BuildContext context) {
    final stackWidth =
        (_avatars.length - 1) * _avatarSpacing +
        (_avatarRadius * 2) +
        _badgeSize;

    return SizedBox(
      width: stackWidth,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < _avatars.length; i++)
            Positioned(
              left: i * _avatarSpacing,
              child: SafeAvatar(
                radius: _avatarRadius,
                backgroundColor: isDark
                    ? (Colors.grey[900] ?? Colors.black)
                    : Colors.white,
                imageUrl: _avatars[i],
                iconSize: 18,
                iconColor: isDark ? Colors.grey[400]! : Colors.grey[600]!,
              ),
            ),
          Positioned(
            left: (_avatars.length - 1) * _avatarSpacing + (_avatarRadius * 2),
            child: Container(
              width: _badgeSize,
              height: _badgeSize,
              decoration: BoxDecoration(
                color: _kPrimaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? _kBackgroundDark : _kBackgroundLight,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '+2k',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
