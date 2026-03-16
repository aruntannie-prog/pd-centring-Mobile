import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/store.dart';
import '../services/pdf_downloader.dart';
import '../theme/app_theme.dart';
import '../widgets/cors_image.dart';

class CustomerDetailScreen extends StatelessWidget {
  final Customer customer;
  final VoidCallback onBack;
  final Function(Customer) onEdit;
  final VoidCallback onLedger;
  const CustomerDetailScreen(
      {super.key,
      required this.customer,
      required this.onBack,
      required this.onEdit,
      required this.onLedger});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final liveCustomer = store.customers
        .firstWhere((c) => c.id == customer.id, orElse: () => customer);
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: onBack,
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
                Text('Back to Customers',
                    style: jakarta(context,
                        size: 14,
                        weight: FontWeight.w700,
                        color: colors.textSub)),
                const Spacer(),
                GestureDetector(
                  onTap: () => onEdit(liveCustomer),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      border: Border.all(color: colors.border, width: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.edit_outlined,
                        size: 18, color: colors.brand),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _confirmDelete(context, colors),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFFFF4D5E).withOpacity(.15)
                          : const Color(0xFFFFF0F1),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFFFF4D5E).withOpacity(.3)
                              : const Color(0xFFFFD1D6),
                          width: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: Color(0xFFFF5555)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    border: Border.all(color: colors.border, width: 0.5),
                    borderRadius: BorderRadius.circular(24)),
                child: Text('◉   PROFILE',
                    style: jakarta(context,
                            size: 9,
                            weight: FontWeight.w800,
                            color: colors.textSub)
                        .copyWith(letterSpacing: 2))),
            const SizedBox(height: 12),
            Text(liveCustomer.name,
                style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: colors.textMain)),
          ]),
        ),
        // Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
                left: 20, right: 20, top: 20, bottom: 100),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (liveCustomer.profilePhotoUrl.isNotEmpty)
                Center(
                    child: GestureDetector(
                        onTap: () {
                          final String fUrl = liveCustomer.profilePhotoUrl;
                          if (fUrl.isNotEmpty) {
                            showDialog(
                                context: context,
                                builder: (ctx) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      insetPadding: EdgeInsets.zero,
                                      child: InteractiveViewer(
                                        child: CORSResilientImage(
                                          imageUrl: fUrl,
                                          placeholder: const Center(
                                              child:
                                                  CircularProgressIndicator()),
                                          errorWidget: Center(
                                              child: Icon(Icons.error_outline,
                                                  size: 48,
                                                  color: colors.textSub)),
                                        ),
                                      ),
                                    ));
                          }
                        },
                        child: Container(
                          width: 120,
                          height: 120,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: colors.brand, width: 3),
                            boxShadow: [
                              BoxShadow(
                                  color: colors.brand.withOpacity(0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8))
                            ],
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: CORSResilientImage(
                            imageUrl: liveCustomer.profilePhotoUrl,
                            fit: BoxFit.cover,
                            placeholder: Center(
                                child: CircularProgressIndicator(
                                    color: colors.brand)),
                            errorWidget: Center(
                                child: Icon(Icons.person,
                                    size: 48, color: colors.textMuted)),
                          ),
                        ))),
              // Material Ledger action card
              GestureDetector(
                onTap: onLedger,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF14224A), Color(0xFF1E3A6E)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF14224A).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.inventory_2_outlined,
                          size: 26, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Material Ledger',
                              style: jakarta(context,
                                  size: 15,
                                  weight: FontWeight.w800,
                                  color: Colors.white)),
                          const SizedBox(height: 3),
                          Text('Track given, returned & pending items',
                              style: jakarta(context,
                                  size: 11,
                                  color: Colors.white.withOpacity(0.6))),
                        ])),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: Colors.white.withOpacity(0.6)),
                  ]),
                ),
              ),

              // Contact Box
              _buildSectionTile('Contact Info', Icons.phone_android_rounded,
                  colors, context, [
                _buildRow('Primary Phone', liveCustomer.phone, colors, context),
                if (liveCustomer.secondaryPhone.isNotEmpty)
                  _buildRow('Secondary Phone', liveCustomer.secondaryPhone,
                      colors, context),
              ]),
              const SizedBox(height: 16),
              _buildSectionTile(
                  'Location', Icons.location_on_rounded, colors, context, [
                _buildRow(
                    'Address',
                    liveCustomer.address.isEmpty ? 'N/A' : liveCustomer.address,
                    colors,
                    context),
              ]),
              const SizedBox(height: 16),
              _buildSectionTile(
                  'Business Details', Icons.business_rounded, colors, context, [
                _buildRow(
                    'GST Number',
                    liveCustomer.gstNumber.isEmpty
                        ? 'N/A'
                        : liveCustomer.gstNumber,
                    colors,
                    context),
                _buildRow(
                    'Referred By',
                    liveCustomer.referBy.isEmpty
                        ? 'Direct'
                        : liveCustomer.referBy,
                    colors,
                    context),
                Builder(builder: (ctx) {
                  final liveCount = store.bills
                      .where((b) => b.customerId == liveCustomer.id)
                      .length;
                  return _buildRow(
                      'Total Bills', '$liveCount', colors, context);
                }),
                _buildRow(
                    'Status',
                    liveCustomer.isActive ? 'Active' : 'Inactive',
                    colors,
                    context,
                    valColor: liveCustomer.isActive
                        ? colors.teal
                        : const Color(0xFFFF5555)),
              ]),
              if (liveCustomer.addressProofUrls.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSectionTile(
                    'Documents', Icons.file_present_rounded, colors, context, [
                  Text(
                      '${liveCustomer.addressProofUrls.length} Address Proof${liveCustomer.addressProofUrls.length > 1 ? 's' : ''} Attached',
                      style: jakarta(context,
                          size: 13,
                          weight: FontWeight.w700,
                          color: colors.brand)),
                  const SizedBox(height: 12),
                  ...liveCustomer.addressProofUrls.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final url = entry.value;
                    final isPdf = _isProofPdf(url);
                    final label = liveCustomer.addressProofUrls.length > 1
                        ? 'PROOF ${idx + 1}'
                        : 'ADDRESS PROOF';
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: idx < liveCustomer.addressProofUrls.length - 1
                              ? 12
                              : 0),
                      child: GestureDetector(
                        onTap: () => _openProof(context, url, colors),
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.border, width: 1),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: isPdf
                              ? _buildPdfTile(label, colors, context)
                              : Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CORSResilientImage(
                                      imageUrl: url,
                                      fit: BoxFit.cover,
                                      placeholder: const Center(
                                          child: CircularProgressIndicator()),
                                      errorWidget: const Center(
                                          child: Icon(Icons.broken_image,
                                              size: 36)),
                                    ),
                                    Positioned(
                                      right: 12,
                                      bottom: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.6),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Text(
                                            '$label · TAP TO ENLARGE',
                                            style: jakarta(context,
                                                size: 9,
                                                weight: FontWeight.w800,
                                                color: Colors.white)),
                                      ),
                                    )
                                  ],
                                ),
                        ),
                      ),
                    );
                  }),
                ]),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  bool _isProofPdf(String url) =>
      url.startsWith('data:application/pdf') ||
      url.toLowerCase().endsWith('.pdf');

  Widget _buildPdfTile(String label, AppColors colors, BuildContext context) {
    return Container(
      color: colors.surfaceVariant,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: Color(0xFFE53935), size: 36),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: jakarta(context,
                  size: 11, weight: FontWeight.w700, color: colors.textMain)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(kIsWeb ? Icons.open_in_new_rounded : Icons.download_rounded,
                  size: 12, color: colors.brand),
              const SizedBox(width: 4),
              Text(kIsWeb ? 'Tap to open' : 'Tap to download',
                  style: jakarta(context, size: 10, color: colors.brand)),
            ],
          ),
        ],
      ),
    );
  }

  void _openProof(BuildContext context, String url, AppColors colors) {
    if (_isProofPdf(url)) {
      _openOrDownloadPdf(context, url, colors);
    } else {
      showDialog(
          context: context,
          builder: (ctx) => Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.zero,
                child: InteractiveViewer(
                  child: CORSResilientImage(
                    imageUrl: url,
                    placeholder:
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: Center(
                        child: Icon(Icons.error_outline,
                            size: 48, color: colors.textSub)),
                  ),
                ),
              ));
    }
  }

  void _openOrDownloadPdf(
      BuildContext context, String url, AppColors colors) async {
    try {
      // Decode base64 data URI  →  raw bytes
      final comma = url.indexOf(',');
      if (comma == -1) return;
      final b64 = url.substring(comma + 1);
      final bytes = base64Decode(b64);
      if (kIsWeb) {
        await downloadPdfWeb(bytes, 'address_proof.pdf');
      } else {
        // Native: show a snack
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('PDF preview not supported on this platform'),
          backgroundColor: colors.brand,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not open PDF: $e'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Widget _buildSectionTile(String title, IconData icon, AppColors colors,
      BuildContext context, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
              color: colors.glow, blurRadius: 16, offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: colors.brand),
          const SizedBox(width: 8),
          Text(title,
              style: jakarta(context,
                  size: 15, weight: FontWeight.w800, color: colors.textMain)),
        ]),
        const SizedBox(height: 16),
        ...children,
      ]),
    );
  }

  Widget _buildRow(
      String label, String value, AppColors colors, BuildContext context,
      {Color? valColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: jakarta(context, size: 12, color: colors.textMuted))),
          Expanded(
              child: Text(value,
                  style: jakarta(context,
                      size: 12,
                      weight: FontWeight.w700,
                      color: valColor ?? colors.textMain))),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppColors colors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: colors.border, width: 0.5)),
        title: Text('Delete this Client?',
            style: jakarta(context,
                size: 18, weight: FontWeight.w800, color: colors.textMain)),
        content: Text(
            'This action is permanent and will remove the record from the cloud. Bills associated with this client will remain.',
            style: jakarta(context, size: 13, color: colors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: jakarta(context,
                        size: 12,
                        weight: FontWeight.w800,
                        color: colors.textSub)
                    .copyWith(letterSpacing: 1)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppStore>().deleteCustomer(customer.id);
              onBack();
            },
            child: Text('DELETE',
                style: jakarta(context,
                        size: 12,
                        weight: FontWeight.w800,
                        color: const Color(0xFFFF5555))
                    .copyWith(letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}
