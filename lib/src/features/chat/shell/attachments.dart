// ignore_for_file: invalid_use_of_protected_member
part of '../home_shell.dart';

extension _HomeShellAttachments on _HomeShellState {
  void _removeAttachment() {
    setState(() {
      _attachedImagePath = null;
      _attachedImageBytes = null;
    });
  }

  void _toggleAttachmentMenu() {
    HapticFeedback.selectionClick();
    setState(() {
      _attachmentMenuOpen = !_attachmentMenuOpen;
    });
  }

  void _closeAttachmentMenu() {
    if (_attachmentMenuOpen) {
      setState(() {
        _attachmentMenuOpen = false;
      });
    }
  }

  Future<void> _pickFromCamera() async {
    _closeAttachmentMenu();
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (photo != null && mounted) {
        final bytes = await photo.readAsBytes();
        // HEIC check: picker should return JPEG but guard anyway
        final isHeic = photo.path.toLowerCase().endsWith('.heic') ||
            photo.path.toLowerCase().endsWith('.heif');
        if (isHeic) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text(L10n.of(context).chatHeicNotSupported),
                  behavior: SnackBarBehavior.floating,
                ),
              );
          }
          return;
        }
        setState(() {
          _attachedImagePath = photo.path;
          _attachedImageBytes = bytes;
        });
        // Warn if multimodal not loaded
        _warnIfMultimodalMissing(photo.path);
      }
    } catch (e) {
      debugPrint('Camera capture error: $e');
      _showAttachmentFailure();
    }
  }

  void _showAttachmentFailure() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(L10n.of(context).chatAttachmentPickFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _pickFromGallery() async {
    _closeAttachmentMenu();
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image != null && mounted) {
        final isHeic = image.path.toLowerCase().endsWith('.heic') ||
            image.path.toLowerCase().endsWith('.heif');
        if (isHeic) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text(L10n.of(context).chatHeicNotSupported),
                  behavior: SnackBarBehavior.floating,
                ),
              );
          }
          return;
        }
        final bytes = await image.readAsBytes();
        setState(() {
          _attachedImagePath = image.path;
          _attachedImageBytes = bytes;
        });
        _warnIfMultimodalMissing(image.path);
      }
    } catch (e) {
      debugPrint('Gallery picker error: $e');
      _showAttachmentFailure();
    }
  }

  Future<void> _pickFromFileSystem() async {
    _closeAttachmentMenu();
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'heic',
          'txt',
          'md',
          'json',
          'csv',
        ],
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null && mounted) {
        final path = result.files.single.path!;
        final isHeic = path.toLowerCase().endsWith('.heic') ||
            path.toLowerCase().endsWith('.heif');
        if (isHeic) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  content: Text(L10n.of(context).chatHeicNotSupported),
                  behavior: SnackBarBehavior.floating,
                ),
              );
          }
          return;
        }
        setState(() {
          _attachedImagePath = path;
          _attachedImageBytes = result.files.single.bytes;
        });
        if (_isImageAttachmentPath(path)) {
          _warnIfMultimodalMissing(path);
        }
      }
    } catch (e) {
      debugPrint('File picker error: $e');
      _showAttachmentFailure();
    }
  }
}
