import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer.dart';
import '../models/store.dart';
import '../theme/app_theme.dart';
import '../widgets/cors_image.dart';

class CustomerDetailScreen extends StatelessWidget {
  final Customer customer;
  final VoidCallback onBack;
  final Function(Customer) onEdit;
  const CustomerDetailScreen(
      {super.key,
      required this.customer,
      required this.onBack,
      required this.onEdit});

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
                _buildRow('Total Bills', '${liveCustomer.billCount}', colors,
                    context),
                _buildRow(
                    'Status',
                    liveCustomer.isActive ? 'Active' : 'Inactive',
                    colors,
                    context,
                    valColor: liveCustomer.isActive
                        ? colors.teal
                        : const Color(0xFFFF5555)),
              ]),
              if (liveCustomer.addressProofUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSectionTile(
                    'Documents', Icons.file_present_rounded, colors, context, [
                  Text('Address Proof Attached',
                      style: jakarta(context,
                          size: 13,
                          weight: FontWeight.w700,
                          color: colors.brand)),
                  const SizedBox(height: 12),
                  Builder(builder: (context) {
                    final String url = liveCustomer.addressProofUrl;
                    final bool isImage = url.toLowerCase().contains('.jpg') ||
                        url.toLowerCase().contains('.jpeg') ||
                        url.toLowerCase().contains('.png') ||
                        url.toLowerCase().contains('.webp') ||
                        url.toLowerCase().contains('.heic');

                    // If we can't definitively say it's an image from the URL extension (e.g. Drive IDs),
                    // but it's a known image link from our upload process (we force uc?export=view), we try to render.
                    // However, we should verify the original upload name if possible. Since we only have the URL,
                    // we err on the side of displaying it as a clickable document link if it looks generic,
                    // but since the original code tried to render all `uc?export=view` as images, let's use a
                    // more robust fallback: always show the URL launcher card, BUT if it is explicitly an image, show the image preview.
                    // Wait, the user uploaded PDFs and they got broken. The previous code grouped everything under CORSResilientImage.

                    // Let's implement a clean "Tap to View Document" card for safety, or render image if we know it's an image.
                    // Actually, the user asked to handle image and non-image separately. Let's make it a smart card.
                    if (isImage) {
                      return GestureDetector(
                        onTap: () async {
                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(Uri.parse(url),
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.border, width: 1),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CORSResilientImage(
                                imageUrl: url,
                                fit: BoxFit.cover,
                                placeholder: const Center(
                                    child: CircularProgressIndicator()),
                                errorWidget: const Center(
                                    child: Icon(Icons.broken_image, size: 36)),
                              ),
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text('TAP TO VIEW',
                                      style: jakarta(context,
                                          size: 9,
                                          weight: FontWeight.w800,
                                          color: Colors.white)),
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    } else {
                      return GestureDetector(
                        onTap: () async {
                          final String targetUrl = liveCustomer.addressProofUrl;
                          if (targetUrl.isNotEmpty) {
                            final url = Uri.parse(targetUrl);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url,
                                  mode: LaunchMode.externalApplication);
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            const Text('📄', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text('Open Attached Document',
                                    style: jakarta(context,
                                        size: 12,
                                        weight: FontWeight.w700,
                                        color: colors.textMain))),
                            Icon(Icons.open_in_new_rounded,
                                size: 18, color: colors.brand),
                          ]),
                        ),
                      );
                    }
                  }),
                ]),
              ],
            ]),
          ),
        ),
      ]),
    );
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
