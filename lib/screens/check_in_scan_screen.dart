import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/api_client.dart';
import '../providers/data.dart';
import '../theme/tokens.dart';

/// The front desk's camera: point it at the guest's check-in QR (in their
/// app, on the PDF, or printed) and it opens that booking's check-in check.
///
/// The code is only read here — the server decides what it is. A forged or
/// printed `STL-…` code, or another property's booking, comes back with the
/// reason and the camera waits to be pointed again. Nothing is changed by a
/// scan; the check-in itself happens on the next screen, after the ID check.
class CheckInScanScreen extends ConsumerStatefulWidget {
  const CheckInScanScreen({super.key});

  @override
  ConsumerState<CheckInScanScreen> createState() => _CheckInScanScreenState();
}

class _CheckInScanScreenState extends ConsumerState<CheckInScanScreen> {
  final _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_checking || _error != null) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .where((v) => v.trim().isNotEmpty)
        .firstOrNull;
    if (raw == null) return;

    setState(() => _checking = true);
    await _camera.stop();
    try {
      final bookingId = await ref.read(actionsProvider).scanCheckIn(raw);
      if (!mounted) return;
      context.pushReplacement('/bookings/$bookingId/check-in');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'ເຊື່ອມຕໍ່ບໍ່ໄດ້ ກະລຸນາລອງໃໝ່');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _scanAgain() async {
    setState(() => _error = null);
    await _camera.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ສະແກນ QR ເຊັກອິນ'),
        actions: [
          IconButton(
            tooltip: 'ໄຟສາຍ',
            onPressed: () => _camera.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraProblem(error: error),
          ),
          // Where to aim — the scanner reads the whole frame, the square just
          // tells staff roughly how close to hold it.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: C.accent, width: 3),
                borderRadius: BorderRadius.circular(R.xl),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _BottomPanel(
              checking: _checking,
              error: _error,
              onScanAgain: _scanAgain,
              onSearchByCode: () => context.go('/bookings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.checking,
    required this.error,
    required this.onScanAgain,
    required this.onSearchByCode,
  });

  final bool checking;
  final String? error;
  final VoidCallback onScanAgain;
  final VoidCallback onSearchByCode;

  @override
  Widget build(BuildContext context) {
    final problem = error;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: problem != null ? C.dangerBg : C.surface,
        borderRadius: BorderRadius.circular(R.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (checking)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: C.accent),
                ),
                SizedBox(width: 10),
                Text('ກຳລັງກວດ QR…', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            )
          else if (problem != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: C.dangerFg, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    problem,
                    style: const TextStyle(fontSize: 13.5, color: C.dangerFg, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onScanAgain,
              icon: const Icon(Icons.qr_code_scanner, size: 19),
              label: const Text('ສະແກນໃໝ່'),
            ),
          ] else
            const Text(
              'ສ່ອງກ້ອງໃສ່ QR ເຊັກອິນ ໃນແອັບ ຫຼື ໃບຢືນຢັນຂອງແຂກ',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: C.soft, height: 1.4),
            ),
          if (!checking)
            TextButton(
              onPressed: onSearchByCode,
              child: const Text('ບໍ່ມີ QR? ຄົ້ນຫາດ້ວຍລະຫັດຈອງ ຫຼື ຊື່ແຂກ'),
            ),
        ],
      ),
    );
  }
}

/// No camera, or no permission to use it — say which, rather than a black
/// screen that looks like the app froze.
class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            denied
                ? 'ແອັບຍັງບໍ່ໄດ້ຮັບອະນຸຍາດໃຫ້ໃຊ້ກ້ອງ\nເປີດໄດ້ທີ່ ການຕັ້ງຄ່າ › ແອັບ › PhaPhak Partner › ສິດ'
                : 'ເປີດກ້ອງບໍ່ໄດ້ · ${error.errorCode.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
          ),
        ),
      ),
    );
  }
}
