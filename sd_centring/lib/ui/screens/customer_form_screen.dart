import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Draft key for the new customer form (see [DraftStore]).
const newCustomerDraftKey = 'new_customer';

/// A document in the form: either already saved on the customer, or picked
/// in this form and uploaded when the customer is saved.
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

  /// Set once uploaded, so "Try again" never uploads it twice.
  String? uploadedUrl;

  /// Why the last upload attempt failed.
  String? problem;

  bool get isPdf => contentType == 'application/pdf';
  bool get needsUpload => existing == null && uploadedUrl == null;
}

enum _UploadChoice { retry, saveWithout, keepEditing }

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
///
/// Nothing is written until every picked file has uploaded, or the user
/// chooses to save without the ones that failed; picked files are kept in
/// the form so a failed upload can simply be tried again.
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
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');

  /// Same id across retries, so uploaded files land in one folder.
  late final String _id = widget.existing?.id ?? _uuid.v4();

  // Photo: a newly picked one, or the existing URL (unless removed).
  PickedMedia? _newPhoto;
  String? _newPhotoUrl;
  String? _photoProblem;
  bool _removePhoto = false;

  late final List<_DocDraft> _docs = [
    for (final d in widget.existing?.documents ?? const <CustomerDoc>[])
      _DocDraft.existing(d),
  ];

  /// Every file uploaded while this form was open. Whatever the saved
  /// customer does not end up using is deleted again.
  final _sessionUploads = <String>[];

  bool _saving = false;
  bool _saved = false;
  bool _dirty = false;
  String? _status;

  /// Files picked before the app was closed (for the restore notice).
  int _restoredFiles = 0;
  bool _restored = false;

  bool get _isNew => widget.existing == null;

  List<TextEditingController> get _controllers => [
    _name,
    _phone,
    _altPhone,
    _address,
    _notes,
  ];

  String get _existingPhoto =>
      _removePhoto ? '' : widget.existing?.photoUrl ?? '';

  @override
  void initState() {
    super.initState();
    if (_isNew) _restoreDraft();
    for (final c in _controllers) {
      c.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    if (!_dirty && mounted) setState(() => _dirty = true);
    _saveDraft();
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  // ── Draft (new customers only) ───────────────────────────────────────────

  void _restoreDraft() {
    final d = context.read<AppState>().drafts.read(newCustomerDraftKey);
    if (d == null) return;
    final text = ['name', 'phone', 'altPhone', 'address', 'notes'];
    if (text.every((k) => (d[k] ?? '').trim().isEmpty)) return;
    _name.text = d['name'] ?? '';
    _phone.text = d['phone'] ?? '';
    _altPhone.text = d['altPhone'] ?? '';
    _address.text = d['address'] ?? '';
    _notes.text = d['notes'] ?? '';
    _restoredFiles = int.tryParse(d['files'] ?? '') ?? 0;
    _restored = true;
    _dirty = true;
  }

  void _saveDraft() {
    if (!_isNew || _saved) return;
    final files = (_newPhoto != null ? 1 : 0) + _docs.length;
    context.read<AppState>().drafts.write(newCustomerDraftKey, {
      'name': _name.text,
      'phone': _phone.text,
      'altPhone': _altPhone.text,
      'address': _address.text,
      'notes': _notes.text,
      'files': '$files',
    });
  }

  void _clearDraft() {
    if (_isNew) context.read<AppState>().drafts.clear(newCustomerDraftKey);
  }

  void _startOver() {
    for (final c in _controllers) {
      c.clear();
    }
    _clearDraft();
    setState(() {
      _restored = false;
      _restoredFiles = 0;
      _dirty = false;
    });
  }

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
        _newPhotoUrl = null;
        _photoProblem = null;
        _removePhoto = true;
        _dirty = true;
      });
      _saveDraft();
      return;
    }
    try {
      final picked = await MediaPicker.instance.photo(
        camera: choice == 'camera',
      );
      if (picked == null || !mounted) return;
      if (picked.bytes.length > maxUploadBytes) {
        _toast('That photo is larger than 10 MB. Choose a smaller one.');
        return;
      }
      setState(() {
        _newPhoto = picked;
        _newPhotoUrl = null;
        _photoProblem = null;
        _removePhoto = true; // replaces the old one once saved
        _dirty = true;
      });
      _saveDraft();
    } catch (e) {
      _toast(
        'Could not open the ${choice == 'camera' ? 'camera' : 'gallery'}.',
      );
    }
  }

  // ── Documents ────────────────────────────────────────────────────────────

  Future<void> _addDocument({required bool file}) async {
    try {
      final picked = file
          ? await MediaPicker.instance.documentFile()
          : await MediaPicker.instance.documentPhoto(camera: true);
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
      _saveDraft();
    } catch (e) {
      _toast('Could not open ${file ? 'files' : 'the camera'}.');
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  String? _altPhoneProblem(String? v) {
    final problem = phoneProblem(v ?? '', required: false);
    if (problem != null) return problem;
    final alt = phoneKey(v ?? '');
    if (alt.isNotEmpty && alt == phoneKey(_phone.text)) {
      return 'Same as the main number';
    }
    return null;
  }

  Future<bool> _confirmDuplicate(List<Customer> matches) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Number already saved'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              matches.length == 1
                  ? 'This number belongs to another customer:'
                  : 'This number belongs to other customers:',
            ),
            const SizedBox(height: 8),
            for (final c in matches.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${c.name}  ${c.phone}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(height: 4),
            const Text('Save this customer anyway?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save anyway'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  /// Uploads every picked file that is not uploaded yet. Returns how many
  /// failed. After a connection failure the rest are skipped rather than
  /// each waiting for its own timeout.
  Future<int> _uploadPending() async {
    final files = context.read<AppState>().files;
    final docs = _docs.where((d) => d.needsUpload).toList();
    final photo = _newPhoto != null && _newPhotoUrl == null;
    final total = docs.length + (photo ? 1 : 0);
    var n = 0;
    var failed = 0;
    String? offline;

    Future<String?> upload(
      String what,
      String path,
      Uint8List bytes,
      String contentType,
      void Function(String? problem) setProblem,
    ) async {
      n++;
      if (offline != null) {
        failed++;
        setProblem(offline);
        return null;
      }
      setState(
        () => _status = total == 1
            ? 'Uploading $what…'
            : 'Uploading file $n of $total…',
      );
      try {
        final url = await files.upload(
          path: path,
          bytes: bytes,
          contentType: contentType,
        );
        _sessionUploads.add(url);
        setProblem(null);
        return url;
      } on FileStoreException catch (e) {
        failed++;
        if (e.noConnection) offline = e.message;
        setProblem(e.message);
        return null;
      }
    }

    if (photo) {
      final p = _newPhoto!;
      _newPhotoUrl = await upload(
        'photo',
        'customers/$_id/photo_${DateTime.now().millisecondsSinceEpoch}'
            '.${_ext(p.contentType)}',
        p.bytes,
        p.contentType,
        (problem) => _photoProblem = problem,
      );
    }
    for (final d in docs) {
      d.uploadedUrl = await upload(
        d.kind,
        'customers/$_id/docs/${d.id}.${_ext(d.contentType)}',
        d.bytes!,
        d.contentType,
        (problem) => d.problem = problem,
      );
    }
    if (mounted) setState(() => _status = null);
    return failed;
  }

  Future<_UploadChoice> _askAboutFailedUploads(int failed) async {
    final lines = [
      if (_photoProblem != null) 'Photo: $_photoProblem',
      for (final d in _docs)
        if (d.problem != null) '${d.kind} (${d.fileName}): ${d.problem}',
    ];
    final choice = await showDialog<_UploadChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          failed == 1
              ? '1 file did not upload'
              : '$failed files did not upload',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $l'),
              ),
            const SizedBox(height: 6),
            const Text(
              'The customer is not saved yet. Try again, or save the details '
              'now and add the files later from the customer page.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _UploadChoice.keepEditing),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _UploadChoice.saveWithout),
            child: const Text('Save without them'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _UploadChoice.retry),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
    return choice ?? _UploadChoice.keepEditing;
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _toast('Please fix the highlighted fields.');
      return;
    }
    final app = context.read<AppState>();
    final phone = normalizePhone(_phone.text);
    final altPhone = normalizePhone(_altPhone.text);

    final matches = app.customersWithPhone([
      phone,
      altPhone,
    ], exceptId: widget.existing?.id);
    if (matches.isNotEmpty && !await _confirmDuplicate(matches)) return;
    if (!mounted) return;

    setState(() => _saving = true);
    while (true) {
      final failed = await _uploadPending();
      if (!mounted) return;
      if (failed == 0) break;
      final choice = await _askAboutFailedUploads(failed);
      if (!mounted) return;
      if (choice == _UploadChoice.retry) continue;
      if (choice == _UploadChoice.keepEditing) {
        setState(() => _saving = false);
        return;
      }
      break; // save without the failed files
    }

    final e = widget.existing;

    // Photo: a failed new photo keeps the old one rather than losing both.
    final String photoUrl;
    if (_newPhotoUrl != null) {
      photoUrl = _newPhotoUrl!;
    } else if (_newPhoto == null && _removePhoto) {
      photoUrl = '';
    } else {
      photoUrl = e?.photoUrl ?? '';
    }

    final docs = <CustomerDoc>[
      for (final d in _docs)
        if (d.existing != null)
          CustomerDoc(
            id: d.id,
            kind: d.kind,
            fileName: d.existing!.fileName,
            url: d.existing!.url,
            contentType: d.existing!.contentType,
            sizeBytes: d.existing!.sizeBytes,
            uploadedAt: d.existing!.uploadedAt,
          )
        else if (d.uploadedUrl != null)
          CustomerDoc(
            id: d.id,
            kind: d.kind,
            fileName: d.fileName,
            url: d.uploadedUrl!,
            contentType: d.contentType,
            sizeBytes: d.sizeBytes,
            uploadedAt: DateTime.now(),
          ),
    ];

    final name = tidyText(_name.text);
    final customer = e == null
        ? Customer(
            id: _id,
            name: name,
            phone: phone,
            altPhone: altPhone,
            address: _address.text.trim(),
            notes: _notes.text.trim(),
            photoUrl: photoUrl,
            documents: docs,
            createdAt: DateTime.now(),
          )
        : e.copyWith(
            name: name,
            phone: phone,
            altPhone: altPhone,
            address: _address.text.trim(),
            notes: _notes.text.trim(),
            photoUrl: photoUrl,
            documents: docs,
          );
    await app.saveCustomer(customer);

    // Remove files the customer no longer uses.
    final used = {customer.photoUrl, ...docs.map((d) => d.url)};
    final unused = <String>{
      if (e != null && e.photoUrl.isNotEmpty) e.photoUrl,
      ...?e?.documents.map((d) => d.url),
      ..._sessionUploads,
    }.difference(used);
    for (final url in unused) {
      unawaited(app.files.delete(url));
    }

    _clearDraft();
    _saved = true;
    if (!mounted) return;
    Navigator.of(context).pop(customer);
  }

  Future<void> _onBack() async {
    if (_saving) {
      _toast('Please wait, saving…');
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this customer?'),
        content: Text(
          _isNew
              ? 'What you entered on this screen will be lost.'
              : 'Your changes on this screen will be lost.',
        ),
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
    if (leave != true || !mounted) return;
    final files = context.read<AppState>().files;
    for (final url in _sessionUploads) {
      unawaited(files.delete(url));
    }
    _clearDraft();
    _saved = true; // nothing left to protect
    Navigator.of(context).pop();
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: _saved || (!_dirty && _sessionUploads.isEmpty),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const CloseButton(),
          title: Text(_isNew ? 'New customer' : 'Edit customer'),
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
                if (_restored) _restoredBanner(),

                // Who: photo beside the name and number.
                FormSection(
                  icon: Icons.person_rounded,
                  title: 'Customer',
                  children: [
                    LayoutBuilder(
                      builder: (context, box) {
                        final fields = Column(
                          children: [
                            TextFormField(
                              controller: _name,
                              autofocus: _isNew && !_restored,
                              decoration: const InputDecoration(
                                labelText: 'Name *',
                              ),
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(
                                  CustomerLimits.name,
                                ),
                              ],
                              validator: (v) => tidyText(v ?? '').isEmpty
                                  ? 'Enter the customer name'
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone *',
                              ),
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              inputFormatters: _phoneFormatters,
                              validator: (v) =>
                                  phoneProblem(v ?? '', required: true),
                            ),
                          ],
                        );
                        // Very narrow screens: photo above the fields.
                        if (box.maxWidth < 240) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _photoPicker(),
                              const SizedBox(height: 12),
                              fields,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _photoPicker(),
                            const SizedBox(width: 12),
                            Expanded(child: fields),
                          ],
                        );
                      },
                    ),
                    if (_photoProblem != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Photo not uploaded: $_photoProblem',
                          style: const TextStyle(
                            color: SdColors.expired,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _altPhone,
                      decoration: const InputDecoration(
                        labelText: 'Alternate phone',
                        prefixIcon: Icon(Icons.phone_forwarded_rounded),
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: _phoneFormatters,
                      validator: _altPhoneProblem,
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
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          CustomerLimits.address,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notes,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(CustomerLimits.notes),
                      ],
                    ),
                  ],
                ),

                // ── Documents ───────────────────────────────────────────
                FormSection(
                  icon: Icons.badge_outlined,
                  title: 'ID & address proof',
                  trailing: Text(
                    _docs.isEmpty ? 'Optional' : '${_docs.length}',
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
                    LayoutBuilder(
                      builder: (context, box) {
                        // Short labels so they stay on one line on small
                        // phones.
                        final narrow = box.maxWidth < 300;
                        return Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () => _addDocument(file: false),
                                icon: const Icon(
                                  Icons.document_scanner_rounded,
                                  size: 18,
                                ),
                                label: Text(narrow ? 'Camera' : 'Take photo'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () => _addDocument(file: true),
                                icon: const Icon(
                                  Icons.upload_file_rounded,
                                  size: 18,
                                ),
                                label: Text(narrow ? 'File' : 'Upload file'),
                              ),
                            ),
                          ],
                        );
                      },
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

  static final _phoneFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
    LengthLimitingTextInputFormatter(20),
  ];

  Widget _restoredBanner() {
    final files = _restoredFiles;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: SdColors.active.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SdColors.active.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.restore_rounded, color: SdColors.active),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Restored what you typed earlier',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                if (files > 0)
                  Text(
                    files == 1
                        ? 'Add the photo or document again.'
                        : 'Add the $files photos / documents again.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          TextButton(onPressed: _startOver, child: const Text('Start over')),
        ],
      ),
    );
  }

  /// Portrait photo tile, like a passport photo. Tap to take, pick, or
  /// remove the photo.
  Widget _photoPicker() {
    final sd = context.sd;
    final hasPhoto = _newPhoto != null || _existingPhoto.isNotEmpty;
    Widget image;
    if (_newPhoto != null) {
      image = Image.memory(_newPhoto!.bytes, fit: BoxFit.cover);
    } else if (_existingPhoto.isNotEmpty) {
      image = StoredImage(_existingPhoto);
    } else {
      image = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_a_photo_rounded,
            color: SdColors.ember,
            size: 26,
          ),
          const SizedBox(height: 6),
          Text(
            'Add photo',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    return Semantics(
      button: true,
      label: 'Customer photo',
      child: Material(
        color: sd.field,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: _photoProblem != null
                ? SdColors.expired
                : hasPhoto
                ? Colors.transparent
                : sd.line,
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: _saving ? null : _photoOptions,
          child: SizedBox(
            width: 88,
            height: 114,
            child: Stack(
              fit: StackFit.expand,
              children: [
                image,
                if (hasPhoto)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: const Text(
                        'Change',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
    final String state;
    if (d.existing != null) {
      state = '';
    } else if (d.uploadedUrl != null) {
      state = 'uploaded';
    } else {
      state = 'uploads on save';
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
                    if (state.isNotEmpty) state,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                if (d.problem != null)
                  Text(
                    'Not uploaded: ${d.problem}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SdColors.expired,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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
                : () {
                    setState(() {
                      _docs.remove(d);
                      _dirty = true;
                    });
                    _saveDraft();
                  },
          ),
        ],
      ),
    );
  }
}
