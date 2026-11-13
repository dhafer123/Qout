import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/auth/data/auth_repository.dart';
import 'package:qout/features/auth/domain/credentials.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _newAccount ? 'Create an account' : 'Sign in';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.reason ??
                        'An account is only needed to add products. '
                            'Scanning works without one.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
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
                      helperText: _newAccount
                          ? 'At least $minPasswordLength characters.'
                          : null,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _showPassword
                            ? 'Hide password'
                            : 'Show password',
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
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
                    Text(
                      error,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_newAccount ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _newAccount = !_newAccount;
                            _error = null;
                          }),
                    child: Text(
                      _newAccount
                          ? 'Already have an account? Sign in'
                          : 'New here? Create an account',
                    ),
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
