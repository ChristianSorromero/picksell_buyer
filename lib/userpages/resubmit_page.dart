import 'package:flutter/material.dart';

import '../components/components.dart';
import '../services/auth_service.dart';
import 'buyer/orders/evidence_picker.dart';

/// Fix a rejected sign-up (website: the resubmit page): see why it wasn't
/// approved, replace the ID and send the same account back for review. Opened
/// from login with the single-use token from the refusal; it does not sign in.
class ResubmitPage extends StatefulWidget {
  const ResubmitPage({super.key, required this.email, required this.token, this.reason, this.documents = const []});

  final String email;
  final String token;
  final String? reason;

  /// What may be replaced, e.g. [(field: 'id_upload', label: 'Government-issued ID')].
  final List<({String field, String label})> documents;

  /// From the login refusal (`documents`, `reason`, `resubmit_token`).
  static ResubmitPage fromRefusal(String email, Map<String, dynamic> data) => ResubmitPage(
        email: email,
        token: '${data['resubmit_token']}',
        reason: data['reason'] as String?,
        documents: [
          for (final d in (data['documents'] as List? ?? const []))
            if (d is Map) (field: '${d['field']}', label: '${d['label']}'),
        ],
      );

  @override
  State<ResubmitPage> createState() => _ResubmitPageState();
}

class _ResubmitPageState extends State<ResubmitPage> {
  final _auth = AuthService();
  List<String> _id = [];
  String? _error;
  bool _sending = false;

  String get _idLabel =>
      widget.documents.where((d) => d.field == 'id_upload').map((d) => d.label).firstOrNull ?? 'Government-issued ID';

  Future<void> _send() async {
    if (_id.isEmpty) {
      setState(() => _error = 'Add a clear photo of your ID first.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await _auth.resubmit(token: widget.token, idPhoto: _id.first);
    if (!mounted) return;
    if (result.success) {
      await PsDialog.info(
        context,
        title: 'Sent for review',
        message: result.message,
      );
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _sending = false;
      _error = result.fieldError('id_upload') ?? result.fieldError('documents') ?? result.fieldError('resubmit_token') ?? result.message;
    });
    // The 30-minute window closed: log in again for a fresh one.
    if (result.fieldError('resubmit_token') != null) {
      await PsDialog.error(context, title: 'Log in again', message: result.fieldError('resubmit_token')!, actionLabel: 'Back to log in');
      if (mounted) Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = widget.reason;
    return PsAppShell(
      topBar: const PsTopBar(title: 'Fix Your Sign-up'),
      footer: PsFooterActions(primary: PsPrimaryButton(label: 'Resubmit for review', uppercase: false, loading: _sending, onPressed: _send)),
      body: ListView(
        padding: const EdgeInsets.all(PsSpace.gutter),
        children: [
          Text('Your sign-up wasn’t approved yet', style: PsText.heading.copyWith(fontSize: 20)),
          const SizedBox(height: 4),
          Text(widget.email, style: PsText.caption),
          const SizedBox(height: PsSpace.md),
          PsCard(
            color: PsColors.warningSoft,
            borderColor: PsColors.warningSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Why it wasn’t approved', style: PsText.bodyStrong.copyWith(color: PsColors.warning)),
                const SizedBox(height: 4),
                Text(
                  reason == null || reason.trim().isEmpty ? 'No reason was given. Check your ID and upload a clearer photo.' : reason,
                  style: PsText.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: PsSpace.lg),
          PsFieldLabel(_idLabel),
          Padding(
            padding: const EdgeInsets.only(bottom: PsSpace.xs),
            child: Text('Take a clear, well-lit photo of the whole ID so every word can be read. Only PickSell admins see it.', style: PsText.caption),
          ),
          EvidencePicker(
            paths: _id,
            max: 1,
            onChanged: (p) => setState(() {
              _id = p;
              _error = null;
            }),
          ),
          if (_error != null) PsFieldError(_error!),
          const SizedBox(height: PsSpace.lg),
          Text('Your account goes back to the review queue. We’ll email you once an admin has checked it.', style: PsText.caption),
        ],
      ),
    );
  }
}
