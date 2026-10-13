import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/file_store.dart';
import '../../models/customer.dart';
import '../../services/document_reader.dart';
import '../../services/image_shrink.dart';
import '../../services/media_picker.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/form_section.dart';
import '../widgets/rental_tile.dart';
import '../widgets/stored_image.dart';

const _uuid = Uuid();

/// Draft key for the new customer form (see [DraftStore]), per account so
/// staff sharing a phone never see each other's half-typed customer.
String newCustomerDraftKey(String? account) =>
    'new_customer:${account ?? 'demo'}';

/// A document in the form: either already saved on the customer, or picked
/// in this form. Picked files start uploading straight away.
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

  /// The user chose the type by hand; reading must not change it.
  bool kindChosen = false;

  /// Set once uploaded, so nothing is ever uploaded twice.
  String? uploadedUrl;

  /// Why the last upload attempt failed.
  String? problem;

  /// The upload in progress, if any.
  Future<void>? uploading;
  double progress = 0;

  /// The name is being read from this document.
  bool reading = false;

  bool get isPdf => contentType == 'application/pdf';
  bool get needsUpload =>
      existing == null && uploadedUrl == null && uploading == null;
}

/// A newly picked profile photo, uploading in the background.
class _PhotoDraft {
  _PhotoDraft(this.media);

  final PickedMedia media;
  String? url;
  String? thumbUrl;
  String? problem;
  Future<void>? uploading;
  double progress = 0;

  bool get needsUpload => url == null && uploading == null;
}

/// What the last document reading found, shown under the documents.
class _ReadResult {
  const _ReadResult({
    required this.kind,
    this.filledName = false,
    this.nameOnDoc,
    this.nothingFound = false,
    this.error,
    this.sample = false,
  });

  final String kind;
  final bool filledName;

  /// A name that differs from the one already typed; offered, not applied.
  final String? nameOnDoc;
  final bool nothingFound;
  final String? error;
  final bool sample;
}

enum _UploadChoice { retry, saveWithout, keepEditing }

String _ext(String contentType) => switch (contentType) {
  'application/pdf' => 'pdf',
  'image/png' => 'png',
  'image/webp' => 'webp',
  _ => 'jpg',
};

/// Same limit as firestore.rules.
const maxDocuments = 30;

String formatBytes(int b) => b >= 1024 * 1024
    ? '${(b / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(b / 1024).ceil()} KB';

/// Add or edit a customer, including profile photo and ID / address proofs.
/// Pops with the saved [Customer].
///
/// Photos and documents upload in the background as soon as they are
/// picked, and documents are read for the customer's name at the same
/// time. Saving waits only for uploads still running; the customer is
/// written once every file is up, or when the user chooses to save without
/// the ones that failed.
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

  /// Same id for every upload, so the customer's files share one folder.
  late final String _id = widget.existing?.id ?? _uuid.v4();

  late final AppState _app = context.read<AppState>();

  _PhotoDraft? _newPhoto;
  bool _removePhoto = false;

  late final List<_DocDraft> _docs = [
    for (final d in widget.existing?.documents ?? const <CustomerDoc>[])
      _DocDraft.existing(d),
  ];

  /// Every file uploaded while this form was open. Whatever the saved
  /// customer does not end up using is deleted again.
  final _sessionUploads = <String>[];

  /// Files being prepared (compressed) after picking.
  int _preparing = 0;
  bool _photoPreparing = false;

  _ReadResult? _read;

  /// The name filled from a document: (value, document type). While the
  /// name is unchanged the field says where it came from.
  (String, String)? _nameFrom;

  bool _saving = false;
  bool _saved = false;
  bool _closed = false;
  bool _dirty = false;

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

  bool get _uploading =>
      _newPhoto?.uploading != null || _docs.any((d) => d.uploading != null);

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
    _closed = true;
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

  void _refresh() {
    if (mounted) setState(() {});
  }

  // ── Draft (new customers only) ───────────────────────────────────────────

  String get _draftKey => newCustomerDraftKey(_app.accountEmail);

  void _restoreDraft() {
    // Opened from a search with a name typed: start from that instead.
    if (widget.initialName.trim().isNotEmpty) return;
    final d = _app.drafts.read(_draftKey);
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
    if (!_isNew || _saved || _closed) return;
    final files = (_newPhoto != null ? 1 : 0) + _docs.length;
    _app.drafts.write(_draftKey, {
      'name': _name.text,
      'phone': _phone.text,
      'altPhone': _altPhone.text,
      'address': _address.text,
      'notes': _notes.text,
      'files': '$files',
    });
  }

  void _clearDraft() {
    if (_isNew) _app.drafts.clear(_draftKey);
  }

  void _startOver() {
    for (final c in _controllers) {
      c.clear();
    }
    _clearDraft();
    setState(() {
      _restored = false;
      _restoredFiles = 0;
      _dirty = _newPhoto != null || _docs.isNotEmpty;
    });
  }

  // ── Uploads (start as soon as a file is picked) ──────────────────────────

  void _forget(String url) {
    _sessionUploads.remove(url);
    unawaited(_app.files.delete(url));
  }

  void _startPhotoUpload(_PhotoDraft p) {
    final files = _app.files;
    p.problem = null;
    p.progress = 0;
    p.uploading = () async {
      try {
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final url = await files.upload(
          path: 'customers/$_id/photo_$stamp.${_ext(p.media.contentType)}',
          bytes: p.media.bytes,
          contentType: p.media.contentType,
          onProgress: (v) {
            p.progress = v;
            _refresh();
          },
        );
        _sessionUploads.add(url);
        // A small copy for lists; if it fails, lists use the full photo.
        String? thumbUrl;
        final thumb = await makeThumbnail(p.media.bytes);
        if (thumb != null) {
          try {
            thumbUrl = await files.upload(
              path: 'customers/$_id/photo_${stamp}_thumb.jpg',
              bytes: thumb,
              contentType: 'image/jpeg',
            );
            _sessionUploads.add(thumbUrl);
          } on FileStoreException {
            thumbUrl = null;
          }
        }
        if (_closed || !identical(_newPhoto, p)) {
          _forget(url);
          if (thumbUrl != null) _forget(thumbUrl);
          return;
        }
        p.url = url;
        p.thumbUrl = thumbUrl;
      } on FileStoreException catch (e) {
        p.problem = e.message;
      } catch (e) {
        p.problem = 'Upload failed. Please try again.';
      } finally {
        p.uploading = null;
        _refresh();
      }
    }();
  }

  void _startDocUpload(_DocDraft d) {
    final files = _app.files;
    d.problem = null;
    d.progress = 0;
    d.uploading = () async {
      try {
        final url = await files.upload(
          path: 'customers/$_id/docs/${d.id}.${_ext(d.contentType)}',
          bytes: d.bytes!,
          contentType: d.contentType,
          onProgress: (v) {
            d.progress = v;
            _refresh();
          },
        );
        _sessionUploads.add(url);
        if (_closed || !_docs.contains(d)) {
          _forget(url);
          return;
        }
        d.uploadedUrl = url;
      } on FileStoreException catch (e) {
        d.problem = e.message;
      } catch (e) {
        d.problem = 'Upload failed. Please try again.';
      } finally {
        d.uploading = null;
        _refresh();
      }
    }();
  }

  /// (Re)starts every upload that is not done or running.
  void _startMissingUploads() {
    final p = _newPhoto;
    if (p != null && p.needsUpload) _startPhotoUpload(p);
    for (final d in _docs) {
      if (d.needsUpload) _startDocUpload(d);
    }
  }

  Future<void> _waitForUploads() async {
    while (true) {
      final running = [
        ?_newPhoto?.uploading,
        for (final d in _docs) ?d.uploading,
      ];
      if (running.isEmpty) return;
      await Future.wait(running);
    }
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
      final old = _newPhoto;
      setState(() {
        _newPhoto = null;
        _removePhoto = true;
        _dirty = true;
      });
      if (old?.url != null) _forget(old!.url!);
      if (old?.thumbUrl != null) _forget(old!.thumbUrl!);
      _saveDraft();
      return;
    }
    try {
      setState(() => _photoPreparing = true);
      final picked = await MediaPicker.instance.photo(
        camera: choice == 'camera',
      );
      if (picked == null || !mounted) return;
      if (picked.bytes.length > maxUploadBytes) {
        _toast('That photo is larger than 10 MB. Choose a smaller one.');
        return;
      }
      final old = _newPhoto;
      final p = _PhotoDraft(picked);
      setState(() {
        _newPhoto = p;
        _removePhoto = true; // replaces the old one once saved
        _dirty = true;
      });
      if (old?.url != null) _forget(old!.url!);
      if (old?.thumbUrl != null) _forget(old!.thumbUrl!);
      _saveDraft();
      _startPhotoUpload(p);
    } catch (e) {
      _toast(
        'Could not open the ${choice == 'camera' ? 'camera' : 'gallery'}.',
      );
    } finally {
      if (mounted) setState(() => _photoPreparing = false);
    }
  }

  // ── Documents ────────────────────────────────────────────────────────────

  Future<void> _addDocument({required bool file}) async {
    if (_docs.length >= maxDocuments) {
      _toast('Up to $maxDocuments documents per customer.');
      return;
    }
    try {
      setState(() => _preparing++);
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
      final d = _DocDraft.picked(picked, kind);
      setState(() {
        _docs.add(d);
        _dirty = true;
      });
      _saveDraft();
      _startDocUpload(d);
      unawaited(_readDocument(d));
    } catch (e) {
      _toast('Could not open ${file ? 'files' : 'the camera'}.');
    } finally {
      if (mounted) setState(() => _preparing--);
    }
  }

  void _removeDocument(_DocDraft d) {
    setState(() {
      _docs.remove(d);
      _dirty = true;
    });
    if (d.uploadedUrl != null) _forget(d.uploadedUrl!);
    _saveDraft();
  }

  // ── Reading the name from a document ─────────────────────────────────────

  Future<void> _readDocument(_DocDraft d) async {
    final reader = _app.reader;
    if (!reader.available || d.bytes == null) return;
    setState(() => d.reading = true);
    try {
      final details = await reader.read(d.bytes!, d.contentType);
      if (!mounted || !_docs.contains(d)) return;
      _applyDetails(d, details);
    } on DocumentReadException catch (e) {
      if (!mounted || !_docs.contains(d)) return;
      setState(() => _read = _ReadResult(kind: d.kind, error: e.message));
    } catch (e) {
      if (!mounted || !_docs.contains(d)) return;
      setState(
        () => _read = _ReadResult(
          kind: d.kind,
          error: 'Could not read this document. Type the details instead.',
        ),
      );
    } finally {
      if (mounted) setState(() => d.reading = false);
    }
  }

  /// Fills the name only when it is still empty. A name already typed is
  /// never changed; if the document shows a different one, it is offered.
  /// The address is never read: a bill may show a site address.
  void _applyDetails(_DocDraft d, DocumentDetails details) {
    if (details.kind.isNotEmpty && !d.kindChosen) d.kind = details.kind;
    final value = details.name;
    final current = _name.text.trim();
    var filled = false;
    String? offered;
    if (value.isNotEmpty) {
      if (current.isEmpty) {
        _name.text = value;
        _nameFrom = (value, d.kind);
        filled = true;
      } else if (!_same(current, value)) {
        offered = value;
      }
    }
    setState(() {
      _read = _ReadResult(
        kind: d.kind,
        filledName: filled,
        nameOnDoc: offered,
        nothingFound: details.isEmpty,
        sample: details.sample,
      );
    });
  }

  static bool _same(String a, String b) {
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return norm(a) == norm(b);
  }

  void _useNameFromDocument(String value) {
    _name.text = value;
    final r = _read!;
    _nameFrom = (value, r.kind);
    setState(() {
      _read = _ReadResult(kind: r.kind, filledName: true, sample: r.sample);
    });
  }

  String? _nameHint() {
    final f = _nameFrom;
    if (f == null || _name.text != f.$1) return null;
    return 'From ${f.$2}. Please check.';
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
        scrollable: true,
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

  Future<_UploadChoice> _askAboutFailedUploads(int failed) async {
    final lines = [
      if (_newPhoto?.problem != null) 'Photo: ${_newPhoto!.problem}',
      for (final d in _docs)
        if (d.problem != null) '${d.kind} (${d.fileName}): ${d.problem}',
    ];
    final choice = await showDialog<_UploadChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        scrollable: true,
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
    final app = _app;
    final phone = normalizePhone(_phone.text);
    final altPhone = normalizePhone(_altPhone.text);

    final matches = app.customersWithPhone([
      phone,
      altPhone,
    ], exceptId: widget.existing?.id);
    if (matches.isNotEmpty && !await _confirmDuplicate(matches)) return;
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      if (!await _finishUploads() || !mounted) return;
      final (customer, unused) = _buildCustomer(phone, altPhone);
      await app.saveCustomer(customer);
      for (final url in unused) {
        unawaited(app.files.delete(url));
      }
      _clearDraft();
      _saved = true;
      if (!mounted) return;
      Navigator.of(context).pop(customer);
    } finally {
      // Whatever went wrong, never leave the form stuck on "Saving…".
      if (mounted && !_saved) setState(() => _saving = false);
    }
  }

  /// Waits for uploads and deals with failures. False: keep editing.
  Future<bool> _finishUploads() async {
    while (true) {
      // Files that failed earlier get one more go automatically: the
      // connection may be back by now.
      _startMissingUploads();
      _refresh();
      await _waitForUploads();
      if (!mounted) return false;
      final failed =
          (_newPhoto?.problem != null ? 1 : 0) +
          _docs.where((d) => d.problem != null).length;
      if (failed == 0) return true;
      final choice = await _askAboutFailedUploads(failed);
      if (!mounted) return false;
      switch (choice) {
        case _UploadChoice.retry:
          continue;
        case _UploadChoice.keepEditing:
          return false;
        case _UploadChoice.saveWithout:
          return true;
      }
    }
  }

  /// The record to write, and the files it no longer uses.
  ///
  /// When editing, changes are applied to the latest saved version of the
  /// customer, not the copy the form opened with: if another phone changed
  /// the photo, a document or a field in the meantime, only what was
  /// changed on this screen overwrites it.
  (Customer, Set<String>) _buildCustomer(String phone, String altPhone) {
    final e = widget.existing;
    final p = _newPhoto;
    final newDocs = [
      for (final d in _docs)
        if (d.existing == null && d.uploadedUrl != null)
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
    final unused = <String>{};

    late final Customer customer;
    if (e == null) {
      final photoOk = p?.url != null;
      customer = Customer(
        id: _id,
        name: tidyText(_name.text),
        phone: phone,
        altPhone: altPhone,
        address: _address.text.trim(),
        notes: _notes.text.trim(),
        photoUrl: photoOk ? p!.url! : '',
        photoThumbUrl: photoOk ? p!.thumbUrl ?? '' : '',
        documents: newDocs,
        createdAt: DateTime.now(),
      );
    } else {
      final live = _app.customerById(e.id) ?? e;
      // A field left as it was keeps the latest saved value.
      String pick(
        TextEditingController c,
        String original,
        String latest,
        String Function(String) clean,
      ) => c.text == original ? latest : clean(c.text);

      var photoUrl = live.photoUrl;
      var thumbUrl = live.photoThumbUrl;
      final photoChanged =
          (p != null && p.url != null) || (p == null && _removePhoto);
      if (photoChanged) {
        unused.addAll([live.photoUrl, live.photoThumbUrl]);
        photoUrl = p?.url ?? '';
        thumbUrl = p?.thumbUrl ?? '';
      }
      // A failed new photo keeps the current one rather than losing both.

      final kept = {
        for (final d in _docs)
          if (d.existing != null) d.id: d.kind,
      };
      final removed = e.documents.where((d) => !kept.containsKey(d.id));
      final removedIds = removed.map((d) => d.id).toSet();
      unused.addAll(removed.map((d) => d.url));
      final docs = [
        for (final d in live.documents)
          if (!removedIds.contains(d.id))
            kept[d.id] == null || kept[d.id] == d.kind
                ? d
                : CustomerDoc(
                    id: d.id,
                    kind: kept[d.id]!,
                    fileName: d.fileName,
                    url: d.url,
                    contentType: d.contentType,
                    sizeBytes: d.sizeBytes,
                    uploadedAt: d.uploadedAt,
                  ),
        ...newDocs,
      ];

      customer = live.copyWith(
        name: pick(_name, e.name, live.name, tidyText),
        phone: pick(_phone, e.phone, live.phone, normalizePhone),
        altPhone: pick(_altPhone, e.altPhone, live.altPhone, normalizePhone),
        address: pick(_address, e.address, live.address, (v) => v.trim()),
        notes: pick(_notes, e.notes, live.notes, (v) => v.trim()),
        photoUrl: photoUrl,
        photoThumbUrl: thumbUrl,
        documents: docs,
      );
    }

    final used = {
      customer.photoUrl,
      customer.photoThumbUrl,
      ...customer.documents.map((d) => d.url),
    };
    unused
      ..addAll(_sessionUploads)
      ..removeAll(used)
      ..remove('');
    return (customer, unused);
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
    // Uploads still running delete their own file when they finish.
    _closed = true;
    for (final url in [..._sessionUploads]) {
      _forget(url);
    }
    _clearDraft();
    _saved = true; // nothing left to protect
    Navigator.of(context).pop();
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  String _saveLabel() {
    if (!_saving) return 'Save customer';
    final progress = [
      if (_newPhoto?.uploading != null) _newPhoto!.progress,
      for (final d in _docs)
        if (d.uploading != null) d.progress,
    ];
    if (progress.isEmpty) return 'Saving…';
    final pct = (progress.reduce((a, b) => a + b) / progress.length * 100)
        .round();
    return progress.length == 1
        ? 'Uploading… $pct%'
        : 'Uploading ${progress.length} files… $pct%';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: _saved || (!_dirty && _sessionUploads.isEmpty && !_uploading),
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
          label: _saveLabel(),
          onPressed: _saving ? null : _save,
        ),
        body: PageWidth(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (_restored) _restoredBanner(),

                // ID first: the name can be filled in from it.
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
                        _app.reader.available
                            ? 'Add the Aadhaar, PAN, voter ID or a bill first '
                                  'and the name is filled in for you. Photo or '
                                  'PDF, up to 10 MB.'
                            : 'Aadhaar, PAN, voter ID or a utility bill. '
                                  'Photo or PDF, up to 10 MB.',
                        style: theme.textTheme.bodySmall,
                      ),
                    if (_preparing > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Preparing file…',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    if (_docs.any((d) => d.reading))
                      _readingLine()
                    else if (_read != null)
                      _readCard(_read!),
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
                              decoration: InputDecoration(
                                labelText: 'Name *',
                                helperText: _nameHint(),
                                helperMaxLines: 2,
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
                    if (_newPhoto?.problem != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Photo not uploaded: ${_newPhoto!.problem} '
                          'It is tried again when you save.',
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

                if (_saving) ...[
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

  Widget _readingLine() => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Reading the name…',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _readCard(_ReadResult r) {
    final theme = Theme.of(context);
    final ok = r.error == null && !r.nothingFound;
    final color = ok ? SdColors.active : SdColors.soon;
    final String title;
    if (r.error != null) {
      title = 'Could not read the name';
    } else if (r.nothingFound) {
      title = 'No name found on this ${r.kind}';
    } else if (r.filledName) {
      title = 'Name filled from ${r.kind}';
    } else if (r.nameOnDoc != null) {
      title = 'The name on the ${r.kind} is different';
    } else {
      title = 'Name matches the ${r.kind}';
    }
    final notes = [
      if (r.error != null) r.error!,
      if (r.filledName) 'Please check it.',
      if (r.nameOnDoc != null) 'Your typed name is kept unless you tap Use.',
      if (r.sample)
        'Demo mode: this is a sample name, not read from your file.',
    ];

    Widget offer(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label on document: ',
                    style: theme.textTheme.bodySmall,
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => _useNameFromDocument(value),
            child: const Text('Use'),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  ok ? Icons.auto_awesome_rounded : Icons.info_outline_rounded,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    for (final n in notes)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(n, style: theme.textTheme.bodySmall),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hide',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                onPressed: () => setState(() => _read = null),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          if (r.nameOnDoc != null) offer('Name', r.nameOnDoc!),
        ],
      ),
    );
  }

  /// Portrait photo tile, like a passport photo. Tap to take, pick, or
  /// remove the photo.
  Widget _photoPicker() {
    final sd = context.sd;
    final p = _newPhoto;
    final hasPhoto = p != null || _existingPhoto.isNotEmpty;
    Widget image;
    if (p != null) {
      image = Image.memory(p.media.bytes, fit: BoxFit.cover);
    } else if (_existingPhoto.isNotEmpty) {
      image = StoredImage(_existingPhoto, decodeSize: 120);
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
            color: p?.problem != null
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
                if (p?.uploading != null || _photoPreparing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        value: (p?.progress ?? 0) > 0 ? p!.progress : null,
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
                  ),
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
      thumb = Image.memory(d.bytes!, fit: BoxFit.cover, cacheWidth: 132);
    } else {
      thumb = StoredImage(d.existing!.url, decodeSize: 44);
    }
    final String state;
    final Color? stateColor;
    if (d.existing != null) {
      state = '';
      stateColor = null;
    } else if (d.uploadedUrl != null) {
      state = 'uploaded';
      stateColor = SdColors.active;
    } else if (d.uploading != null) {
      state = 'uploading ${(d.progress * 100).round()}%';
      stateColor = null;
    } else {
      state = '';
      stateColor = null;
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
                    d.kindChosen = true;
                    _dirty = true;
                  }),
                  itemBuilder: (_) => [
                    for (final k in documentKinds)
                      PopupMenuItem(value: k, child: Text(k)),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          d.kind,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                        color: sd.muted,
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${d.fileName} · ${formatBytes(d.sizeBytes)}',
                      ),
                      if (state.isNotEmpty)
                        TextSpan(
                          text: ' · $state',
                          style: TextStyle(
                            color: stateColor,
                            fontWeight: stateColor == null
                                ? null
                                : FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                if (d.uploading != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: LinearProgressIndicator(
                      value: d.progress > 0 ? d.progress : null,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                if (d.problem != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Not uploaded: ${d.problem}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SdColors.expired,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!_saving)
                        TextButton(
                          onPressed: () => setState(() => _startDocUpload(d)),
                          child: const Text('Retry'),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove document',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: const Icon(Icons.close_rounded),
            onPressed: _saving ? null : () => _removeDocument(d),
          ),
        ],
      ),
    );
  }
}
