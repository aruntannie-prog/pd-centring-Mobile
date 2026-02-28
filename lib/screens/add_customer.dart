import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
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

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _secPhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _siteCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _referCtrl = TextEditingController();

  // Immutable state references
  String? _profileUrl;
  String? _addressUrl;
  Uint8List? _localProfileBytes;
  Uint8List? _originalProfileBytes;
  String? _profileFileName;
  Uint8List? _localAddressBytes;
  String? _addressFileName;

  @override
  void initState() {
    super.initState();
    if (widget.initialCustomer != null) {
      final c = widget.initialCustomer!;
      _nameCtrl.text = c.name;
      _phoneCtrl.text = c.phone;
      _secPhoneCtrl.text = c.secondaryPhone;
      _addressCtrl.text = c.address;
      _siteCtrl.text = c.site;
      _gstCtrl.text = c.gstNumber;
      _referCtrl.text = c.referBy;
      _profileUrl = c.profilePhotoUrl.isNotEmpty ? c.profilePhotoUrl : null;
      _addressUrl = c.addressProofUrl.isNotEmpty ? c.addressProofUrl : null;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _secPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _siteCtrl.dispose();
    _referCtrl.dispose();
    super.dispose();
  }

  // ── Photo Pick ────────────────────────────────────────────────────────────
  Future<void> _pickProfile(ImageSource source) async {
    final picker = ImagePicker();

    // imageQuality: 40 on web = browser C++ compresses in-process before
    // returning bytes. ZERO Dart image processing. Never blocks the UI.
    // imageQuality: 70 on native = OS compresses before we read bytes.
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: kIsWeb ? 40 : 70,
    );
    if (pickedFile == null || !mounted) return;

    final bytes = await pickedFile.readAsBytes();

    Uint8List cropBytes;
    Uint8List originalBytes;

    if (kIsWeb) {
      // Web: bytes are already compressed by browser. Show preview immediately.
      // No Dart pixel ops at all — they all block the JS event loop.
      cropBytes = bytes;
      originalBytes = bytes;
    } else {
      // Native: face-crop in background isolate + native compressor (non-blocking)
      final cropped = await SmartCropper.cropToFace(bytes);
      cropBytes = await ImageCompressor.compress(Uint8List.fromList(cropped));
      originalBytes =
          await ImageCompressor.compress(bytes, maxWidth: 1920, quality: 78);
    }

    if (!mounted) return;
    setState(() {
      _localProfileBytes = cropBytes;
      _originalProfileBytes = originalBytes;
      _profileFileName = pickedFile.name;
    });
  }

  Uint8List?
      _rawAddressBytes; // Holds the actual file bytes for upload (Image OR PDF)

  // ── Document Pick ─────────────────────────────────────────────────────────
  Future<void> _pickAddressProof() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic', 'webp', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final ext = file.name.split('.').last.toLowerCase();
    Uint8List bytes = file.bytes!;
    final isImage = ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext);

    // Show local preview immediately — no network needed
    setState(() {
      _rawAddressBytes = bytes; // Always store raw bytes for upload
      _localAddressBytes =
          isImage ? bytes : null; // Only for image preview rendering
      _addressFileName = file.name;
    });

    // Compress images on native only — web bytes already at reduced quality
    if (!kIsWeb && isImage) {
      _localAddressBytes =
          await ImageCompressor.compress(bytes, maxWidth: 1600);
      _rawAddressBytes =
          _localAddressBytes; // Upload compressed version saving bandwidth
    }
  }

  void _save() {
    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Name and Primary Phone are required'),
          backgroundColor: const Color(0xFFFF5555),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final newCustomer = Customer(
      id: widget.initialCustomer?.id,
      billCount: widget.initialCustomer?.billCount ?? 0,
      isActive: widget.initialCustomer?.isActive ?? true,
      name: _nameCtrl.text,
      phone: _phoneCtrl.text,
      secondaryPhone: _secPhoneCtrl.text,
      address: _addressCtrl.text,
      site: _siteCtrl.text,
      gstNumber: _gstCtrl.text,
      referBy: _referCtrl.text,
      profilePhotoUrl:
          _profileUrl ?? '', // may be empty if upload still pending
      addressProofUrl: _addressUrl ?? '',
    );

    final store = context.read<AppStore>();

    if (widget.initialCustomer != null) {
      store.updateCustomer(newCustomer);
    } else {
      store.addCustomer(newCustomer);
    }

    // Trigger true background upload. Guaranteed to save even if UI unmounts immediately.
    if (_localProfileBytes != null && _profileFileName != null) {
      store.uploadAndSetCustomerPhoto(
          newCustomer.id, _profileFileName!, _localProfileBytes!);
    }
    if (_rawAddressBytes != null && _addressFileName != null) {
      store.uploadAndSetCustomerPhoto(
          newCustomer.id, _addressFileName!, _rawAddressBytes!,
          isAddressProof: true);
    }

    if (widget.onSave != null) {
      widget.onSave!(newCustomer);
    } else {
      widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      bottom: false,
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: widget.onBack,
              behavior: HitTestBehavior.opaque,
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    border: Border.all(color: colors.border, width: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: colors.textMain),
                ),
                const SizedBox(width: 12),
                Text('Customers',
                    style: jakarta(context,
                        size: 14,
                        weight: FontWeight.w700,
                        color: colors.textSub)),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  border: Border.all(color: colors.border, width: 0.5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                    widget.initialCustomer == null
                        ? '⊞   NEW PROFILE'
                        : '⊞   EDIT PROFILE',
                    style: jakarta(context,
                            size: 9,
                            weight: FontWeight.w800,
                            color: colors.textSub)
                        .copyWith(letterSpacing: 2))),
            const SizedBox(height: 12),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: widget.initialCustomer == null ? 'Add ' : 'Edit ',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: colors.textMain)),
              TextSpan(
                  text: 'Customer',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: colors.brand,
                      fontStyle: FontStyle.italic)),
            ])),
          ]),
        ),
        // Body
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
                left: 20, right: 20, top: 20, bottom: 100 + keyboardHeight),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Avatar
              Center(
                  child: Column(children: [
                GestureDetector(
                  onTap: () {
                    if (_originalProfileBytes != null || _profileUrl != null) {
                      showDialog(
                          context: context,
                          builder: (ctx) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: EdgeInsets.zero,
                              child: InteractiveViewer(
                                child: _originalProfileBytes != null
                                    ? Image.memory(_originalProfileBytes!)
                                    : CORSResilientImage(
                                        imageUrl: _profileUrl!,
                                        placeholder: const Center(
                                            child: CircularProgressIndicator()),
                                        errorWidget: Center(
                                            child: Icon(Icons.error_outline,
                                                size: 48,
                                                color: colors.textSub)),
                                      ),
                              )));
                    }
                  },
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                          color: (_localProfileBytes != null ||
                                  _profileUrl != null)
                              ? colors.brand
                              : colors.border,
                          width: 2),
                      color: colors.surfaceVariant,
                      boxShadow: [
                        BoxShadow(
                            color: colors.glow,
                            blurRadius: 16,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: (_localProfileBytes != null || _profileUrl != null)
                        ? (_localProfileBytes != null
                            ? Image.memory(_localProfileBytes!,
                                fit: BoxFit.cover)
                            : CORSResilientImage(
                                imageUrl: _profileUrl!,
                                fit: BoxFit.cover,
                                placeholder: Center(
                                    child: CircularProgressIndicator(
                                        color: colors.brand)),
                                errorWidget: Center(
                                    child: Icon(Icons.person,
                                        size: 36, color: colors.textMuted)),
                              ))
                        : Center(
                            child: Text('👤',
                                style: const TextStyle(fontSize: 36))),
                  ),
                ),
                const SizedBox(height: 16),
                Text('PROFILE PHOTO',
                    style: jakarta(context,
                            size: 10,
                            weight: FontWeight.w800,
                            color: colors.textMuted)
                        .copyWith(letterSpacing: 2)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _showPhotoSheet(context, colors),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: colors.brand.withOpacity(0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: colors.brand.withOpacity(0.1),
                              blurRadius: 10)
                        ]),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_a_photo_rounded,
                          color: colors.brand, size: 20),
                      const SizedBox(width: 10),
                      Text('UPLOAD PHOTO',
                          style: jakarta(context,
                              size: 12,
                              weight: FontWeight.w800,
                              color: colors.brand)),
                    ]),
                  ),
                ),
              ])),
              const SizedBox(height: 32),
              _Lbl('Full Name *', colors: colors),
              _TF('Customer full name...',
                  colors: colors, controller: _nameCtrl),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _Lbl('Primary Phone *', colors: colors),
                      _TF('98765 43210',
                          type: TextInputType.phone,
                          colors: colors,
                          controller: _phoneCtrl)
                    ])),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _Lbl('Secondary Phone', colors: colors),
                      _TF('Optional',
                          type: TextInputType.phone,
                          colors: colors,
                          controller: _secPhoneCtrl)
                    ])),
              ]),
              const SizedBox(height: 16),
              _Lbl('Address', colors: colors),
              _TF('Full address...', colors: colors, controller: _addressCtrl),
              const SizedBox(height: 16),
              _Lbl('Site / Project Location', colors: colors),
              _TF('Site location...', colors: colors, controller: _siteCtrl),
              const SizedBox(height: 16),
              _Lbl('Address Proof', colors: colors),
              GestureDetector(
                onTap: _pickAddressProof,
                child: Container(
                  width: double.infinity,
                  height: 120,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(
                      color: (_addressFileName != null || _addressUrl != null)
                          ? colors.brand
                          : colors.border,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _buildAddressPreview(colors),
                ),
              ),
              const SizedBox(height: 16),
              _Lbl('GST Number', colors: colors),
              _TF('33ABCDE1234F1Z5', colors: colors, controller: _gstCtrl),
              const SizedBox(height: 16),
              _Lbl('Refer By', colors: colors),
              _TF('Who referred this customer?',
                  colors: colors, controller: _referCtrl),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _save,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E3A8A), const Color(0xFF162B66)]
                          : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: (isDark
                                  ? const Color(0xFF1E3A8A)
                                  : const Color(0xFF2563EB))
                              .withOpacity(.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: Center(
                    child: Text('SAVE CUSTOMER PROFILE',
                        style: jakarta(context,
                                size: 14,
                                weight: FontWeight.w800,
                                color: Colors.white)
                            .copyWith(letterSpacing: .5)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ]),
    );
  }

  // Builds the address proof preview widget.
  // Priority: (1) local bytes via Image.memory (no network, no CORS)
  //           (2) doc card for PDFs from previous sessions (_addressUrl set)
  //           (3) empty prompt
  Widget _buildAddressPreview(AppColors colors) {
    final hasLocal = _localAddressBytes != null;
    final hasRemote = _addressUrl != null && _addressUrl!.isNotEmpty;
    final hasAny = hasLocal || hasRemote || _addressFileName != null;
    if (hasLocal) {
      // Image file — show local bytes immediately, no network needed
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(_localAddressBytes!, fit: BoxFit.cover),

          // Open in Drive button (only when URL is available)
          if (hasRemote)
            Positioned(
              right: 8,
              top: 8,
              child: _openInDriveButton(colors),
            ),
        ],
      );
    }

    if (hasAny) {
      // Non-image doc (PDF/Word) or existing record URL — show card
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.brand.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _addressFileName?.toLowerCase().endsWith('.pdf') == true
                  ? '📄'
                  : '📎',
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _addressFileName ?? 'Document Attached',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(context,
                        size: 13,
                        weight: FontWeight.w700,
                        color: colors.textMain),
                  ),
                  const SizedBox(height: 4),
                  Text('Tap to change',
                      style:
                          jakarta(context, size: 11, color: colors.textMuted)),
                ]),
          ),
          if (hasRemote) _openInDriveButton(colors),
        ]),
      );
    }

    // Empty state — prompt to attach
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('📎', style: TextStyle(fontSize: 28)),
      const SizedBox(height: 12),
      Text('Attach Document',
          style: jakarta(context,
              size: 13, weight: FontWeight.w700, color: colors.brand)),
      const SizedBox(height: 4),
      Text('PDF · Images · Word',
          style: jakarta(context, size: 11, color: colors.textMuted)),
    ]);
  }

  Widget _openInDriveButton(AppColors colors) {
    final url = _addressUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return IconButton(
      icon:
          const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
      style: IconButton.styleFrom(
          backgroundColor: Colors.black54, padding: const EdgeInsets.all(6)),
      onPressed: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri))
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    );
  }

  void _showPhotoSheet(BuildContext context, AppColors colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Text('Upload Profile Photo',
              style: jakarta(context,
                  size: 18, weight: FontWeight.w800, color: colors.textMain)),
          const SizedBox(height: 8),
          Text('Take a fresh photo or choose from gallery',
              style: jakarta(context, size: 13, color: colors.textMuted)),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(
                child: _PhotoBtn('📷', 'Take Photo', colors: colors, onTap: () {
              Navigator.pop(ctx);
              _pickProfile(ImageSource.camera);
            })),
            const SizedBox(width: 16),
            Expanded(
                child:
                    _PhotoBtn('🖼', 'From Gallery', colors: colors, onTap: () {
              Navigator.pop(ctx);
              _pickProfile(ImageSource.gallery);
            })),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _PhotoBtn extends StatelessWidget {
  final String icon, label;
  final AppColors colors;
  final VoidCallback onTap;
  const _PhotoBtn(this.icon, this.label,
      {required this.colors, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 110,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border, width: 0.5),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: colors.glow,
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ]),
          child: Column(children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 8),
            Text(label,
                style: jakarta(context,
                    size: 11, weight: FontWeight.w700, color: colors.textMain))
          ]),
        ),
      );
}

class _Lbl extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _Lbl(this.text, {required this.colors});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(),
          style: jakarta(context,
                  size: 9, weight: FontWeight.w800, color: colors.textMuted)
              .copyWith(letterSpacing: 2)));
}

class _TF extends StatelessWidget {
  final String hint;
  final TextInputType type;
  final AppColors colors;
  final TextEditingController controller;
  const _TF(this.hint,
      {this.type = TextInputType.text,
      required this.colors,
      required this.controller});
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: type,
        style: jakarta(context, size: 13, color: colors.textMain),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: jakarta(context, size: 13, color: colors.textMuted),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.border, width: 0.5)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.border, width: 0.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.brand, width: 1.5)),
          filled: true,
          fillColor: colors.surface,
        ),
      );
}
