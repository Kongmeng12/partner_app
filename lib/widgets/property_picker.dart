import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';

/// Bottom sheet for choosing which property the Calendar shows. Only worth
/// opening for a partner who owns more than one.
Future<void> pickCalendarProperty(
  BuildContext context,
  WidgetRef ref,
  List<Property> properties,
  String currentId,
) async {
  final picked = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: C.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
    ),
    builder:
        (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in properties)
                ListTile(
                  title: Text(p.name),
                  trailing:
                      p.id == currentId
                          ? const Icon(Icons.check, color: C.accent)
                          : null,
                  onTap: () => Navigator.of(context).pop(p.id),
                ),
            ],
          ),
        ),
  );
  if (picked != null) ref.read(selectedPropertyProvider.notifier).set(picked);
}
