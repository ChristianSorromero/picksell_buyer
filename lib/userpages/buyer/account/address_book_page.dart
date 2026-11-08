import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/address.dart';
import '../../../services/address_book_service.dart';
import 'address_form_page.dart';
import 'edit_profile_page.dart';
import 'map_pin_page.dart';

/// What the buyer picked at checkout: the default address ([id] null) or a saved one.
class AddressChoice {
  const AddressChoice(this.id);

  final int? id;
}

/// My Addresses (website: account page "Delivery Address" and "Other
/// Addresses"): the default address with its door pin, and up to 10 more.
///
/// Opened from checkout with [picking], tapping an address pops an
/// [AddressChoice]; otherwise it manages the book.
class AddressBookPage extends StatefulWidget {
  const AddressBookPage({super.key, this.picking = false, this.selectedId});

  final bool picking;

  /// The address checkout currently ships to (null = default).
  final int? selectedId;

  @override
  State<AddressBookPage> createState() => _AddressBookPageState();
}

enum _Action { edit, pin, makeDefault, delete }

class _AddressBookPageState extends State<AddressBookPage> {
  final _service = AddressBookService();
  AddressBook? _book;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final book = await _service.load();
      if (mounted) {
        setState(() {
          _book = book;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Runs a book change, showing the server's message if it fails.
  Future<void> _run(Future<AddressBook> Function() change, String done) async {
    setState(() => _busy = true);
    try {
      final book = await change();
      if (!mounted) return;
      setState(() => _book = book);
      PsToast.success(context, done);
    } on ApiException catch (e) {
      if (mounted) PsDialog.error(context, title: 'Something went wrong', message: e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final book = _book!;
    if (book.isFull) {
      PsDialog.info(context, title: 'Address book is full', message: 'You can save up to ${book.max} addresses. Remove one to add another.');
      return;
    }
    final updated = await Navigator.of(context).push<AddressBook>(MaterialPageRoute(
      builder: (_) => AddressFormPage(defaultName: book.defaultAddress.recipientName, defaultPhone: book.defaultAddress.phone),
    ));
    if (updated == null || !mounted) return;
    setState(() => _book = updated);
    // Picking at checkout: a new address is the one they want to ship to.
    if (widget.picking && updated.addresses.isNotEmpty) {
      final newest = updated.addresses.reduce((a, b) => a.id > b.id ? a : b);
      Navigator.of(context).pop(AddressChoice(newest.id));
    }
  }

  Future<void> _edit(SavedAddress a) async {
    final updated = await Navigator.of(context).push<AddressBook>(MaterialPageRoute(builder: (_) => AddressFormPage(address: a)));
    if (updated != null && mounted) setState(() => _book = updated);
  }

  Future<void> _editDefault() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfilePage(focusAddress: true)));
    if (mounted) _load();
  }

  Future<void> _pinDefault() async {
    final d = _book!.defaultAddress;
    PinResult? result;
    await Navigator.of(context).push<GeoPin>(MaterialPageRoute(
      builder: (_) => MapPinPage(
        initial: d.pin,
        title: 'Pin your door',
        addressLine: d.fullAddress,
        onConfirm: (pin) async => result = await _service.pinDefault(pin),
      ),
    ));
    final r = result;
    if (r == null || !mounted) return;
    PsToast.success(
      context,
      r.parcelsUpdated == 0
          ? 'Door pin saved. Riders will bring your orders here.'
          : 'Door pin saved. ${r.parcelsUpdated} ${r.parcelsUpdated == 1 ? 'parcel' : 'parcels'} on the way will come here.',
    );
    _load();
  }

  Future<void> _makeDefault(SavedAddress a) async {
    final ok = await PsDialog.confirm(
      context,
      title: 'Make this your default?',
      message: '${a.fullAddress} becomes your default address. Your current default is kept here as “Previous default”. Orders already placed keep their address.',
      confirmLabel: 'Make default',
      icon: Icons.home_rounded,
    );
    if (ok) await _run(() => _service.makeDefault(a.id), 'Default address changed');
  }

  Future<void> _delete(SavedAddress a) async {
    final ok = await PsDialog.confirm(
      context,
      title: 'Remove this address?',
      message: '${a.label ?? 'This address'} · ${a.fullAddress}\nOrders already placed to it are not affected.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (ok) await _run(() => _service.remove(a.id), 'Address removed');
  }

  void _pick(int? id) => Navigator.of(context).pop(AddressChoice(id));

  @override
  Widget build(BuildContext context) {
    final book = _book;
    return PsAppShell(
      topBar: PsTopBar(title: widget.picking ? 'Deliver To' : 'My Addresses'),
      footer: book == null
          ? null
          : PsFooterActions(
              primary: PsPrimaryButton(
                label: book.isFull ? 'Address book full (${book.max})' : 'Add a new address',
                icon: Icons.add_location_alt_outlined,
                uppercase: false,
                onPressed: _busy || book.isFull ? null : _add,
              ),
            ),
      body: _body(book),
    );
  }

  Widget _body(AddressBook? book) {
    if (book == null) {
      final e = _error;
      if (e == null) return const PsSkeletonList(itemCount: 3, thumbnail: false);
      return e is ApiException && e.isNetworkError
          ? PsOfflineState(onRetry: _load)
          : PsErrorState(title: 'Couldn’t load your addresses', message: errorMessage(e), onRetry: _load);
    }
    final d = book.defaultAddress;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(PsSpace.gutter),
        children: [
          if (widget.picking)
            Padding(
              padding: const EdgeInsets.only(bottom: PsSpace.sm),
              child: Text('Choose where this order goes. Shipping is priced to the address you pick.', style: PsText.caption),
            ),
          Text('DEFAULT ADDRESS', style: PsText.overline),
          const SizedBox(height: PsSpace.xs),
          _AddressTile(
            label: 'Default',
            isDefault: true,
            name: d.recipientName,
            phone: d.displayPhone,
            address: d.complete ? d.fullAddress : 'Add your province, city and barangay',
            incomplete: !d.complete,
            pinned: d.pin != null,
            selected: widget.picking && widget.selectedId == null,
            onTap: widget.picking ? (d.complete ? () => _pick(null) : _editDefault) : _editDefault,
            actions: const [_Action.edit, _Action.pin],
            onAction: (a) => a == _Action.pin ? _pinDefault() : _editDefault(),
          ),
          if (d.pin == null && d.complete && !widget.picking)
            Padding(
              padding: const EdgeInsets.only(top: PsSpace.xs),
              child: PsCard(
                color: PsColors.primarySoft,
                borderColor: PsColors.primarySoft,
                onTap: _pinDefault,
                child: Row(
                  children: [
                    const Icon(Icons.push_pin_outlined, size: 18, color: PsColors.primaryStrong),
                    const SizedBox(width: PsSpace.xs),
                    Expanded(child: Text('Pin your door on the map so riders find it faster.', style: PsText.caption.copyWith(color: PsColors.primaryStrong))),
                    const Icon(Icons.chevron_right_rounded, color: PsColors.primaryStrong),
                  ],
                ),
              ),
            ),
          const SizedBox(height: PsSpace.lg),
          Text('OTHER ADDRESSES (${book.addresses.length}/${book.max})', style: PsText.overline),
          const SizedBox(height: PsSpace.xs),
          if (book.addresses.isEmpty)
            PsCard(
              child: Row(
                children: [
                  const Icon(Icons.bookmark_add_outlined, color: PsColors.textMuted),
                  const SizedBox(width: PsSpace.sm),
                  Expanded(child: Text('Save your office, a relative’s house or anywhere else you ship to.', style: PsText.bodyMuted)),
                ],
              ),
            ),
          for (final a in book.addresses) ...[
            _AddressTile(
              label: a.label,
              name: a.recipientName,
              phone: a.displayPhone,
              address: a.fullAddress,
              incomplete: !a.complete,
              pinned: a.pin != null,
              selected: widget.picking && widget.selectedId == a.id,
              onTap: widget.picking ? (a.complete ? () => _pick(a.id) : () => _edit(a)) : () => _edit(a),
              actions: const [_Action.edit, _Action.makeDefault, _Action.delete],
              onAction: (action) => switch (action) {
                _Action.makeDefault => _makeDefault(a),
                _Action.delete => _delete(a),
                _ => _edit(a),
              },
            ),
            const SizedBox(height: PsSpace.sm),
          ],
          const SizedBox(height: PsSpace.lg),
        ],
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.name,
    required this.phone,
    required this.address,
    required this.actions,
    required this.onAction,
    required this.onTap,
    this.label,
    this.isDefault = false,
    this.incomplete = false,
    this.pinned = false,
    this.selected = false,
  });

  final String? label;
  final String name;
  final String phone;
  final String address;
  final bool isDefault;
  final bool incomplete;
  final bool pinned;
  final bool selected;
  final VoidCallback onTap;
  final List<_Action> actions;
  final ValueChanged<_Action> onAction;

  static const _labels = {
    _Action.edit: 'Edit',
    _Action.pin: 'Pin on map',
    _Action.makeDefault: 'Set as default',
    _Action.delete: 'Remove',
  };

  @override
  Widget build(BuildContext context) {
    return PsAddressCard(
      name: name.isEmpty ? 'No name' : name,
      phone: phone,
      address: address,
      label: isDefault ? null : label,
      isDefault: isDefault,
      selected: selected,
      onTap: onTap,
      landmark: incomplete ? 'Incomplete: tap to finish this address' : (pinned ? 'Pinned on the map' : null),
      trailing: PopupMenuButton<_Action>(
        tooltip: 'Address options',
        icon: const Icon(Icons.more_vert_rounded, color: PsColors.textMuted),
        onSelected: onAction,
        itemBuilder: (_) => [
          for (final a in actions)
            PopupMenuItem(
              value: a,
              child: Text(_labels[a]!, style: a == _Action.delete ? PsText.body.copyWith(color: PsColors.error) : PsText.body),
            ),
        ],
      ),
    );
  }
}
