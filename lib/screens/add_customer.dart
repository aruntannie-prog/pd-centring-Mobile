import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../widgets/cors_image.dart';
import '../models/customer.dart';
import '../models/store.dart';
import '../services/smart_cropper.dart';
import '../services/image_compressor.dart';

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

  String? _profileUrl;
  String? _addressUrl;
  Uint8List? _localProfileBytes;
  Uint8List? _originalProfileBytes;
  Uint8List? _rawAddressBytes;
  Uint8List? _localAddressBytes;
  String? _addressFileName;
  bool _isSaving = false;
  bool _showLightbox = false;

  late final AnimationController _shimmerCtrl;
  late final AnimationController _staggerCtrl;
  late final Animation<double> _headerAnim;
  late final Animation<double> _uploadsAnim;
  late final Animation<double> _bodyAnim;
  late final Animation<double> _ctaAnim;

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
    _ctaAnim     = _stagger(0.55, 1.00);

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
      _addressUrl = c.addressProofUrl.isNotEmpty ? c.addressProofUrl : null;
      if (_addressUrl != null) _addressFileName = 'proof.jpg';
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
      _localProfileBytes   = crop;
      _originalProfileBytes = orig;
    });
  }

  // ── Pick address proof (any file) ──────────────────────────────────────────
  Future<void> _pickAddressProof() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.any, withData: true);
    if (result == null || result.files.isEmpty || !mounted) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    Uint8List final_ = bytes;
    if (!kIsWeb && _isImageExt(f.name)) {
      final_ = await ImageCompressor.compress(bytes, maxWidth: 1600);
    }
    if (!mounted) return;
    setState(() {
      _rawAddressBytes   = final_;
      _localAddressBytes = final_;
      _addressFileName   = f.name;
    });
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
    String aUrl = _addressUrl ?? '';

    try {
      if (_localProfileBytes != null) {
        pUrl = 'data:image/jpeg;base64,${base64Encode(_localProfileBytes!)}';
      }
      if (_rawAddressBytes != null) {
        final ext = _addressFileName?.split('.').last.toLowerCase() ?? 'pdf';
        final mime = ext == 'pdf'
            ? 'application/pdf'
            : ext == 'png'
                ? 'image/png'
                : 'image/jpeg';
        aUrl = 'data:$mime;base64,${base64Encode(_rawAddressBytes!)}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Encoding failed: $e')));
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
      addressProofUrl: aUrl,
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

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
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

                  // 2. Upload cards (flex-shrink:0)
                  _FadeUp(
                    animation: _uploadsAnim,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                      child: SizedBox(
                        height: 100,
                        child: Row(children: [
                          Expanded(child: _buildProfileCard()),
                          const SizedBox(width: 10),
                          Expanded(child: _buildAddressCard()),
                        ]),
                      ),
                    ),
                  ),

                  // 3. Scrollable form body (flex:1)
                  Expanded(
                    child: _FadeUp(
                      animation: _bodyAnim,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
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

                  // 4. Save button (inline, NOT fixed)
                  _FadeUp(
                    animation: _ctaAnim,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                      child: _buildSaveButton(),
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
            onTap: widget.onBack,
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

  // ── Profile card ───────────────────────────────────────────────────────────
  Widget _buildProfileCard() {
    final hasImg = _localProfileBytes != null ||
        (_profileUrl != null && _profileUrl!.isNotEmpty);
    return GestureDetector(
      onTap: () {
        if (hasImg) {
          setState(() => _showLightbox = true);
        } else {
          _showPhotoSheet();
        }
      },
      child: _cardWrapper(
        filled: hasImg,
        child: hasImg
            ? Stack(fit: StackFit.expand, children: [
                _localProfileBytes != null
                    ? Image.memory(_localProfileBytes!,
                        fit: BoxFit.cover, alignment: Alignment.topCenter)
                    : CORSResilientImage(
                        imageUrl: _profileUrl!,
                        fit: BoxFit.cover,
                        errorWidget: const Center(
                            child: Icon(Icons.broken_image, color: cMuted))),
                // Change overlay
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: GestureDetector(
                    onTap: _showPhotoSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      color: const Color(0x9905080A),
                      alignment: Alignment.center,
                      child: Text('✎ Change',
                          style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ])
            : _emptyCard(Icons.person_outline, 'Profile Photo', 'Tap to add'),
      ),
    );
  }

  // ── Address card ──────────────────────────────────────────────────────────
  Widget _buildAddressCard() {
    final hasProof = _localAddressBytes != null ||
        (_addressUrl != null && _addressUrl!.isNotEmpty);
    final isImg = _addressFileName != null
        ? _isImageExt(_addressFileName!)
        : (_addressUrl?.contains('firebasestorage') == true ||
            _addressUrl?.contains('.jp') == true ||
            _addressUrl?.contains('.png') == true);

    return GestureDetector(
      onTap: _pickAddressProof,
      child: _cardWrapper(
        filled: hasProof,
        child: hasProof
            ? Stack(fit: StackFit.expand, children: [
                if (isImg)
                  (_localAddressBytes != null
                      ? Image.memory(_localAddressBytes!,
                          fit: BoxFit.cover, alignment: Alignment.topCenter)
                      : CORSResilientImage(
                          imageUrl: _addressUrl!,
                          fit: BoxFit.cover,
                          errorWidget: const Center(
                              child: Icon(Icons.broken_image, color: cMuted))))
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.description_outlined,
                          color: cAccent, size: 30),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          _addressFileName ?? 'Document',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                              color: cText,
                              fontSize: 9,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (_addressFileName?.split('.').last.toUpperCase() ??
                              'DOC'),
                          style: GoogleFonts.dmSans(
                              color: cAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    color: const Color(0x9905080A),
                    alignment: Alignment.center,
                    child: Text('✎ Change',
                        style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ])
            : _emptyCard(Icons.badge_outlined, 'Address Proof', 'Doc / Image'),
      ),
    );
  }

  Widget _cardWrapper({required bool filled, required Widget child}) =>
      Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: cSurf,
          borderRadius: BorderRadius.circular(14),
          border: filled
              ? Border.all(
                  color: cAccent.withOpacity(0.3), width: 1.5)
              : Border.all(
                  color: cAccent.withOpacity(0.3),
                  width: 1.5,
                  style: BorderStyle.none), // dashed via CustomPaint if needed
        ),
        child: filled
            ? child
            : _DashedBorder(child: child),
      );

  Widget _emptyCard(IconData icon, String label, String sub) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                color: cAccent.withOpacity(0.10), shape: BoxShape.circle),
            child: Icon(icon, color: cAccent, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.dmSans(
                  color: cText, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sub,
              style: GoogleFonts.dmSans(color: cLabel, fontSize: 9)),
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
              borderRadius: BorderRadius.circular(14),
              gradient: active
                  ? LinearGradient(
                      colors: const [
                        Color(0xFF0AAD96),
                        Color(0xFF0ECFB0),
                        Color(0xFFB8F5ED),
                        Color(0xFF0ECFB0),
                        Color(0xFF0AAD96),
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

  // ── Lightbox ──────────────────────────────────────────────────────────────
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
    final radius = Radius.circular(14);
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
