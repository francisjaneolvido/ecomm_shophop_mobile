import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shophop/features/rider/data/models/rider_assignment.dart';

class RiderDeliveryConfirmation {
  const RiderDeliveryConfirmation(this.proof, this.cashCollected);
  final PlatformFile proof;
  final bool cashCollected;
}

class RiderDeliveryCompletion extends StatefulWidget {
  const RiderDeliveryCompletion({
    super.key,
    required this.assignment,
    this.pickProof,
    this.captureProof,
  });
  final RiderAssignment assignment;
  final Future<PlatformFile?> Function()? pickProof;
  final Future<PlatformFile?> Function()? captureProof;

  @override
  State<RiderDeliveryCompletion> createState() =>
      _RiderDeliveryCompletionState();
}

class _RiderDeliveryCompletionState extends State<RiderDeliveryCompletion> {
  PlatformFile? _proof;
  bool _cashCollected = false;
  bool _picking = false;
  String? _error;

  Future<PlatformFile?> _cameraPhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
      requestFullMetadata: false,
    );
    if (photo == null) return null;
    final bytes = await photo.readAsBytes();
    return PlatformFile(name: photo.name, size: bytes.length, bytes: bytes);
  }

  Future<void> _chooseProof({bool camera = false}) async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final selected = camera
          ? await (widget.captureProof ?? _cameraPhoto)()
          : widget.pickProof != null
          ? await widget.pickProof!()
          : (await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
              allowMultiple: false,
              withData: true,
            ))?.files.firstOrNull;
      if (!mounted || selected == null) return;
      final ext = selected.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext) ||
          selected.size <= 0 ||
          selected.size > 5 * 1024 * 1024) {
        setState(() {
          _error = 'Choose a JPG, PNG, or WebP image up to 5 MB.';
        });
        return;
      }
      setState(() => _proof = selected);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _error =
              error.code.contains('denied') || error.code.contains('restricted')
              ? 'Camera access is disabled. Allow camera access in your phone settings, or choose a delivery photo.'
              : 'Could not open ${camera ? 'the camera' : 'photos'}. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not open the photo. Please choose it again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignment = widget.assignment;
    final ready =
        !_picking && _proof != null && (!assignment.isCod || _cashCollected);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Complete delivery',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              assignment.deliveryName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(assignment.trackingCode),
            const SizedBox(height: 12),
            const Text(
              'Confirm only after handing the parcel to the buyer. No additional QR scan is needed.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Proof of delivery',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Text(
              'Take a clear photo of the delivered parcel, or choose one. JPG, PNG, or WebP, up to 5 MB.',
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _picking ? null : () => _chooseProof(camera: true),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Open camera'),
            ),
            OutlinedButton.icon(
              onPressed: _picking ? null : () => _chooseProof(),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _picking
                    ? 'Opening...'
                    : _proof == null
                    ? 'Choose delivery photo'
                    : 'Change photo',
              ),
            ),
            if (_proof != null)
              Text(_proof!.name, key: const Key('delivery-proof-name')),
            if (_proof?.bytes != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Image.memory(
                  _proof!.bytes!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Text('Photo selected. Preview unavailable.'),
                ),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            if (assignment.isCod)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'I collected PHP ${assignment.totalAmount} from the buyer',
                ),
                subtitle: const Text(
                  'If you did not receive the full amount, cancel and report a delivery problem.',
                ),
                value: _cashCollected,
                onChanged: (value) =>
                    setState(() => _cashCollected = value == true),
              )
            else
              const Text(
                'Already paid. Do not collect payment from the buyer.',
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: ready
                    ? () => Navigator.pop(
                        context,
                        RiderDeliveryConfirmation(
                          _proof!,
                          assignment.isCod && _cashCollected,
                        ),
                      )
                    : null,
                icon: const Icon(Icons.task_alt),
                label: const Text('Confirm delivered'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
