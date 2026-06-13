import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/whatsapp_icon.dart';

const _supportEmail = 'support@petafinds.lk';
const _supportPhoneDisplay = '077 712 8291';
// E.164 for tel: and wa.me (Sri Lanka +94, drop leading 0)
const _supportPhoneE164 = '+94777128291';

Future<void> _launchSafe(BuildContext context, Uri uri,
    {String fallbackMessage = 'Could not open'}) async {
  try {
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fallbackMessage)),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fallbackMessage)),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Help Center — FAQ only
// Route: /profile/support
// ─────────────────────────────────────────────────────────────────────────────
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        backgroundColor: AppColors.bgSection,
        title: Text(
          'Help Center',
          style: GoogleFonts.nunito(
            color: AppColors.text1,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: const [
          _Section(label: 'FREQUENTLY ASKED'),
          _FaqItem(
            q: 'How do I save products?',
            a: 'Tap the heart on any product card or detail screen. '
                'Saved items appear under Profile → My Saved Items.',
          ),
          _FaqItem(
            q: 'How do I message a seller?',
            a: 'Open the product, tap "Chat Seller". You must be signed in '
                'to start a chat. Threads live under Profile → Messages.',
          ),
          _FaqItem(
            q: 'How do I list my business?',
            a: 'Create an account with the Business role at signup, then '
                'finish business setup. Once approved, add products from '
                'the Manage Products screen.',
          ),
          _FaqItem(
            q: 'My product images won\'t upload.',
            a: 'Make sure the image is under 3 MB and the file type is '
                'JPG, PNG or WebP. If it still fails, check your internet '
                'and try again.',
          ),
          _FaqItem(
            q: 'How do I report a listing?',
            a: 'Open the product, scroll to the bottom, tap "Report '
                'product". Reports are reviewed by the moderation team.',
          ),
          _FaqItem(
            q: 'How do I search by category?',
            a: 'From the home screen, tap any category pill (Electronics, '
                'Textiles, etc.) to see all businesses in that category. '
                'You can also use the Search tab to filter by name or keyword.',
          ),
          _FaqItem(
            q: 'Can I use PettahFinds without an account?',
            a: 'Yes. You can browse businesses, view products, and use the '
                'map as a guest. Saving items, messaging sellers, and '
                'managing a business listing all require an account.',
          ),
          _FaqItem(
            q: 'How do I delete my account?',
            a: 'Email support@petafinds.lk from your registered address '
                'with the subject "Delete my account". We confirm within '
                'two working days.',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Contact Us — contact methods only
// Route: /profile/contact
// ─────────────────────────────────────────────────────────────────────────────
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSection,
      appBar: AppBar(
        backgroundColor: AppColors.bgSection,
        title: Text(
          'Contact Us',
          style: GoogleFonts.nunito(
            color: AppColors.text1,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          const _Section(label: 'GET IN TOUCH'),
          _ContactTile(
            icon: Icons.mail_outline_rounded,
            label: 'Email us',
            value: _supportEmail,
            onTap: () => _launchSafe(
              context,
              Uri(
                scheme: 'mailto',
                path: _supportEmail,
                queryParameters: const {'subject': 'PetaFinds support'},
              ),
              fallbackMessage: 'Could not open mail app',
            ),
          ),
          _ContactTile(
            icon: Icons.phone_outlined,
            label: 'Call us',
            value: _supportPhoneDisplay,
            onTap: () => _launchSafe(
              context,
              Uri(scheme: 'tel', path: _supportPhoneE164),
              fallbackMessage: 'Could not open phone app',
            ),
          ),
          _ContactTile(
            icon: Icons.chat_bubble_outline_rounded,
            customIcon: const WhatsAppIcon(size: 20),
            label: 'WhatsApp',
            value: _supportPhoneDisplay,
            onTap: () => _launchSafe(
              context,
              Uri.parse(
                'https://wa.me/${_supportPhoneE164.replaceAll('+', '')}'
                '?text=${Uri.encodeComponent('Hi PetaFinds support, I need help with...')}',
              ),
              fallbackMessage: 'Could not open WhatsApp',
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared private widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String label;
  const _Section({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.text3,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final Widget? customIcon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _ContactTile({
    required this.icon,
    this.customIcon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: customIcon ?? Icon(icon, color: AppColors.teal, size: 20),
        ),
        title: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.text1,
          ),
        ),
        subtitle: Text(
          value,
          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.text3),
        ),
        trailing:
            Icon(Icons.open_in_new, size: 16, color: AppColors.teal),
        onTap: onTap,
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String q;
  final String a;
  const _FaqItem({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        shape: const Border(),
        title: Text(
          q,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.text1,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              a,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.text2,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
