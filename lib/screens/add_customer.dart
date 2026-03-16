import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../widgets/cors_image.dart';
import '../widgets/common.dart' show showUnsavedChangesDialog;
import '../models/customer.dart';
import '../services/pdf_downloader.dart';
import '../models/store.dart';
import '../services/smart_cropper.dart';
import '../services/image_compressor.dart';
import '../services/ocr_service.dart';
import '../services/firebase_upload_service.dart';

class AddCustomerScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Function(Customer)? onSave;
  final Customer? initialCustomer;
  const AddCustomerScreen(
      {super.key, required this.onBack, this.onSave, this.initialCustomer});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen>
    with TickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _secPhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _siteCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _referCtrl = TextEditingController();

  // Profile photo
  String? _profileUrl;
  Uint8List? _localProfileBytes;     // face-cropped (saved to Firestore)
  Uint8List? _originalProfileBytes;  // full original (shown in preview)
  bool _showLightbox = false;

  // Background upload state — files start uploading immediately when picked
  Future<String>? _profileUploadFuture;
  bool _profileUploading = false;
  final List<Future<String>> _proofUploadFutures = [];
  final List<bool> _proofUploading = [];

  // Address proofs (multi-upload)
  List<String> _existingProofUrls = [];   // loaded from initialCustomer
  List<Uint8List> _newProofBytes = [];    // picked in this session
  List<String> _newProofFileNames = [];   // filenames for new picks

  bool _isSaving = false;
  bool _isOcrRunning = false;

  late final AnimationController _shimmerCtrl;
  late final AnimationController _staggerCtrl;
  late final Animation<double> _headerAnim;
  late final Animation<double> _uploadsAnim;
  late final Animation<double> _bodyAnim;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const cBg     = Color(0xFF0A0F1E);
  static const cSurf   = Color(0xFF162032);
  static const cAccent = Color(0xFF0ECFB0);
  static const cText   = Color(0xFFE2E8F0);
  static const cMuted  = Color(0xFF64748B);
  static const cLabel  = Color(0xFF94A3B8);
  static const cBorder = Color(0x210ECFB0); // rgba(14,207,176,0.13)

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat();
    _staggerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();

    _headerAnim  = _stagger(0.00, 0.35);
    _uploadsAnim = _stagger(0.15, 0.50);
    _bodyAnim    = _stagger(0.30, 0.75);

    if (widget.initialCustomer != null) {
      final c = widget.initialCustomer!;
      _nameCtrl.text     = c.name;
      _phoneCtrl.text    = c.phone;
      _secPhoneCtrl.text = c.secondaryPhone;
      _addressCtrl.text  = c.address;
      _siteCtrl.text     = c.site;
      _gstCtrl.text      = c.gstNumber;
      _referCtrl.text    = c.referBy;
      _profileUrl = c.profilePhotoUrl.isNotEmpty ? c.profilePhotoUrl : null;
      _existingProofUrls = List.from(c.addressProofUrls);
    }
  }

  Animation<double> _stagger(double start, double end) => CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _secPhoneCtrl, _addressCtrl, _siteCtrl, _gstCtrl, _referCtrl]) {
      c.dispose();
    }
    _shimmerCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  // ── Pick profile photo ─────────────────────────────────────────────────────
  Future<void> _pickProfile(ImageSource source) async {
    final file = await ImagePicker().pickImage(
        source: source, imageQuality: kIsWeb ? 40 : 70);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    Uint8List crop = bytes, orig = bytes;
    if (!kIsWeb) {
      final c = await SmartCropper.cropToFace(bytes);
      crop = await ImageCompressor.compress(Uint8List.fromList(c));
      orig = await ImageCompressor.compress(bytes, maxWidth: 1920, quality: 78);
    }
    if (!mounted) return;
    setState(() {
      _localProfileBytes    = crop;
      _originalProfileBytes = orig;
      _profileUploading     = false; // web: no background upload, use base64 at save
      _profileUploadFuture  = null;
    });
    // On web: skip background upload to avoid CORS/auth hangs — base64 fallback at save.
    // On mobile: upload in background with a 30-second timeout.
    if (!kIsWeb) {
      setState(() => _profileUploading = true);
      final path = FirebaseUploadService.profilePath();
      _profileUploadFuture = FirebaseUploadService.uploadBytes(
        orig, path, contentType: 'image/jpeg',
      ).then((url) {
        if (mounted) setState(() => _profileUploading = false);
        return url;
      }).catchError((e) {
        debugPrint('Profile upload error: $e');
        if (mounted) setState(() => _profileUploading = false);
        return ''; // empty → will fall back to base64 at save time
      });
    }
  }

  // ── Pick address proof from camera / gallery ──────────────────────────────
  Future<void> _pickAddressProofFromImage(ImageSource source) async {
    final file = await ImagePicker().pickImage(
        source: source, imageQuality: kIsWeb ? 40 : 70);
    if (file == null || !mounted) return;

    final isFirstEver = _existingProofUrls.isEmpty && _newProofBytes.isEmpty;

    final bytes = await file.readAsBytes();
    Uint8List processed = bytes;
    if (!kIsWeb) {
      processed = await ImageCompressor.compress(bytes, maxWidth: 1600);
    }
    final name = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (!mounted) return;
    setState(() {
      _newProofBytes.add(processed);
      _newProofFileNames.add(name);
    });
    _startProofUpload(processed, name);

    if (isFirstEver) {
      _runOcrOnFirstProof(processed, name);
    }
  }

  // ── Bottom sheet to pick proof source ─────────────────────────────────────
  void _showAddProofSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cSurf,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: cBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Text('Add Address Proof',
              style: GoogleFonts.sora(
                  fontSize: 17, fontWeight: FontWeight.w800, color: cText)),
          const SizedBox(height: 8),
          Text('Take a photo, choose from gallery, or upload a file',
              style: GoogleFonts.dmSans(fontSize: 13, color: cMuted),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(child: _sheetBtn(Icons.camera_alt_rounded, 'Camera', () {
              Navigator.pop(ctx);
              _pickAddressProofFromImage(ImageSource.camera);
            })),
            const SizedBox(width: 10),
            Expanded(child: _sheetBtn(Icons.photo_library_rounded, 'Gallery', () {
              Navigator.pop(ctx);
              _pickAddressProofFromImage(ImageSource.gallery);
            })),
            const SizedBox(width: 10),
            Expanded(child: _sheetBtn(Icons.upload_file_rounded, 'File', () {
              Navigator.pop(ctx);
              _pickAddressProofs();
            })),
          ]),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  // ── Pick address proofs (any file, multiple allowed) ───────────────────────
  Future<void> _pickAddressProofs() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.any, withData: true, allowMultiple: true);
    if (result == null || result.files.isEmpty || !mounted) return;

    // Capture whether this will be the very first proof before we add anything
    final isFirstEver = _existingProofUrls.isEmpty && _newProofBytes.isEmpty;

    final newBytes = <Uint8List>[];
    final newNames = <String>[];
    for (final f in result.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      Uint8List processed = bytes;
      if (!kIsWeb && _isImageExt(f.name)) {
        processed = await ImageCompressor.compress(bytes, maxWidth: 1600);
      }
      newBytes.add(processed);
      newNames.add(f.name);
    }

    if (!mounted) return;
    setState(() {
      _newProofBytes.addAll(newBytes);
      _newProofFileNames.addAll(newNames);
    });
    // Start background uploads for each newly picked file
    for (int i = 0; i < newBytes.length; i++) {
      _startProofUpload(newBytes[i], newNames[i]);
    }

    // Run OCR on the first-ever uploaded image proof
    if (isFirstEver && newBytes.isNotEmpty && _isImageExt(newNames.first)) {
      _runOcrOnFirstProof(newBytes.first, newNames.first);
    }
  }

  // ── Background proof upload helper ────────────────────────────────────────
  // On web: skip background upload to avoid CORS/auth hangs — save as base64.
  // On mobile: upload in background with timeout via FirebaseUploadService.
  void _startProofUpload(Uint8List bytes, String fileName) {
    if (kIsWeb) {
      // Web: store a resolved future with empty URL; base64 used at save time
      _proofUploading.add(false);
      _proofUploadFutures.add(Future.value(''));
      return;
    }
    final mime = FirebaseUploadService.mimeForFile(fileName);
    final path = FirebaseUploadService.proofPath(fileName);
    final idx  = _proofUploading.length;
    _proofUploading.add(true);
    _proofUploadFutures.add(
      FirebaseUploadService.uploadBytes(bytes, path, contentType: mime).then((url) {
        if (mounted) setState(() {
          if (idx < _proofUploading.length) _proofUploading[idx] = false;
        });
        return url;
      }).catchError((Object e) {
        debugPrint('Proof upload error: $e');
        if (mounted) setState(() {
          if (idx < _proofUploading.length) _proofUploading[idx] = false;
        });
        return ''; // empty → fall back to base64 at save time
      }),
    );
  }

  // ── OCR on first proof ─────────────────────────────────────────────────────
  Future<void> _runOcrOnFirstProof(Uint8List bytes, String filename) async {
    setState(() => _isOcrRunning = true);
    final ext = filename.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    final result = await OcrService.extractFromImage(bytes, mime);
    if (!mounted) return;
    setState(() => _isOcrRunning = false);
    if (result != null && result.hasData) {
      _showOcrResultSheet(result);
    }
  }

  // ── OCR result bottom sheet ────────────────────────────────────────────────
  void _showOcrResultSheet(OcrResult result) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cSurf,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: cBorder, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: cAccent.withOpacity(0.12),
                    shape: BoxShape.circle),
                child: const Icon(Icons.document_scanner_outlined,
                    color: cAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Document Scanned',
                    style: GoogleFonts.sora(
                        color: cText, fontSize: 16, fontWeight: FontWeight.w700)),
                Text('Tap to apply extracted details',
                    style: GoogleFonts.dmSans(color: cMuted, fontSize: 12)),
              ]),
            ]),
            const SizedBox(height: 20),
            // Extracted fields
            if (result.hasName) ...[
              _ocrFieldTile(
                ctx,
                icon: Icons.person_outline_rounded,
                label: 'Name',
                value: result.name,
                onApply: () {
                  _nameCtrl.text = result.name;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Name applied from document'),
                    backgroundColor: cAccent.withOpacity(0.85),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                },
              ),
              const SizedBox(height: 10),
            ],
            if (result.hasAddress) ...[
              _ocrFieldTile(
                ctx,
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: result.address,
                onApply: () {
                  _addressCtrl.text = result.address;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Address applied from document'),
                    backgroundColor: cAccent.withOpacity(0.85),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                },
              ),
              const SizedBox(height: 10),
            ],
            // Fill Both button
            if (result.hasName && result.hasAddress) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  _nameCtrl.text = result.name;
                  _addressCtrl.text = result.address;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:
                        const Text('Name & Address applied from document'),
                    backgroundColor: cAccent.withOpacity(0.85),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF0AAD96), Color(0xFF0ECFB0)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text('Apply Both Fields',
                      style: GoogleFonts.sora(
                          color: const Color(0xFF060E14),
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Dismiss
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Text('Skip',
                    style: GoogleFonts.dmSans(color: cMuted, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ocrFieldTile(BuildContext ctx,
      {required IconData icon,
      required String label,
      required String value,
      required VoidCallback onApply}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cBorder),
      ),
      child: Row(children: [
        Icon(icon, color: cAccent, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.dmSans(
                      color: cLabel, fontSize: 10, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(value,
                  style: GoogleFonts.dmSans(
                      color: cText, fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onApply,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cAccent.withOpacity(0.3)),
            ),
            child: Text('Apply',
                style: GoogleFonts.dmSans(
                    color: cAccent, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  bool _isImageExt(String name) =>
      ['jpg', 'jpeg', 'png', 'gif', 'webp']
          .contains(name.split('.').last.toLowerCase());

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Name and Primary Phone are required'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    setState(() => _isSaving = true);

    String pUrl = _profileUrl ?? '';
    final allProofUrls = <String>[..._existingProofUrls];

    try {
      // Await background profile upload (should already be done by the time
      // the user fills the form and taps Save — usually instant wait here).
      if (_profileUploadFuture != null) {
        pUrl = await _profileUploadFuture!;
      }
      // Fallback: base64 if upload failed or was never started
      if (pUrl.isEmpty && (_localProfileBytes != null || _originalProfileBytes != null)) {
        final toSave = _originalProfileBytes ?? _localProfileBytes!;
        pUrl = 'data:image/jpeg;base64,${base64Encode(toSave)}';
      }

      // Await background proof uploads, fallback to base64 per proof if needed
      for (int i = 0; i < _newProofBytes.length; i++) {
        String proofUrl = '';
        if (i < _proofUploadFutures.length) {
          proofUrl = await _proofUploadFutures[i];
        }
        if (proofUrl.isEmpty) {
          final mime = FirebaseUploadService.mimeForFile(_newProofFileNames[i]);
          proofUrl = 'data:$mime;base64,${base64Encode(_newProofBytes[i])}';
        }
        allProofUrls.add(proofUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')));
        setState(() => _isSaving = false);
      }
      return;
    }

    final customer = Customer(
      id: widget.initialCustomer?.id,
      billCount: widget.initialCustomer?.billCount ?? 0,
      isActive: widget.initialCustomer?.isActive ?? true,
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      secondaryPhone: _secPhoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      site: _siteCtrl.text.trim(),
      gstNumber: _gstCtrl.text.trim(),
      referBy: _referCtrl.text.trim(),
      profilePhotoUrl: pUrl,
      addressProofUrls: allProofUrls,
    );

    final store = context.read<AppStore>();
    try {
      widget.initialCustomer != null
          ? await store.updateCustomer(customer)
          : await store.addCustomer(customer);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
        setState(() => _isSaving = false);
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    widget.onSave != null ? widget.onSave!(customer) : widget.onBack();
  }

  bool get _isDirty =>
      _nameCtrl.text.isNotEmpty ||
      _phoneCtrl.text.isNotEmpty ||
      _siteCtrl.text.isNotEmpty ||
      _addressCtrl.text.isNotEmpty;

  Future<void> _handleBack() async {
    if (!_isDirty) {
      widget.onBack();
      return;
    }
    final leave = await showUnsavedChangesDialog(context);
    if (leave && mounted) widget.onBack();
  }


  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          child: _buildSaveButton(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Glow blobs ────────────────────────────────────────────────
              Positioned(
                top: -80, left: -60,
                child: _blob(220, cAccent.withOpacity(0.14)),
              ),
              Positioned(
                bottom: -120, right: -80,
                child: _blob(300, cAccent.withOpacity(0.08)),
              ),

              // ── Main column ───────────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header
                  _FadeUp(animation: _headerAnim, child: _buildHeader()),

                  // 2. Upload section (profile + address proofs)
                  _FadeUp(
                    animation: _uploadsAnim,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Profile card: circular avatar
                          Center(child: _buildProfileCard()),
                          const SizedBox(height: 16),
                          // Address proofs section (header + scrollable row)
                          _buildAddressProofsRow(),
                        ],
                      ),
                    ),
                  ),

                  // 3. Scrollable form body (flex:1)
                  Expanded(
                    child: _FadeUp(
                      animation: _bodyAnim,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _divider('PERSONAL'),
                            _input(_nameCtrl, 'Full Name', 'Customer full name', req: true),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: _input(_phoneCtrl, 'Primary Phone', '98765 43210', req: true, phone: true)),
                              const SizedBox(width: 10),
                              Expanded(child: _input(_secPhoneCtrl, 'Secondary Phone', 'Optional', phone: true)),
                            ]),
                            const SizedBox(height: 18),

                            _divider('LOCATION'),
                            _textarea(_addressCtrl, 'Address', 'Full address'),
                            const SizedBox(height: 10),
                            _input(_siteCtrl, 'Site / Project', 'Site location'),
                            const SizedBox(height: 18),

                            _divider('BUSINESS'),
                            Row(children: [
                              Expanded(child: _input(_gstCtrl, 'GST Number', '33ABCDE1234F1Z5', gst: true)),
                              const SizedBox(width: 10),
                              Expanded(child: _input(_referCtrl, 'Referred By', 'Who referred?')),
                            ]),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
                  ),

                ],
              ),

              // ── Lightbox ─────────────────────────────────────────────────
              if (_showLightbox) _buildLightbox(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Glow blob ──────────────────────────────────────────────────────────────
  Widget _blob(double size, Color color) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      );

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(children: [
          GestureDetector(
            onTap: _handleBack,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: cAccent.withOpacity(0.5)),
                color: cSurf.withOpacity(0.6),
              ),
              child: const Icon(Icons.arrow_back, color: cText, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Text.rich(TextSpan(children: [
            TextSpan(
              text: widget.initialCustomer == null ? 'Add ' : 'Edit ',
              style: GoogleFonts.sora(
                  color: cText, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: 'Customer',
              style: GoogleFonts.sora(
                  color: cAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic),
            ),
          ])),
        ]),
      );

  // ── Profile card (circular avatar, 110px) ─────────────────────────────────
  Widget _buildProfileCard() {
    const size = 110.0;
    final hasImg = _localProfileBytes != null ||
        (_profileUrl != null && _profileUrl!.isNotEmpty);
    final previewBytes = _localProfileBytes ?? _originalProfileBytes;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Dashed circle border
          Positioned.fill(
            child: CustomPaint(painter: _DashedCirclePainter()),
          ),
          // Avatar circle (inset 4px from dashed border)
          Positioned(
            top: 4, left: 4, right: 4, bottom: 4,
            child: GestureDetector(
              onTap: () {
                if (hasImg) {
                  setState(() => _showLightbox = true);
                } else {
                  _showPhotoSheet();
                }
              },
              child: ClipOval(
                child: Container(
                  color: cSurf,
                  child: hasImg
                      ? (previewBytes != null
                          ? Image.memory(previewBytes, fit: BoxFit.cover)
                          : CORSResilientImage(
                              imageUrl: _profileUrl!,
                              fit: BoxFit.cover,
                              errorWidget: const Center(
                                  child: Icon(Icons.broken_image, color: cMuted))))
                      : const Icon(Icons.person, color: cMuted, size: 44),
                ),
              ),
            ),
          ),
          // Edit badge at bottom-right
          Positioned(
            bottom: 0, right: 0,
            child: GestureDetector(
              onTap: _showPhotoSheet,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cAccent,
                  border: Border.all(color: cBg, width: 2),
                ),
                child: const Icon(Icons.edit, color: Color(0xFF060E14), size: 13),
              ),
            ),
          ),
          // Upload spinner overlay
          if (_profileUploading)
            Positioned(
              top: 4, left: 4, right: 4, bottom: 4,
              child: ClipOval(
                child: Container(
                  color: cBg.withOpacity(0.6),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cAccent),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Address proofs grid ────────────────────────────────────────────────────
  Widget _buildAddressProofsRow() {
    final totalProofs = _existingProofUrls.length + _newProofBytes.length;
    final hasAny = totalProofs > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header row
        Row(children: [
          Text('ADDRESS PROOFS',
              style: GoogleFonts.dmSans(
                  color: cLabel,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: cBorder)),
        ]),
        const SizedBox(height: 10),
        // Wrap grid of 80×80 tiles
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Existing URL proofs
            ..._existingProofUrls.asMap().entries.map((e) {
              final globalIdx = e.key;
              final url = e.value;
              final isPdf = _isPdfUrl(url);
              final isPrimary = globalIdx == 0;
              return _proofThumb(
                isPrimary: isPrimary,
                label: isPrimary ? null : 'DOC ${globalIdx + 1}',
                showOcrSpinner: false,
                child: isPdf
                    ? _pdfThumbContent()
                    : CORSResilientImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        errorWidget: const Center(
                            child: Icon(Icons.description_outlined,
                                color: cAccent, size: 24)),
                      ),
                onRemove: () =>
                    setState(() => _existingProofUrls.removeAt(e.key)),
                onTap: () => _showProofViewer(url: url),
              );
            }),
            // New (locally picked) proofs
            ..._newProofBytes.asMap().entries.map((e) {
              final globalIdx = _existingProofUrls.length + e.key;
              final bytes = e.value;
              final name = _newProofFileNames[e.key];
              final isImg = _isImageExt(name);
              final isPrimary = globalIdx == 0;
              final showSpinner = isPrimary && _isOcrRunning;
              final uploading = e.key < _proofUploading.length
                  ? _proofUploading[e.key]
                  : false;
              return _proofThumb(
                isPrimary: isPrimary,
                label: isPrimary ? null : 'DOC ${globalIdx + 1}',
                showOcrSpinner: showSpinner,
                isUploading: uploading && !showSpinner,
                child: isImg
                    ? Image.memory(bytes, fit: BoxFit.cover)
                    : _pdfThumbContent(),
                onRemove: () => setState(() {
                  _newProofBytes.removeAt(e.key);
                  _newProofFileNames.removeAt(e.key);
                  if (e.key < _proofUploadFutures.length) {
                    _proofUploadFutures.removeAt(e.key);
                  }
                  if (e.key < _proofUploading.length) {
                    _proofUploading.removeAt(e.key);
                  }
                }),
                onTap: () => _showProofViewer(bytes: bytes, fileName: name),
              );
            }),
            // "+ Upload Proof" tile (always at end)
            GestureDetector(
              onTap: _showAddProofSheet,
              child: Container(
                width: 80,
                height: 80,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                    color: cSurf,
                    borderRadius: BorderRadius.circular(14)),
                child: _DashedBorder(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                            color: cAccent.withOpacity(0.10),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: cAccent, size: 18),
                      ),
                      const SizedBox(height: 5),
                      Text(
                          hasAny ? 'Add More' : 'Upload\nProof',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                              color: cText,
                              fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // Count below grid
        if (hasAny) ...[
          const SizedBox(height: 8),
          Text('$totalProofs doc${totalProofs > 1 ? 's' : ''}',
              style: GoogleFonts.dmSans(
                  color: cAccent, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
        // OCR hint text shown while scanning
        if (_isOcrRunning)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: cAccent)),
              const SizedBox(width: 8),
              Text('Scanning document for name & address...',
                  style: GoogleFonts.dmSans(
                      color: cAccent, fontSize: 11, fontWeight: FontWeight.w500)),
            ]),
          ),
      ],
    );
  }

  /// Small thumbnail card for an address proof item.
  Widget _proofThumb({
    required Widget child,
    required VoidCallback onRemove,
    VoidCallback? onTap,
    bool isPrimary = false,
    String? label,
    bool showOcrSpinner = false,
    bool isUploading = false,
  }) {
    final showingSpinner = showOcrSpinner || isUploading;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: cSurf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary ? cAccent : cAccent.withOpacity(0.3),
            width: isPrimary ? 2 : 1.5,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            // Upload / OCR spinner overlay
            if (showingSpinner)
              Container(
                color: cBg.withOpacity(0.6),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cAccent),
                    ),
                    if (isUploading && !showOcrSpinner) ...[
                      const SizedBox(height: 4),
                      Text('Uploading',
                          style: GoogleFonts.dmSans(
                              color: cAccent,
                              fontSize: 7,
                              fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
            // PRIMARY badge at top
            if (isPrimary && !showingSpinner)
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cAccent.withOpacity(0.9), cAccent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text('PRIMARY',
                      style: GoogleFonts.dmSans(
                          color: const Color(0xFF060E14),
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8)),
                ),
              ),
            // DOC N label for non-primary
            if (label != null && !isPrimary)
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  color: Colors.black.withOpacity(0.45),
                  alignment: Alignment.center,
                  child: Text(label,
                      style: GoogleFonts.dmSans(
                          color: cLabel,
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6)),
                ),
              ),
            // Remove button
            Positioned(
              bottom: 4, right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isPdfUrl(String url) =>
      url.startsWith('data:application/pdf') ||
      url.toLowerCase().endsWith('.pdf');

  /// Show a proof image viewer, or download if PDF.
  void _showProofViewer({String? url, Uint8List? bytes, String? fileName}) {
    // PDF: download instead of attempting to render
    final isPdf = (url != null && _isPdfUrl(url)) ||
        (fileName != null && fileName.toLowerCase().endsWith('.pdf'));
    if (isPdf) {
      Uint8List? pdfBytes = bytes;
      if (pdfBytes == null && url != null) {
        final comma = url.indexOf(',');
        if (comma != -1) pdfBytes = base64Decode(url.substring(comma + 1));
      }
      if (pdfBytes != null && kIsWeb) {
        downloadPdfWeb(pdfBytes, fileName ?? 'address_proof.pdf');
      }
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(
            child: url != null
                ? CORSResilientImage(
                    imageUrl: url,
                    placeholder: const Center(child: CircularProgressIndicator()),
                    errorWidget: const Center(
                        child: Icon(Icons.broken_image, color: cMuted, size: 48)),
                  )
                : Image.memory(bytes!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _pdfThumbContent() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf_rounded,
              color: Color(0xFFE53935), size: 28),
          const SizedBox(height: 4),
          Text('PDF',
              style: GoogleFonts.dmSans(
                  color: cAccent, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      );

  // ── Section divider ───────────────────────────────────────────────────────
  Widget _divider(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Text(text,
              style: GoogleFonts.dmSans(
                  color: cLabel,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
              child: Container(height: 1, color: cBorder)),
        ]),
      );

  // ── Input field ───────────────────────────────────────────────────────────
  Widget _input(
    TextEditingController ctrl,
    String label,
    String hint, {
    bool req = false,
    bool phone = false,
    bool gst = false,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text(label,
                style: GoogleFonts.dmSans(
                    color: cLabel,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            if (req)
              Text(' *',
                  style: GoogleFonts.dmSans(
                      color: cAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 5),
          SizedBox(
            height: 42,
            child: TextFormField(
              controller: ctrl,
              keyboardType:
                  phone ? TextInputType.phone : TextInputType.text,
              style: gst
                  ? GoogleFonts.ptMono(
                      color: cAccent, fontSize: 12, letterSpacing: 1.2)
                  : GoogleFonts.dmSans(color: cText, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    GoogleFonts.dmSans(color: cMuted, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 13, vertical: 9),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: const BorderSide(color: cBorder)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: cAccent),
                ),
                fillColor: cSurf,
                filled: true,
              ),
            ),
          ),
        ],
      );

  // ── Textarea ──────────────────────────────────────────────────────────────
  Widget _textarea(
      TextEditingController ctrl, String label, String hint) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: GoogleFonts.dmSans(
                  color: cLabel, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          TextFormField(
            controller: ctrl,
            maxLines: 2,
            style: GoogleFonts.dmSans(color: cText, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.dmSans(color: cMuted, fontSize: 13),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: cBorder)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: cAccent),
              ),
              fillColor: cSurf,
              filled: true,
            ),
          ),
        ],
      );

  // ── Save button with shimmer ───────────────────────────────────────────────
  Widget _buildSaveButton() {
    final active = !_isSaving;
    return GestureDetector(
      onTap: active ? _save : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _shimmerCtrl,
        builder: (_, __) {
          final t = _shimmerCtrl.value;
          return Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: active
                  ? LinearGradient(
                      colors: const [
                        Color(0xFF00BFA5),
                        Color(0xFF1DE9B6),
                        Color(0xFFB8F5ED),
                        Color(0xFF1DE9B6),
                        Color(0xFF00BFA5),
                      ],
                      stops: [
                        0.0,
                        (t - 0.25).clamp(0.0, 1.0),
                        t.clamp(0.0, 1.0),
                        (t + 0.25).clamp(0.0, 1.0),
                        1.0,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : const LinearGradient(colors: [cSurf, cSurf]),
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: cAccent.withOpacity(0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 4))
                    ]
                  : [],
              border: active ? null : Border.all(color: cBorder),
            ),
            alignment: Alignment.center,
            child: _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Color(0xFF060E14), strokeWidth: 2))
                : Text(
                    widget.initialCustomer == null
                        ? 'Save Customer'
                        : 'Update Customer',
                    style: GoogleFonts.sora(
                        color: active
                            ? const Color(0xFF060E14)
                            : cMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
          );
        },
      ),
    );
  }

  // ── Profile photo sheet ────────────────────────────────────────────────────
  void _showPhotoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cSurf,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: cBorder,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Text('Upload Profile Photo',
              style: GoogleFonts.sora(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: cText)),
          const SizedBox(height: 8),
          Text('Take a photo or pick from gallery',
              style: GoogleFonts.dmSans(fontSize: 13, color: cMuted)),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
                child: _sheetBtn(Icons.camera_alt, 'Take Photo', () {
              Navigator.pop(ctx);
              _pickProfile(ImageSource.camera);
            })),
            const SizedBox(width: 14),
            Expanded(
                child: _sheetBtn(Icons.photo_library, 'From Gallery', () {
              Navigator.pop(ctx);
              _pickProfile(ImageSource.gallery);
            })),
          ]),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _sheetBtn(IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
              color: cBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cBorder)),
          child: Column(children: [
            Icon(icon, color: cAccent, size: 26),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.dmSans(
                    color: cText,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
      );

  // ── Lightbox (profile photo full view) ────────────────────────────────────
  Widget _buildLightbox() => GestureDetector(
        onTap: () => setState(() => _showLightbox = false),
        child: Container(
          color: const Color(0xEB000000),
          child: Stack(children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.95,
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                child: _originalProfileBytes != null
                    ? Image.memory(_originalProfileBytes!, fit: BoxFit.contain)
                    : (_profileUrl != null
                        ? CORSResilientImage(
                            imageUrl: _profileUrl!,
                            fit: BoxFit.contain,
                            errorWidget: const Icon(Icons.broken_image,
                                color: cMuted, size: 48))
                        : const SizedBox.shrink()),
              ),
            ),
            Positioned(
              top: 24,
              right: 16,
              child: GestureDetector(
                onTap: () => setState(() => _showLightbox = false),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(color: cAccent.withOpacity(0.3))),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
          ]),
        ),
      );
}

// ── Fade-up animation helper ────────────────────────────────────────────────
class _FadeUp extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _FadeUp({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        builder: (_, __) => Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - animation.value)),
            child: child,
          ),
        ),
      );
}

// ── Dashed border painter ────────────────────────────────────────────────────
class _DashedBorder extends StatelessWidget {
  final Widget child;
  const _DashedBorder({required this.child});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashedPainter(),
        child: child,
      );
}

class _DashedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0ECFB0).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dashLen = 6.0;
    const gapLen = 5.0;
    const radius = Radius.circular(14);
    final rRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5), radius);
    final path = Path()..addRRect(rRect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double dist = 0;
      while (dist < metric.length) {
        canvas.drawPath(metric.extractPath(dist, dist + dashLen), paint);
        dist += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1DE9B6).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dashLen = 5.0;
    const gapLen = 4.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 0.75;
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double dist = 0;
      while (dist < metric.length) {
        canvas.drawPath(metric.extractPath(dist, dist + dashLen), paint);
        dist += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
