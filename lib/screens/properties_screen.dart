import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/money.dart';
import '../models/models.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

class PropertiesScreen extends ConsumerWidget {
  const PropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(propertiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ທີ່ພັກ & ຫ້ອງ')),
      body: properties.when(
        loading: () => const LoadingBlock(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(propertiesProvider)),
        data: (list) => list.isEmpty
            ? const EmptyState(message: 'ຍັງບໍ່ມີທີ່ພັກ', icon: Icons.home_work_outlined)
            : RefreshIndicator(
                color: C.accent,
                onRefresh: () async => ref.invalidate(propertiesProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    for (final property in list) ...[
                      _PropertyCard(property: property),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _PropertyCard extends ConsumerStatefulWidget {
  const _PropertyCard({required this.property});
  final Property property;

  @override
  ConsumerState<_PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends ConsumerState<_PropertyCard> {
  bool _uploading = false;

  Future<void> _addPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Uploads are capped at 5 MB and resized server-side anyway; shrinking
      // here saves the partner's mobile data.
      maxWidth: 2000,
      imageQuality: 88,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      await ref.read(actionsProvider).uploadPropertyPhoto(
            widget.property.id,
            MultipartFile.fromBytes(bytes, filename: picked.name),
          );
      if (mounted) showMessage(context, 'ອັບໂຫຼດຮູບແລ້ວ');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removePhoto(int index) async {
    try {
      await ref.read(actionsProvider).deletePropertyPhoto(widget.property.id, index);
      if (mounted) showMessage(context, 'ລຶບຮູບແລ້ວ');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _editRoom({Room? room}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
      ),
      builder: (_) => _RoomSheet(propertyId: widget.property.id, room: room),
    );
    if (saved == true && mounted) showMessage(context, 'ບັນທຶກຫ້ອງແລ້ວ');
  }

  Future<void> _deleteRoom(Room room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ລຶບ "${room.name}"?'),
        content: const Text(
          'ຖ້າຫ້ອງນີ້ເຄີຍມີການຈອງ ລະບົບຈະປິດການຂາຍແທນການລຶບ '
          'ເພື່ອຮັກສາປະຫວັດການຈອງໄວ້',
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('ຍົກເລີກ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.dangerFg),
            onPressed: () => ctx.pop(true),
            child: const Text('ຢືນຢັນ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final deleted = await ref.read(actionsProvider).deleteRoom(room.id);
      if (mounted) {
        showMessage(context, deleted ? 'ລຶບຫ້ອງແລ້ວ' : 'ປິດການຂາຍຫ້ອງແລ້ວ (ມີປະຫວັດການຈອງ)');
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Photo(url: p.photos.isEmpty ? null : p.photos.first, width: 58, height: 58),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${p.province} · ${p.rooms.length} ຫ້ອງ',
                        style: const TextStyle(fontSize: 12.5, color: C.muted),
                      ),
                      if (p.reviewCount > 0)
                        Text(
                          '${stars(p.rating?.round() ?? 0)} ${p.rating?.toStringAsFixed(2) ?? ''} (${p.reviewCount})',
                          style: const TextStyle(fontSize: 12, color: C.accent),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'ຮູບທີ່ພັກ',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${p.photos.length}/12',
                  style: const TextStyle(fontSize: 11.5, color: C.faint),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 74,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < p.photos.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          Photo(url: p.photos[i], width: 74, height: 74),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () => _removePhoto(i),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 13, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (p.photos.length < 12)
                    InkWell(
                      onTap: _uploading ? null : _addPhoto,
                      borderRadius: BorderRadius.circular(R.md),
                      child: Container(
                        width: 74,
                        height: 74,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: C.bg,
                          borderRadius: BorderRadius.circular(R.md),
                          border: Border.all(color: C.border),
                        ),
                        child: _uploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: C.accent),
                              )
                            : const Icon(Icons.add_a_photo_outlined, color: C.soft, size: 20),
                      ),
                    ),
                ],
              ),
            ),

            const Divider(height: 26),
            Row(
              children: [
                const Text('ຫ້ອງ', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _editRoom(),
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('ເພີ່ມຫ້ອງ'),
                ),
              ],
            ),
            for (final room in p.rooms)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        room.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: room.isActive ? C.text : C.faint,
                        ),
                      ),
                    ),
                    if (!room.isActive) ...[
                      const SizedBox(width: 8),
                      const StatusPill(
                        map: {'closed': Pill(C.neutralBg, C.neutralFg, 'ປິດຂາຍ')},
                        status: 'closed',
                        compact: true,
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  '${kip(room.basePrice)} · ${room.capacity} ຄົນ · ${room.qty} ຫ້ອງ'
                  '${room.hasAc ? ' · ແອ' : ''}',
                  style: const TextStyle(fontSize: 12, color: C.muted),
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: C.faint),
                  onSelected: (value) {
                    if (value == 'edit') _editRoom(room: room);
                    if (value == 'delete') _deleteRoom(room);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('ແກ້ໄຂ')),
                    PopupMenuItem(value: 'delete', child: Text('ລຶບ')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoomSheet extends ConsumerStatefulWidget {
  const _RoomSheet({required this.propertyId, this.room});

  final String propertyId;
  final Room? room;

  @override
  ConsumerState<_RoomSheet> createState() => _RoomSheetState();
}

class _RoomSheetState extends ConsumerState<_RoomSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.room?.name ?? '');
  late final _roomNo = TextEditingController(text: widget.room?.roomNo ?? '');
  late final _price = TextEditingController(text: widget.room?.basePrice.toString() ?? '');
  late final _capacity = TextEditingController(text: widget.room?.capacity.toString() ?? '2');
  late final _qty = TextEditingController(text: widget.room?.qty.toString() ?? '1');

  late String _bedType = widget.room?.bedType ?? 'double';
  late bool _hasAc = widget.room?.hasAc ?? true;
  late bool _isActive = widget.room?.isActive ?? true;
  bool _busy = false;

  /// Must match `BED_TYPES` in the backend's `common/money.ts`.
  static const _bedTypes = {
    'single': 'ຕຽງດ່ຽວ',
    'double': 'ຕຽງຄູ່',
    'twin': 'ສອງຕຽງ',
    'king': 'ຕຽງໃຫຍ່',
  };

  @override
  void dispose() {
    _name.dispose();
    _roomNo.dispose();
    _price.dispose();
    _capacity.dispose();
    _qty.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);

    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'roomNo': _roomNo.text.trim(),
      'hasAc': _hasAc,
      'bedType': _bedType,
      'basePrice': int.parse(_price.text.replaceAll(RegExp(r'[^0-9]'), '')),
      'capacity': int.parse(_capacity.text),
      'qty': int.parse(_qty.text),
      // Only an update may toggle activity; the create DTO rejects the field.
      if (widget.room != null) 'isActive': _isActive,
    };

    try {
      await ref.read(actionsProvider).saveRoom(
            roomId: widget.room?.id,
            propertyId: widget.propertyId,
            body: body,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.room == null ? 'ເພີ່ມຫ້ອງ' : 'ແກ້ໄຂຫ້ອງ',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'ຊື່ຫ້ອງ'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'ໃສ່ຊື່ຫ້ອງ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roomNo,
                decoration: const InputDecoration(labelText: 'ເລກຫ້ອງ (ບໍ່ບັງຄັບ)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'ລາຄາຕໍ່ຄືນ', prefixText: '₭ '),
                validator: (v) {
                  final n = int.tryParse((v ?? '').replaceAll(RegExp(r'[^0-9]'), ''));
                  if (n == null || n < 1000) return 'ລາຄາຢ່າງໜ້ອຍ ₭1,000';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _capacity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'ຮັບໄດ້ (ຄົນ)'),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1 || n > 20) return '1–20';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _qty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ຈຳນວນຫ້ອງ',
                        helperText: 'ຫ້ອງແບບນີ້ມີຈັກຫ້ອງ',
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1 || n > 200) return '1–200';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _bedType,
                decoration: const InputDecoration(labelText: 'ປະເພດຕຽງ'),
                items: [
                  for (final e in _bedTypes.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _bedType = v ?? 'double'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _hasAc,
                onChanged: (v) => setState(() => _hasAc = v),
                title: const Text('ມີແອ', style: TextStyle(fontSize: 14)),
                activeColor: C.accent,
              ),
              if (widget.room != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('ເປີດຂາຍ', style: TextStyle(fontSize: 14)),
                  activeColor: C.accent,
                ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('ບັນທຶກ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
