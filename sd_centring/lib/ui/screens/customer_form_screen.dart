import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/file_store.dart';
import '../../models/customer.dart';
import '../../services/media_picker.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/form_section.dart';
import '../widgets/rental_tile.dart';
import '../widgets/stored_image.dart';

const _uuid = Uuid();

/// A document in the form: either already uploaded, or picked and waiting
/// to be uploaded on save.
class _DocDraft {
  _DocDraft.existing(CustomerDoc d)
    : id = d.id,
      kind = d.kind,
      fileName = d.fileName,
      contentType = d.contentType,
      sizeBytes = d.sizeBytes,
      existing = d,
      bytes = null;

  _DocDraft.picked(PickedMedia m, this.kind)
    : id = _uuid.v4(),
      fileName = m.name,
      contentType = m.contentType,
      sizeBytes = m.bytes.length,
      existing = null,
      bytes = m.bytes;

  final String id;
  String kind;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final CustomerDoc? existing;
  final Uint8List? bytes;

  bool get isPdf => contentType == 'application/pdf';
}

String _ext(String contentType) => switch (contentType) {
  'application/pdf' => 'pdf',
  'image/png' => 'png',
  'image/webp' => 'webp',
  _ => 'jpg',
};

String formatBytes(int b) => b >= 1024 * 1024
    ? '${(b / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(b / 1024).ceil()} KB';

/// Add or edit a customer, including profile photo and ID / address proofs.
/// Pops with the saved [Customer].
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.existing, this.initialName = ''});

  final Customer? existing;
  final String initialName;

  static Future<Customer?> open(
    BuildContext context, {
    Customer? existing,
    String initialName = '',
  }) => Navigator.of(context).push<Customer>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          CustomerFormScreen(existing: existing, initialName: initialName),
    ),
  );

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.existing?.name ?? widget.initialName,
  );
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _altPhone = TextEditingController(
    text: widget.existing?.altPhone ?? '',
  );
  late final _address = TextEditingController(
    text: widget.existing?.address ?? '',
  );
  late final _referredBy = TextEditingController(
    text: widget.existing?.referredBy ?? '',
  );
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');

  // Photo: a newly picked one, or the existing URL (unless removed).
  PickedMedia? _newPhoto;
  bool _removePhoto = false;

  late final List<_DocDraft> _docs = [
    for (final d in widget.existing?.documents ?? const <CustomerDoc>[])
      _DocDraft.existing(d),
  ];

  bool _saving = false;
  bool _dirty = false;
  String? _status;

  List<TextEditingController> get _controllers => [
    _name,
    _phone,
    _altPhone,
    _address,
    _referredBy,
    _notes,
  ];

  String get _existingPhoto =>
      _removePhoto ? '' : widget.existing?.photoUrl ?? '';

  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  // ── Photo ────────────────────────────────────────────────────────────────

  Future<void> _photoOptions() async {
    final hasPhoto = _newPhoto != null || _existingPhoto.isNotEmpty;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: SdColors.expired,
                ),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: SdColors.expired),
                ),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'remove') {
      setState(() {
        _newPhoto = null;
        _removePhoto = true;
        _dirty = true;
      });
      return;
    }
    try {
      final picked = await MediaPicker.instance.photo(
        camera: choice == 'camera',
      );
      if (picked == null || !mounted) return;
      setState(() {
        _newPhoto = picked;
        _removePhoto = true; // replace the old one
        _dirty = true;
      });
    } catch (e) {
      _toast(
        'Could not open the ${choice == 'camera' ? 'camera' : 'gallery'}.',
      );
    }
  }

  // ── Documents ────────────────────────────────────────────────────────────

  Future<void> _addDocument({required bool camera, required bool file}) async {
    try {
      final picked = file
          ? await MediaPicker.instance.documentFile()
          : await MediaPicker.instance.documentPhoto(camera: camera);
      if (picked == null || !mounted) return;
      if (picked.bytes.length > maxUploadBytes) {
        _toast('That file is larger than 10 MB. Choose a smaller one.');
        return;
      }
      final used = _docs.map((d) => d.kind).toSet();
      final kind = documentKinds.firstWhere(
        (k) => !used.contains(k),
        orElse: () => 'Other',
      );
      setState(() {
        _docs.add(_DocDraft.picked(picked, kind));
        _dirty = true;
      });
    } catch (e) {
      _toast('Could not open ${file ? 'files' : 'the camera'}.');
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  String? _validatePhone(String? v, {required bool required}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return required ? 'Required' : null;
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10 || digits.length > 13) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final app = context.read<AppState>();
    final phone = normalizePhone(_phone.text);

    final key = phoneKey(phone);
    final dup = app.customers.where(
      (c) => c.id != widget.existing?.id && phoneKey(c.phone) == key,
    );
    if (dup.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Phone number already used'),
          content: Text(
            '${dup.first.name} already has this number. Save anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    setState(() => _saving = true);
    final files = app.files;
    final e = widget.existing;
    final id = e?.id ?? _uuid.v4();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final failures = <String>[];
    final toDelete = <String>[];

    // Photo.
    var photoUrl = e?.photoUrl ?? '';
    if (_newPhoto != null) {
      setState(() => _status = 'Uploading photo…');
      try {
        final url = await files.upload(
          path: 'customers/$id/photo_$stamp.${_ext(_newPhoto!.contentType)}',
          bytes: _newPhoto!.bytes,
          contentType: _newPhoto!.contentType,
        );
        if (photoUrl.isNotEmpty) toDelete.add(photoUrl);
        photoUrl = url;
      } on FileStoreException catch (err) {
        failures.add('Photo: ${err.message}');
      }
    } else if (_removePhoto && photoUrl.isNotEmpty) {
      toDelete.add(photoUrl);
      photoUrl = '';
    }

    // Documents.
    final docs = <CustomerDoc>[];
    final pending = _docs.where((d) => d.existing == null).toList();
    var n = 0;
    for (final d in _docs) {
      if (d.existing != null) {
        docs.add(
          CustomerDoc(
            id: d.id,
            kind: d.kind,
            fileName: d.existing!.fileName,
            url: d.existing!.url,
            contentType: d.existing!.contentType,
            sizeBytes: d.existing!.sizeBytes,
            uploadedAt: d.existing!.uploadedAt,
          ),
        );
        continue;
      }
      n++;
      setState(() => _status = 'Uploading document $n of ${pending.length}…');
      try {
        final url = await files.upload(
          path: 'customers/$id/docs/${d.id}.${_ext(d.contentType)}',
          bytes: d.bytes!,
          contentType: d.contentType,
        );
        docs.add(
          CustomerDoc(
            id: d.id,
            kind: d.kind,
            fileName: d.fileName,
            url: url,
            contentType: d.contentType,
            sizeBytes: d.sizeBytes,
            uploadedAt: DateTime.now(),
          ),
        );
      } on FileStoreException catch (err) {
        failures.add('${d.kind} (${d.fileName}): ${err.message}');
      }
    }
    final keptIds = docs.map((d) => d.id).toSet();
    for (final old in e?.documents ?? const <CustomerDoc>[]) {
      if (!keptIds.contains(old.id)) toDelete.add(old.url);
    }

    final customer = e == null
        ? Customer(
            id: id,
            name: _name.text.trim(),
            phone: phone,
            altPhone: normalizePhone(_altPhone.text),
            address: _address.text.trim(),
            referredBy: _referredBy.text.trim(),
            notes: _notes.text.trim(),
            photoUrl: photoUrl,
            documents: docs,
            createdAt: DateTime.now(),
          )
        : e.copyWith(
            name: _name.text.trim(),
            phone: phone,
            altPhone: normalizePhone(_altPhone.text),
            address: _address.text.trim(),
            referredBy: _referredBy.text.trim(),
            notes: _notes.text.trim(),
            photoUrl: photoUrl,
            documents: docs,
          );
    await app.saveCustomer(customer);
    for (final url in toDelete) {
      unawaited(files.delete(url));
    }
    if (!mounted) return;

    if (failures.isNotEmpty) {
      // The details are saved; say plainly which files are missing.
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Saved, but some files did not upload'),
          content: Text(
            '${failures.join('\n')}\n\nOpen the customer and add them again '
            'when the connection is better.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
    }
    Navigator.of(context).pop(customer);
  }

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('What you entered on this screen will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const CloseButton(),
          title: Text(
            widget.existing == null ? 'New customer' : 'Edit customer',
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: const Text(
                'SAVE',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        bottomNavigationBar: SaveBar(
          label: _saving ? (_status ?? 'Saving…') : 'Save customer',
          onPressed: _saving ? null : _save,
        ),
        body: PageWidth(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // ── Photo ───────────────────────────────────────────────
                Center(child: _photoPicker()),
                const SizedBox(height: 16),

                FormSection(
                  icon: Icons.person_rounded,
                  title: 'Contact',
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Name *',
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone *',
                        prefixIcon: Icon(Icons.call_rounded),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => _validatePhone(v, required: true),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _altPhone,
                      decoration: const InputDecoration(
                        labelText: 'Alternate phone',
                        prefixIcon: Icon(Icons.phone_forwarded_rounded),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => _validatePhone(v, required: false),
                    ),
                  ],
                ),

                // ── Documents ───────────────────────────────────────────
                FormSection(
                  icon: Icons.badge_outlined,
                  title: 'ID & address proof',
                  trailing: Text(
                    _docs.isEmpty ? 'None yet' : '${_docs.length}',
                    style: theme.textTheme.bodySmall,
                  ),
                  children: [
                    for (var i = 0; i < _docs.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _docRow(_docs[i]),
                    ],
                    if (_docs.isEmpty)
                      Text(
                        'Aadhaar, PAN, voter ID or a utility bill. '
                        'Photo or PDF, up to 10 MB.',
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _addDocument(camera: true, file: false),
                            icon: const Icon(
                              Icons.document_scanner_rounded,
                              size: 18,
                            ),
                            label: const Text('Take photo'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _addDocument(camera: false, file: true),
                            icon: const Icon(
                              Icons.upload_file_rounded,
                              size: 18,
                            ),
                            label: const Text('Upload file'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                FormSection(
                  icon: Icons.place_rounded,
                  title: 'Address & notes',
                  children: [
                    TextFormField(
                      controller: _address,
                      decoration: const InputDecoration(labelText: 'Address'),
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _referredBy,
                      decoration: const InputDecoration(
                        labelText: 'Referred by',
                        prefixIcon: Icon(Icons.handshake_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notes,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
                if (_saving && _status != null) ...[
                  const SizedBox(height: 4),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoPicker() {
    final sd = context.sd;
    Widget image;
    if (_newPhoto != null) {
      image = Image.memory(_newPhoto!.bytes, fit: BoxFit.cover);
    } else if (_existingPhoto.isNotEmpty) {
      image = StoredImage(_existingPhoto);
    } else {
      image = Container(
        color: sd.field,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_rounded, color: sd.muted, size: 28),
            const SizedBox(height: 4),
            Text(
              'Add photo',
              style: TextStyle(
                color: sd.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    return Semantics(
      button: true,
      label: 'Customer photo',
      child: GestureDetector(
        onTap: _saving ? null : _photoOptions,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: SizedBox(width: 104, height: 104, child: image),
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: SdColors.ember,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _docRow(_DocDraft d) {
    final theme = Theme.of(context);
    final sd = context.sd;
    Widget thumb;
    if (d.isPdf) {
      thumb = Container(
        color: SdColors.expired.withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: const Icon(
          Icons.picture_as_pdf_rounded,
          color: SdColors.expired,
        ),
      );
    } else if (d.bytes != null) {
      thumb = Image.memory(d.bytes!, fit: BoxFit.cover);
    } else {
      thumb = StoredImage(d.existing!.url);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 44, height: 44, child: thumb),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Document type',
                  initialValue: d.kind,
                  onSelected: (k) => setState(() {
                    d.kind = k;
                    _dirty = true;
                  }),
                  itemBuilder: (_) => [
                    for (final k in documentKinds)
                      PopupMenuItem(value: k, child: Text(k)),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(d.kind, style: theme.textTheme.titleSmall),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                        color: sd.muted,
                      ),
                    ],
                  ),
                ),
                Text(
                  [
                    d.fileName,
                    formatBytes(d.sizeBytes),
                    if (d.existing == null) 'uploads on save',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove document',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: const Icon(Icons.close_rounded),
            onPressed: _saving
                ? null
                : () => setState(() {
                    _docs.remove(d);
                    _dirty = true;
                  }),
          ),
        ],
      ),
    );
  }
}
