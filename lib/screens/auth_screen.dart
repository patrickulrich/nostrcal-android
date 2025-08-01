import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:async_button_builder/async_button_builder.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../main.dart';


/// Authentication screen for signing in with Amber
class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pubkey = ref.watch(Signer.activePubkeyProvider);

    // If user is already signed in, navigate to calendar
    if (pubkey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/calendar');
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App branding
              Icon(
                Icons.calendar_month,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to NostrCal',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your decentralized calendar on Nostr.\nSign in to manage your events and availability.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Sign in section
              if (pubkey == null) ...[
                _buildSignInButton(context, ref),
                const SizedBox(height: 24),
                _buildAmberInfo(context),
              ] else ...[
                // Show profile info while loading
                _buildProfileSection(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton(BuildContext context, WidgetRef ref) {
    return AsyncButtonBuilder(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.key, size: 20),
          const SizedBox(width: 8),
          Text('Sign In with Amber'),
        ],
      ),
      onPressed: () => _signInWithAmber(context, ref),
      builder: (context, child, callback, buttonState) {
        return FilledButton(
          onPressed: buttonState.maybeWhen(
            loading: () => null,
            orElse: () => callback,
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: buttonState.maybeWhen(
            loading: () => SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            orElse: () => child,
          ),
        );
      },
    );
  }

  Widget _buildAmberInfo(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'About Amber',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Amber is a secure Nostr signer app that keeps your private keys safe. '
              'It allows NostrCal to create and sign events without exposing your keys.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _launchAmberInstall(),
              child: Text('Install Amber'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Column(
      children: [
        CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          'Loading your profile...',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  Future<void> _signInWithAmber(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(amberSignerProvider).signIn();
      if (context.mounted) {
        context.go('/calendar');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Install Amber',
              onPressed: _launchAmberInstall,
            ),
          ),
        );
      }
    }
  }

  void _launchAmberInstall() {
    launchUrl(
      Uri.parse('https://github.com/greenart7c3/Amber'),
      mode: LaunchMode.externalApplication,
    );
  }
}