import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:disaster/domain/entities/location_record.dart';
import 'package:disaster/presentation/providers/app_controller.dart';
import 'package:disaster/presentation/navigation/root_navigation.dart';
import 'package:disaster/presentation/screens/location/location_picker_screen.dart';
import 'package:disaster/presentation/theme/app_theme.dart';

/// First-run onboarding with permission requests (notifications + location).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _manualChosen = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final app = context.read<AppController>();
    await app.requestNotificationPermission();
    if (!_manualChosen) await app.requestGpsPermission();
    if (!mounted) return;
    await app.setOnboardingDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RootNavigation()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (p) => setState(() => _page = p),
                children: _pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? AppTheme.danger
                            : AppTheme.danger.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  const Spacer(),
                  if (!isLast)
                    TextButton(
                      onPressed: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeIn,
                      ),
                      child: const Text('Next'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _finish,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Get started'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  late final List<Widget> _pages = [
    _OnboardPage(
      icon: Icons.crisis_alert,
      color: AppTheme.danger,
      title: 'Real-time disaster alerts',
      body:
          'Earthquake, flood, cyclone, tsunami, wildfire, storm and more are '
          'pushed live to your device as soon as they are detected.',
    ),
    _OnboardPage(
      icon: Icons.my_location,
      color: AppTheme.safe,
      title: 'Personal safety radius',
      body:
          'We use your GPS location and calculate your distance to every '
          'active event so you always know if you are safe, warned, in danger '
          'or in a critical zone.',
    ),
    _OnboardPage(
      icon: Icons.sos,
      color: AppTheme.warningA,
      title: 'One-tap SOS',
      body:
          'Share your live location and alert your emergency contacts '
          'instantly. Works even when you are offline by queueing the alert.',
    ),
    _LocationChoicePage(
      onSetManual: _setManualLocation,
    ),
    _OnboardPage(
      icon: Icons.notifications_active,
      color: AppTheme.info,
      title: 'Grant permissions',
      body:
          'For alerts to reach you we need notification and location '
          'permission. You can adjust this anytime in Settings.',
    ),
  ];

  Future<void> _setManualLocation() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (!mounted) return;
    setState(() {
      _manualChosen = context.read<AppController>().settings.locationMode ==
          LocationMode.manual;
    });
  }
}

class _LocationChoicePage extends StatelessWidget {
  const _LocationChoicePage({required this.onSetManual});

  final VoidCallback onSetManual;

  @override
  Widget build(BuildContext context) {
    return _OnboardPage(
      icon: Icons.location_on,
      color: AppTheme.primary,
      title: 'How should we locate you?',
      body:
          'Use live GPS (updates as you move) or pick a place manually — '
          'useful when indoors, traveling, or watching over a distant area.',
      child: Column(
        children: [
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onSetManual,
            icon: const Icon(Icons.edit_location_alt_outlined),
            label: const Text('Choose a place manually'),
          ),
        ],
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.child,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 88, color: color),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}
