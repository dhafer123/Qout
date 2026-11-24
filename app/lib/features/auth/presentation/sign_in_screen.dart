import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:qout/app/theme.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/auth/data/auth_repository.dart';
import 'package:qout/features/auth/domain/credentials.dart';
import 'package:qout/features/auth/presentation/sign_in_art.dart';

/// Sign in, or create a contributor account. Pops `true` once signed in.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({this.reason, super.key});

  /// Why an account is needed here, shown above the form.
  final String? reason;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _newAccount = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final repository = ref.read(authRepositoryProvider);
    try {
      if (_newAccount) {
        await repository.register(
          email: _email.text,
          password: _password.text,
        );
      } else {
        await repository.signIn(email: _email.text, password: _password.text);
      }
      if (!mounted) return;
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/');
      }
    } on QoutApiException catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(QoutApiException error) => switch (error) {
    ApiUnauthorized() => 'Wrong email or password.',
    ApiConflict() =>
      'An account with this email already exists. Sign in instead.',
    ApiTooManyRequests(:final retryAfter) =>
      'Too many attempts. Try again in '
          '${_minutes(retryAfter ?? const Duration(minutes: 1))}.',
    ApiInvalidRequest(:final message) => _capitalized(message),
    ApiConnectionError() =>
      'You are offline. Connect to the internet and try again.',
    _ => 'Qout could not be reached. Try again in a moment.',
  };

  static String _minutes(Duration wait) {
    final minutes = (wait.inSeconds / 60).ceil();
    return minutes <= 1 ? 'a minute' : '$minutes minutes';
  }

  static String _capitalized(String text) => text.isEmpty
      ? 'The server refused this. Check your entries.'
      : '${text[0].toUpperCase()}${text.substring(1)}.';

  void _setMode({required bool newAccount}) => setState(() {
    _newAccount = newAccount;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // With the keyboard up, the illustration makes room for the form.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: keyboard
                        ? const SizedBox(width: double.infinity)
                        : const Center(child: SignInArt()),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    header: true,
                    child: Text(
                      _newAccount ? 'Create your account' : 'Welcome back',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.reason case final reason?) ...[
                    const SizedBox(height: 6),
                    Text(
                      reason,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: QoutPalette.of(context).muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Sign in')),
                      ButtonSegment(value: true, label: Text('Sign up')),
                    ],
                    selected: {_newAccount},
                    showSelectedIcon: false,
                    onSelectionChanged: _busy
                        ? null
                        : (choice) => _setMode(newAccount: choice.single),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(PhosphorIconsRegular.envelopeSimple),
                    ),
                    validator: (value) => emailProblem(value ?? ''),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: !_showPassword,
                    autofillHints: [
                      if (_newAccount)
                        AutofillHints.newPassword
                      else
                        AutofillHints.password,
                    ],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(PhosphorIconsRegular.lockSimple),
                      helperText: _newAccount
                          ? 'At least $minPasswordLength characters.'
                          : null,
                      suffixIcon: IconButton(
                        tooltip: _showPassword
                            ? 'Hide password'
                            : 'Show password',
                        icon: Icon(
                          _showPassword
                              ? PhosphorIconsRegular.eyeSlash
                              : PhosphorIconsRegular.eye,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    validator: (value) =>
                        passwordProblem(value ?? '', newAccount: _newAccount),
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(QoutRadius.lg),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              PhosphorIconsRegular.warningCircle,
                              size: 20,
                              color: scheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                error,
                                style: TextStyle(
                                  color: scheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _busy
                        ? SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                        : Text(_newAccount ? 'Create account' : 'Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
