import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/theme.dart';

/// The first screen anyone sees, so it carries the mark and says what this is.
///
/// Deliberately quiet: the logo does the colour, the type does the hierarchy, and
/// the fields sit in the same grouped surface the rest of the app uses — no
/// decorative gradient panels, no glass, nothing that will look dated next year.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignedIn});
  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _ready => _email.text.contains('@') && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_ready || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.instance.signIn(_email.text.trim(), _password.text);
      if (mounted) widget.onSignedIn();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Could not reach Makutano Connect. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? Brand.darkSurface : Brand.surface;
    final line = dark ? Brand.darkLine : Brand.line;

    return Scaffold(
      backgroundColor: dark ? Brand.darkGround : Brand.ground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              // Spacer needs a bounded column; a scroll view alone gives it infinity.
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 44),

                    // The mark, at a size that reads as a brand rather than an icon.
                    Row(
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          width: 62,
                          height: 62,
                          filterQuality: FilterQuality.high,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: dark ? Brand.darkInk : Brand.ink,
                                  ),
                                  children: const [
                                    TextSpan(text: 'Makutano '),
                                    TextSpan(
                                      text: 'Connect',
                                      style: TextStyle(color: Brand.blue),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Customer operations, in your pocket',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 34),
                    Text(
                      'Sign in',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 27, letterSpacing: -0.6),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Use the same details you use on the web portal.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(height: 22),

                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                        decoration: BoxDecoration(
                          color: Brand.danger.withValues(alpha: dark ? 0.16 : 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Brand.danger.withValues(alpha: 0.28)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Brand.danger, size: 18),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Brand.danger, fontSize: 13.5, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // One surface, two fields, a hairline between — the same grouped
                    // language the rest of the app speaks.
                    Container(
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: line),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _Field(
                            controller: _email,
                            focusNode: _emailFocus,
                            hint: 'Email',
                            icon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username, AutofillHints.email],
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _passwordFocus.requestFocus(),
                          ),
                          Divider(height: 1, indent: 46, color: line),
                          _Field(
                            controller: _password,
                            focusNode: _passwordFocus,
                            hint: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscure,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _submit(),
                            trailing: IconButton(
                              icon: Icon(
                                _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 19,
                              ),
                              color: Theme.of(context).textTheme.bodySmall?.color,
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _ready && !_busy ? _submit : null,
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                            : const Text('Sign in'),
                      ),
                    ),

                    const SizedBox(height: 14),
                    Text(
                      'Forgot your password? Reset it on the web portal — this app uses the same account.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12.5, height: 1.4),
                    ),

                    const Spacer(),
                    Center(
                      child: TextButton.icon(
                        onPressed: _busy ? null : _showServerSheet,
                        icon: Icon(
                          Icons.dns_outlined,
                          size: 15,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        label: Text(
                          Api.instance.baseUrl.replaceFirst(RegExp(r'^https?://'), ''),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Rarely needed, never in the way: pointing the app at a different server.
  void _showServerSheet() {
    final controller = TextEditingController(text: Api.instance.baseUrl);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Server', style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Leave this alone unless you were told to change it.',
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(controller: controller, keyboardType: TextInputType.url, autocorrect: false),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await Api.instance.setBaseUrl(controller.text);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                if (mounted) setState(() {});
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A field that lives inside a grouped surface: icon, text, optional trailing —
/// no box of its own, because the group already draws the box.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: 19, color: muted),
          const SizedBox(width: 11),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscure,
              keyboardType: keyboardType,
              autofillHints: autofillHints,
              textInputAction: textInputAction,
              autocorrect: false,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: const TextStyle(fontSize: 15.5),
              decoration: InputDecoration(
                hintText: hint,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 17),
                isDense: true,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
