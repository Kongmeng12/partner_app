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

  // Holds the dragged-to order while a reorder request is in flight, so the
  // strip shows the new arrangement immediately instead of snapping back
  // until the server round-trip finishes. Cleared once a fresh photo list
  // arrives from the provider (success) or the request fails (revert).
  List<PhotoRef>? _reorderedPhotos;

  List<PhotoRef> get _displayPhotos => _reorderedPhotos ?? widget.property.photos;

  @override
  void didUpdateWidget(covariant _PropertyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.property.photos, widget.property.photos)) {
      _reorderedPhotos = null;
    }
  }

  // `newIndex` here already accounts for the item's removal from `oldIndex`
  // (that's what onReorderItem does differently from the deprecated
  // onReorder) — insert at it directly, no further adjustment.
  Future<void> _reorderPhotos(int oldIndex, int newIndex) async {
    final photos = List<PhotoRef>.of(_displayPhotos);
    final moved = photos.removeAt(oldIndex);
    photos.insert(newIndex, moved);
    setState(() => _reorderedPhotos = photos);

    try {
      await ref.read(actionsProvider).reorderPropertyPhotos(
            widget.property.id,
            [for (final photo in photos) photo.id],
          );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _reorderedPhotos = null);
        showMessage(context, e.message, error: true);
      }
    }
  }

  Future<void> _addPhoto() async {
    final picked = await ImagePicker().pickMultiImage(
      // Uploads are capped at 5 MB and resized server-side anyway; shrinking
      // here saves the partner's mobile data.
      maxWidth: 2000,
      imageQuality: 88,
    );
    if (picked.isEmpty) return;

    setState(() => _uploading = true);
    try {
      // The backend endpoint takes one file per request, so each picked
      // photo is its own upload — a failure partway through still leaves
      // the earlier ones saved rather than losing the whole batch.
      for (final photo in picked) {
        final bytes = await photo.readAsBytes();
        await ref.read(actionsProvider).uploadPropertyPhoto(
              widget.property.id,
              MultipartFile.fromBytes(bytes, filename: photo.name),
            );
      }
      if (mounted) {
        showMessage(
          context,
          picked.length == 1 ? 'ອັບໂຫຼດຮູບແລ້ວ' : 'ອັບໂຫຼດ ${picked.length} ຮູບແລ້ວ',
        );
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removePhoto(String imageId) async {
    try {
      await ref.read(actionsProvider).deletePropertyPhoto(widget.property.id, imageId);
      if (mounted) showMessage(context, 'ລຶບຮູບແລ້ວ');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _editRoom({RoomType? room}) async {
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

  Future<void> _deleteRoom(RoomType room) async {
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
      final deleted = await ref.read(actionsProvider).deleteRoomType(room.id);
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
                Photo(url: p.photos.isEmpty ? null : p.photos.first.url, width: 58, height: 58),
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
                        '${p.location} · ${p.roomTypes.length} ປະເພດຫ້ອງ',
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
                  '${_displayPhotos.length}/12',
                  style: const TextStyle(fontSize: 11.5, color: C.faint),
                ),
              ],
            ),
            if (_displayPhotos.length > 1) ...[
              const SizedBox(height: 2),
              const Text(
                'ກົດຄ້າງແລ້ວລາກເພື່ອຈັດລຳດັບ · ຮູບທຳອິດຄືຮູບປົກ',
                style: TextStyle(fontSize: 11, color: C.faint),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              height: 74,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: _displayPhotos.length * 82.0,
                      height: 74,
                      child: ReorderableListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        onReorderItem: _reorderPhotos,
                        itemCount: _displayPhotos.length,
                        itemBuilder: (context, index) {
                          final photo = _displayPhotos[index];
                          return Padding(
                            key: ValueKey(photo.id),
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                Photo(url: photo.url, width: 74, height: 74),
                                if (index == 0)
                                  Positioned(
                                    left: 4,
                                    bottom: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: C.accent,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'ຮູບປົກ',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: InkWell(
                                    onTap: () => _removePhoto(photo.id),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child:
                                          const Icon(Icons.close, size: 13, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (_displayPhotos.length < 12)
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2, color: C.accent),
                                )
                              : const Icon(Icons.add_a_photo_outlined, color: C.soft, size: 20),
                        ),
                      ),
                  ],
                ),
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
                  label: const Text('ເພີ່ມປະເພດຫ້ອງ'),
                ),
              ],
            ),
            for (final room in p.roomTypes)
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
                  '${kip(room.basePrice)} · ${room.maxOccupancy} ຄົນ · ${room.totalRooms} ຫ້ອງ'
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
  final RoomType? room;

  @override
  ConsumerState<_RoomSheet> createState() => _RoomSheetState();
}

class _RoomSheetState extends ConsumerState<_RoomSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.room?.name ?? '');
  late final _price = TextEditingController(text: widget.room?.basePrice.toString() ?? '');
  late final _capacity =
      TextEditingController(text: widget.room?.maxOccupancy.toString() ?? '2');
  late final _qty = TextEditingController(text: widget.room?.totalRooms.toString() ?? '1');
  late final _minNights = TextEditingController(text: widget.room?.minNights.toString() ?? '1');

  late String _bedType = widget.room?.bedType ?? 'double';
  late bool _hasAc = widget.room?.hasAc ?? true;
  late bool _isActive = widget.room?.isActive ?? true;
  late bool _allowRoomSelection = widget.room?.allowRoomSelection ?? false;
  bool _busy = false;

  /// Must match the `bed_type` enum exactly — anything else is a 400.
  static const _bedTypes = {
    'single': 'ຕຽງດ່ຽວ',
    'double': 'ຕຽງຄູ່',
    'twin': 'ສອງຕຽງ',
  };

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _capacity.dispose();
    _qty.dispose();
    _minNights.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);

    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'hasAc': _hasAc,
      'bedType': _bedType,
      'basePrice': int.parse(_price.text.replaceAll(RegExp(r'[^0-9]'), '')),
      'maxOccupancy': int.parse(_capacity.text),
      'totalRooms': int.parse(_qty.text),
      'minNights': int.parse(_minNights.text),
      // Only an update may toggle activity; the create DTO rejects the field.
      if (widget.room != null) 'isActive': _isActive,
      // Unlike isActive, the create endpoint accepts this one too.
      'allowRoomSelection': _allowRoomSelection,
    };

    try {
      await ref.read(actionsProvider).saveRoomType(
            roomTypeId: widget.room?.id,
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

  /// A full page rather than a second bottom sheet stacked on this one: room
  /// management can hold a floor-grouped grid and a FAB, which a sheet has no
  /// good room for, and a sheet-over-sheet reads as broken, not layered. The
  /// room-type sheet closes first so returning here shows the property list
  /// fresh rather than leaving a stale sheet open underneath.
  Future<void> _manageRooms(RoomType room) async {
    final navigator = Navigator.of(context);
    navigator.pop();
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => _RoomUnitsScreen(roomTypeId: room.id, roomTypeName: room.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Re-resolved from the live property list rather than the `widget.room`
    // snapshot, so the room count on the button below stays right after the
    // partner adds or removes numbered rooms in the sheet it opens.
    final liveRoom = widget.room == null
        ? null
        : _roomTypeById(ref.watch(propertiesProvider).value, widget.room!.id) ?? widget.room;

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
                widget.room == null ? 'ເພີ່ມປະເພດຫ້ອງ' : 'ແກ້ໄຂປະເພດຫ້ອງ',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'ຊື່ປະເພດຫ້ອງ',
                  helperText: 'ເຊັ່ນ: Standard AC, Deluxe',
                ),
                validator: (v) => (v == null || v.trim().length < 2) ? 'ໃສ່ຊື່ຫ້ອງ' : null,
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
                        if (n == null || n < 1 || n > 500) return '1–500';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minNights,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ພັກຢ່າງໜ້ອຍ (ຄືນ)',
                  helperText: 'ຈອງໜ້ອຍກວ່ານີ້ບໍ່ໄດ້',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1 || n > 30) return '1–30';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _bedType,
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
                activeThumbColor: C.accent,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _allowRoomSelection,
                onChanged: (v) => setState(() => _allowRoomSelection = v),
                title: const Text('ໃຫ້ແຂກເລືອກເລກຫ້ອງ', style: TextStyle(fontSize: 14)),
                subtitle: const Text(
                  'ແຂກສາມາດເລືອກຫ້ອງທີ່ຕ້ອງການຕອນຈອງ',
                  style: TextStyle(fontSize: 12),
                ),
                activeThumbColor: C.accent,
              ),
              if (widget.room != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('ເປີດຂາຍ', style: TextStyle(fontSize: 14)),
                  activeThumbColor: C.accent,
                ),
              if (liveRoom != null) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () => _manageRooms(liveRoom),
                  icon: const Icon(Icons.meeting_room_outlined, size: 18),
                  label: Text(
                    liveRoom.rooms.isEmpty
                        ? 'ຈັດການເລກຫ້ອງ'
                        : 'ຈັດການເລກຫ້ອງ (${liveRoom.rooms.length})',
                  ),
                ),
              ],
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

/// Finds one room type by id across every property, so a sheet that only
/// knows the id can always show the freshest copy from [propertiesProvider]
/// rather than the possibly-stale snapshot it was opened with.
RoomType? _roomTypeById(List<Property>? properties, String roomTypeId) {
  if (properties == null) return null;
  for (final p in properties) {
    for (final rt in p.roomTypes) {
      if (rt.id == roomTypeId) return rt;
    }
  }
  return null;
}

/// Lists a room type's individually-numbered rooms — add, edit, retire or
/// delete. Opened from `_RoomSheet` once a room type exists, since a room
/// cannot be created before its room type has an id.
///
/// A full page, not a sheet: grouped by floor with a summary row and a FAB,
/// which is the layout a partner with 20-50 rooms actually needs to scan and
/// manage them, not a flat scrolling list inside a half-screen sheet.
class _RoomUnitsScreen extends ConsumerWidget {
  const _RoomUnitsScreen({required this.roomTypeId, required this.roomTypeName});

  final String roomTypeId;
  final String roomTypeName;

  Future<void> _addOrEdit(BuildContext context, WidgetRef ref, {RoomUnit? room}) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
      ),
      builder: (_) => _RoomUnitSheet(roomTypeId: roomTypeId, room: room),
    );
    // The sheet shows its own success/failure message (a batch add has one
    // per outcome, not a single "saved" line), so there is nothing to do with
    // the popped value here beyond letting `propertiesProvider` — already
    // invalidated inside the action that ran — repaint this screen.
  }

  /// A single tap on the status pill, for the common case (temporarily close
  /// one room, or reopen it) without opening the full edit form. `inactive`
  /// rooms are excluded — that status means "carries booking history," and
  /// changing it deserves the deliberate act of opening the edit form, not a
  /// stray tap.
  Future<void> _toggleStatus(BuildContext context, WidgetRef ref, RoomUnit room) async {
    if (room.isInactive) return;
    final next = room.isAvailable ? 'maintenance' : 'available';
    try {
      await ref.read(actionsProvider).updateRoom(room.id, status: next);
      if (context.mounted) {
        showMessage(context, next == 'maintenance' ? 'ປິດຊົ່ວຄາວແລ້ວ' : 'ເປີດໃຊ້ຄືນແລ້ວ');
      }
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(propertiesProvider).value;
    final roomType = _roomTypeById(properties, roomTypeId);
    final rooms = roomType?.rooms ?? const <RoomUnit>[];
    final floors = _groupRoomsByFloor(rooms);

    return Scaffold(
      appBar: AppBar(title: Text('ເລກຫ້ອງ · $roomTypeName', overflow: TextOverflow.ellipsis)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('ເພີ່ມຫ້ອງ'),
      ),
      body: rooms.isEmpty
          ? EmptyState(
              message: 'ຍັງບໍ່ມີການລະບຸເລກຫ້ອງ\nເພີ່ມເລກຫ້ອງເພື່ອໃຫ້ແຂກເລືອກໄດ້ຕອນຈອງ',
              icon: Icons.meeting_room_outlined,
              action: FilledButton.icon(
                onPressed: () => _addOrEdit(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('ເພີ່ມເລກຫ້ອງ'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _RoomSummaryRow(rooms: rooms),
                const SizedBox(height: 22),
                for (final floor in floors) ...[
                  Text(
                    floor.label.isEmpty ? 'ບໍ່ໄດ້ລະບຸຊັ້ນ' : 'ຊັ້ນ ${floor.label}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.muted),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final room in floor.rooms)
                        _RoomTile(
                          room: room,
                          onTap: () => _addOrEdit(context, ref, room: room),
                          onToggleStatus:
                              room.isInactive ? null : () => _toggleStatus(context, ref, room),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
    );
  }
}

/// A compact scannable overview above the floor groups — "how many rooms do
/// I have and what shape are they in" answered in one glance, the way a real
/// front-desk board would show it, instead of only being readable by counting
/// pills down a list.
class _RoomSummaryRow extends StatelessWidget {
  const _RoomSummaryRow({required this.rooms});
  final List<RoomUnit> rooms;

  @override
  Widget build(BuildContext context) {
    final available = rooms.where((r) => r.isAvailable).length;
    final maintenance = rooms.where((r) => r.isMaintenance).length;
    final inactive = rooms.where((r) => r.isInactive).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(R.lg),
        border: Border.all(color: C.border),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 10,
        children: [
          _stat('ຫ້ອງທັງໝົດ', rooms.length, C.text),
          _stat('ພ້ອມໃຊ້', available, C.successFg),
          if (maintenance > 0) _stat('ບຳລຸງຮັກສາ', maintenance, C.warnFg),
          if (inactive > 0) _stat('ປິດໃຊ້ງານ', inactive, C.muted),
        ],
      ),
    );
  }

  Widget _stat(String label, int count, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color, height: 1.1),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11.5, color: C.muted)),
      ],
    );
  }
}

/// One numbered room as a small tappable card, sized to sit in a `Wrap` —
/// the room number reads first and largest, the status is a coloured pill
/// underneath that alone is enough to scan a whole floor's shape at once.
class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, required this.onTap, this.onToggleStatus});

  final RoomUnit room;
  final VoidCallback onTap;
  final VoidCallback? onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final pill = pillFor(roomUnitStatusPill, room.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.md),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: room.isAvailable ? C.surface : pill.bg.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: room.isAvailable ? C.border : pill.bg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              room.roomNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: room.isInactive ? C.faint : C.text,
              ),
            ),
            const SizedBox(height: 7),
            InkWell(
              onTap: onToggleStatus,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: pill.bg, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  pill.label,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: pill.fg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloorGroup {
  const _FloorGroup(this.label, this.rooms);
  final String label;
  final List<RoomUnit> rooms;
}

/// Groups rooms by floor and orders both the floors and the rooms within each
/// the way a person reads a building, not the way a database returns rows:
/// numeric floors ascend (1, 2, 3…), named ones follow alphabetically, and
/// rooms with no floor set trail last as their own group. Within a floor,
/// "2" sorts before "10" — plain string sorting would not.
List<_FloorGroup> _groupRoomsByFloor(List<RoomUnit> rooms) {
  const noFloor = '';
  final groups = <String, List<RoomUnit>>{};
  for (final room in rooms) {
    final floor = room.floor?.trim();
    final key = (floor == null || floor.isEmpty) ? noFloor : floor;
    groups.putIfAbsent(key, () => []).add(room);
  }
  for (final list in groups.values) {
    list.sort((a, b) => _naturalCompare(a.roomNumber, b.roomNumber));
  }
  final keys = groups.keys.toList()
    ..sort((a, b) {
      if (a == noFloor) return 1;
      if (b == noFloor) return -1;
      final an = int.tryParse(a);
      final bn = int.tryParse(b);
      if (an != null && bn != null) return an.compareTo(bn);
      if (an != null) return -1;
      if (bn != null) return 1;
      return a.compareTo(b);
    });
  return [for (final key in keys) _FloorGroup(key, groups[key]!)];
}

int _naturalCompare(String a, String b) {
  final an = int.tryParse(a);
  final bn = int.tryParse(b);
  if (an != null && bn != null) return an.compareTo(bn);
  return a.compareTo(b);
}

/// Create/edit form for one numbered room — or, when creating, several at
/// once. Status is only shown when editing — like `_RoomSheet`'s `isActive`,
/// the create endpoint does not accept it and a fresh room always starts
/// `available` server-side. Delete lives here too when editing, so a room has
/// exactly one place a partner opens to do anything to it, rather than a
/// separate menu for status/delete and a separate sheet for the rest.
class _RoomUnitSheet extends ConsumerStatefulWidget {
  const _RoomUnitSheet({required this.roomTypeId, this.room});

  final String roomTypeId;
  final RoomUnit? room;

  @override
  ConsumerState<_RoomUnitSheet> createState() => _RoomUnitSheetState();
}

class _RoomUnitSheetState extends ConsumerState<_RoomUnitSheet> {
  final _form = GlobalKey<FormState>();
  late final _roomNumber = TextEditingController(text: widget.room?.roomNumber ?? '');
  late final _floor = TextEditingController(text: widget.room?.floor ?? '');
  late final _qty = TextEditingController(text: '1');
  late String _status = widget.room?.status ?? 'available';
  bool _busy = false;

  bool get _isCreate => widget.room == null;

  /// Must match the `room_status` enum exactly — anything else is a 400.
  static const _statuses = {
    'available': 'ພ້ອມໃຊ້',
    'maintenance': 'ບຳລຸງຮັກສາ',
    'inactive': 'ປິດໃຊ້ງານ',
  };

  @override
  void initState() {
    super.initState();
    // Only the preview needs to redraw as these change — cheap enough that a
    // full setState on every keystroke is not worth avoiding here.
    _roomNumber.addListener(_refreshPreview);
    _qty.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _roomNumber.removeListener(_refreshPreview);
    _qty.removeListener(_refreshPreview);
    _roomNumber.dispose();
    _floor.dispose();
    _qty.dispose();
    super.dispose();
  }

  void _refreshPreview() => setState(() {});

  int get _quantity => int.tryParse(_qty.text.trim()) ?? 1;

  /// The numbers a batch create would generate — read by both the live
  /// preview and `_save`, so what a partner sees before saving is exactly
  /// what gets sent, never a close approximation of it.
  List<String>? get _generatedNumbers {
    final start = _roomNumber.text.trim();
    if (start.isEmpty) return null;
    return _generateRoomNumbers(start, _quantity);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    final floor = _floor.text.trim();
    final actions = ref.read(actionsProvider);

    if (!_isCreate) {
      setState(() => _busy = true);
      try {
        await actions.updateRoom(
          widget.room!.id,
          roomNumber: _roomNumber.text.trim(),
          floor: floor,
          status: _status,
        );
        if (mounted) Navigator.of(context).pop(true);
      } on ApiException catch (e) {
        if (mounted) showMessage(context, e.message, error: true);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    final numbers = _generatedNumbers;
    if (numbers == null || numbers.isEmpty) return;

    setState(() => _busy = true);
    try {
      if (numbers.length == 1) {
        await actions.createRoom(widget.roomTypeId, numbers.single, floor: floor.isEmpty ? null : floor);
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      final result = await actions.createRooms(widget.roomTypeId, numbers, floor: floor.isEmpty ? null : floor);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      if (result.failed.isEmpty) {
        showMessage(context, 'ເພີ່ມແລ້ວ ${result.created.length} ຫ້ອງ');
      } else if (result.created.isEmpty) {
        showMessage(context, 'ເພີ່ມຫ້ອງບໍ່ສຳເລັດ: ${result.failed.values.first}', error: true);
      } else {
        final skipped = result.failed.keys.join(', ');
        showMessage(
          context,
          'ເພີ່ມແລ້ວ ${result.created.length} ຫ້ອງ · ຂ້າມ $skipped (ມີເລກນີ້ຢູ່ແລ້ວ)',
          error: true,
        );
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final room = widget.room;
    if (room == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ລຶບຫ້ອງ "${room.roomNumber}"?'),
        content: const Text(
          'ຖ້າຫ້ອງນີ້ເຄີຍມີການຈອງ ລະບົບຈະປິດໃຊ້ງານແທນການລຶບ '
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
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final deleted = await ref.read(actionsProvider).deleteRoom(room.id);
      if (mounted) {
        Navigator.of(context).pop(true);
        showMessage(context, deleted ? 'ລຶບຫ້ອງແລ້ວ' : 'ປິດໃຊ້ງານຫ້ອງແລ້ວ (ມີປະຫວັດການຈອງ)');
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _isCreate ? (_generatedNumbers ?? const <String>[]) : const <String>[];
    final showBatchPreview = preview.length > 1;

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
                _isCreate ? 'ເພີ່ມເລກຫ້ອງ' : 'ແກ້ໄຂເລກຫ້ອງ',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _roomNumber,
                decoration: InputDecoration(
                  labelText: _isCreate ? 'ເລກຫ້ອງເລີ່ມຕົ້ນ' : 'ເລກຫ້ອງ',
                  helperText: _isCreate
                      ? 'ເຊັ່ນ: 204 — ຖ້າເພີ່ມຫຼາຍຫ້ອງ ຈະນັບຕໍ່ອັດຕະໂນມັດ'
                      : 'ເຊັ່ນ: 204, 206',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'ໃສ່ເລກຫ້ອງ' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _floor,
                decoration: const InputDecoration(labelText: 'ຊັ້ນ (ຖ້າມີ)'),
              ),
              if (_isCreate) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _qty,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ຈຳນວນຫ້ອງ',
                    helperText: 'ໃສ່ຫຼາຍກວ່າ 1 ເພື່ອສ້າງເລກຕໍ່ກັນທັງໝົດພ້ອມກັນ',
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 1 || n > 100) return '1–100';
                    final startText = _roomNumber.text.trim();
                    if (n > 1 && startText.isNotEmpty && _generateRoomNumbers(startText, n).length == 1) {
                      return 'ເລກຫ້ອງຕ້ອງລົງທ້າຍດ້ວຍໂຕເລກ ເພື່ອສ້າງເປັນຊຸດ';
                    }
                    return null;
                  },
                ),
                if (showBatchPreview) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: C.accentSoft,
                      borderRadius: BorderRadius.circular(R.md),
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final n in preview.take(12))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: C.surface,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              n,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.accentDark),
                            ),
                          ),
                        if (preview.length > 12)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '+${preview.length - 12} ຫ້ອງ',
                              style: const TextStyle(fontSize: 11.5, color: C.accentDark, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
              if (!_isCreate) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'ສະຖານະ'),
                  items: [
                    for (final e in _statuses.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'available'),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        showBatchPreview ? 'ບັນທຶກ ${preview.length} ຫ້ອງ' : 'ບັນທຶກ',
                      ),
              ),
              if (!_isCreate) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _delete,
                  style: OutlinedButton.styleFrom(foregroundColor: C.dangerFg, side: const BorderSide(color: C.dangerBg)),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('ລຶບຫ້ອງ'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Expands a starting room number into `count` sequential numbers, preserving
/// whatever non-digit prefix and zero-padding width the partner typed —
/// `"301"` × 10 → `301..310`; `"A-01"` × 5 → `A-01..A-05`. A number with no
/// trailing digits (e.g. a named suite like "Penthouse") cannot be extended,
/// so anything past the first is silently dropped rather than guessed at —
/// the quantity validator is what turns that into a message the partner sees
/// before they ever hit save.
List<String> _generateRoomNumbers(String start, int count) {
  if (count <= 1 || start.isEmpty) return [start];
  final match = RegExp(r'^(.*?)(\d+)$').firstMatch(start);
  if (match == null) return [start];

  final prefix = match.group(1)!;
  final digits = match.group(2)!;
  final width = digits.length;
  final startNum = int.parse(digits);

  return List.generate(count, (i) => '$prefix${(startNum + i).toString().padLeft(width, '0')}');
}
