import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/assets_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:interbridge/presentation/screens/auth/web/auth_web_palette.dart';
// IMPORTANT: Update this import path if your wrapper is in a different folder
import 'package:interbridge/presentation/screens/auth/web/auth_web_wrapper.dart'; 
import 'package:url_launcher/url_launcher.dart';

/// The Gateway screen utilizing the global AuthWebWrapper for its background.
class AuthSelectionWeb extends StatelessWidget {
  const AuthSelectionWeb({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Call the Global Wrapper
    return AuthWebWrapper(
      wrapInCard: false, // Tells the wrapper NOT to use the standard login box
      child: _buildGatewayCard(context),
    );
  }

  // 2. The Custom Split-Card Layout
  Widget _buildGatewayCard(BuildContext context) {
    return Container(
      width: 900,
      height: 600,
      decoration: BoxDecoration(
        color: AuthWebPalette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AuthWebPalette.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 1,
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
              child: Image.asset(
                'assets/images/welcome_hero.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AuthWebPalette.primary,
                    child: const Center(
                      child: Icon(Icons.language_rounded, size: 80, color: Colors.white24),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      _buildLogo(),
                      const SizedBox(width: 12),
                    const  Text(
                        'Interbridge',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AuthWebPalette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Bridging the World',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AuthWebPalette.textPrimary,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Access opportunities, build your experience, and become part of a growing global language network.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AuthWebPalette.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                            Routes.registerRoute,
                            arguments: {'role': 'interpreter'});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AuthWebPalette.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Join Our Interpreter Network',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(Routes.loginRoute);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AuthWebPalette.textPrimary,
                        side: const BorderSide(color: AuthWebPalette.border, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Sign In to Your Account',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildAcademyLink(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
          color: AuthWebPalette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AuthWebPalette.border)),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(ImageAssets.appIcon, fit: BoxFit.cover)),
    );
  }

  Widget _buildAcademyLink() {
    return Center(
      child: TextButton(
        onPressed: () async {
          final Uri url = Uri.parse('https://interbridge-ling.com/our-services/imia-accredited-medical-and-community-interpreting-diploma/');
          try {
            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
              debugPrint('Could not launch $url');
            }
          } catch (e) {
            debugPrint('Error launching URL: $e');
          }
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          foregroundColor: AuthWebPalette.primary,
        ),
        child: const Text(
          'Want to be an interpreter?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}