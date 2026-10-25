import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../components/components.dart';

/// Up to [max] evidence photos (camera or gallery), compressed on pick.
class EvidencePicker extends StatelessWidget {
  const EvidencePicker({super.key, required this.paths, required this.onChanged, this.max = 3});

  final List<String> paths;
  final ValueChanged<List<String>> onChanged;
  final int max;

  Future<void> _add(BuildContext context) async {
    final source = await PsBottomSheet.options<ImageSource>(
      context,
      title: 'Add photo',
      options: const [
        PsSheetOption(value: ImageSource.camera, label: 'Take a photo', icon: Icons.photo_camera_outlined),
        PsSheetOption(value: ImageSource.gallery, label: 'Choose from gallery', icon: Icons.photo_library_outlined),
      ],
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1600);
      if (picked != null) onChanged([...paths, picked.path]);
    } catch (_) {
      if (context.mounted) PsToast.error(context, 'Couldn’t open the ${source == ImageSource.camera ? 'camera' : 'gallery'}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: PsSpace.xs,
      runSpacing: PsSpace.xs,
      children: [
        for (final p in paths)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(p), width: 80, height: 80, fit: BoxFit.cover),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: InkWell(
                  onTap: () => onChanged([...paths]..remove(p)),
                  child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close_rounded, size: 14, color: Colors.white)),
                ),
              ),
            ],
          ),
        if (paths.length < max)
          Semantics(
            button: true,
            label: 'Add photo',
            child: InkWell(
              onTap: () => _add(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: PsColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PsColors.border, width: 1.4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded, color: PsColors.textSecondary),
                    Text('Add Photo', style: PsText.caption.copyWith(fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
