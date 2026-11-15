import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../page_transitions.dart';
import '../../../services/account_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/cart_service.dart';
import '../../../services/wishlist_service.dart';
import '../../welcome_page.dart';

/// Delete Account, as on the website: confirm with the password. The server
/// refuses while an order or return is still open and says which; otherwise
/// the buyer's details are erased (order records the seller relies on stay).
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }
    setState(() => _error = null);
    final ok = await PsDialog.confirm(
      context,
      title: 'Delete your account?',
      message: 'This can’t be undone. Your profile, addresses, cart and saved items will be erased.',
      confirmLabel: 'Delete account',
      cancelLabel: 'Keep account',
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await AccountService().deleteAccount(password: _password.text);
      await SessionManager().clear();
      CartStore.instance.reset();
      WishlistStore.instance.clear();
      NotificationBadge.instance.value = 0;
      if (!mounted) return;
      PsToast.success(context, 'Your account has been deleted.');
      Navigator.of(context).pushAndRemoveUntil(fadeRoute(const WelcomePage()), (_) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.fieldError('password') ?? (e.isValidation ? e.message : null);
      });
      if (!e.isValidation) PsDialog.error(context, title: 'Couldn’t delete your account', message: e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: const PsTopBar(title: 'Delete Account'),
      footer: PsFooterActions(
        primary: PsPrimaryButton(label: 'Delete my account', uppercase: false, loading: _busy, onPressed: _delete),
      ),
      body: ListView(
        padding: const EdgeInsets.all(PsSpace.gutter),
        children: [
          PsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: PsColors.error),
                    const SizedBox(width: PsSpace.xs),
                    Expanded(child: Text('Before you go', style: PsText.heading.copyWith(fontSize: 16))),
                  ],
                ),
                const SizedBox(height: PsSpace.sm),
                for (final line in const [
                  'Your profile, addresses, cart, My Picks and followed stores are erased.',
                  'Orders still in progress or open returns must be finished first.',
                  'Past order records are kept for the seller and for refunds, without your details.',
                  'You can’t undo this. You’d need to sign up again to shop.',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: PsSpace.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•  ', style: PsText.body),
                        Expanded(child: Text(line, style: PsText.body)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: PsSpace.lg),
          PsTextField(
            label: 'Password',
            controller: _password,
            obscure: true,
            errorText: _error,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _delete(),
          ),
        ],
      ),
    );
  }
}
