import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/address.dart';
import '../../../services/account_service.dart';
import 'address_form_page.dart';

/// BUY-A03 Address Manager. In [selectMode] tapping an address pops it
/// (checkout); otherwise addresses can be edited, deleted or made default.
class AddressBookPage extends StatefulWidget {
  const AddressBookPage({super.key, this.selectMode = false, this.selectedId});

  final bool selectMode;
  final int? selectedId;

  @override
  State<AddressBookPage> createState() => _AddressBookPageState();
}

class _AddressBookPageState extends State<AddressBookPage> {
  final _account = AccountService();
  final _view = GlobalKey<PsAsyncViewState<List<Address>>>();

  Future<void> _edit([Address? address]) async {
    final saved = await Navigator.of(context).push<Address>(MaterialPageRoute(builder: (_) => AddressFormPage(address: address)));
    if (saved == null || !mounted) return;
    if (widget.selectMode && address == null) {
      Navigator.of(context).pop(saved);
      return;
    }
    _view.currentState?.reload();
  }

  Future<void> _more(Address a) async {
    final action = await PsBottomSheet.options<String>(
      context,
      title: a.recipientName,
      options: [
        const PsSheetOption(value: 'edit', label: 'Edit address', icon: Icons.edit_outlined),
        if (!a.isDefault) const PsSheetOption(value: 'default', label: 'Set as default', icon: Icons.star_outline_rounded),
        const PsSheetOption(value: 'delete', label: 'Delete', icon: Icons.delete_outline_rounded, destructive: true),
      ],
    );
    if (!mounted || action == null) return;
    try {
      switch (action) {
        case 'edit':
          await _edit(a);
        case 'default':
          await _account.makeDefault(a.id);
          if (mounted) PsToast.success(context, 'Default address updated');
          _view.currentState?.reload();
        case 'delete':
          final ok = await PsDialog.confirm(
            context,
            title: 'Delete this address?',
            message: a.fullAddress,
            confirmLabel: 'Delete',
            destructive: true,
          );
          if (!ok) return;
          _view.currentState?.replace(await _account.deleteAddress(a.id));
          if (mounted) PsToast.success(context, 'Address deleted');
      }
    } catch (e) {
      if (mounted) PsDialog.error(context, title: 'Something went wrong', message: errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: PsTopBar(title: widget.selectMode ? 'Select Address' : 'My Addresses'),
      footer: PsFooterActions(primary: PsPrimaryButton(label: 'Add new address', icon: Icons.add_rounded, uppercase: false, onPressed: _edit)),
      body: PsAsyncView<List<Address>>(
        key: _view,
        load: _account.addresses,
        isEmpty: (l) => l.isEmpty,
        empty: const PsEmptyState(
          icon: Icons.location_on_outlined,
          title: 'No saved addresses',
          message: 'Add where you’d like your orders delivered.',
        ),
        builder: (context, list, _) => ListView.separated(
          padding: const EdgeInsets.all(PsSpace.gutter),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: PsSpace.sm),
          itemBuilder: (_, i) {
            final a = list[i];
            return PsAddressCard.of(
              a,
              selected: widget.selectMode && a.id == widget.selectedId,
              onTap: widget.selectMode ? () => Navigator.of(context).pop(a) : () => _edit(a),
              trailing: PsIconButton(icon: Icons.more_vert_rounded, tooltip: 'Address options', onPressed: () => _more(a)),
            );
          },
        ),
      ),
    );
  }
}
