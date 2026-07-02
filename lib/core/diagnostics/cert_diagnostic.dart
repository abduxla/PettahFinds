// TEMPORARY DIAGNOSTIC — remove after the Play App Signing SHA-1 is identified.
//
// Triggered by a long-press on the PetaFinds logo in sign_in_screen.dart.
// Calls the native MethodChannel in MainActivity to read the signing certificate
// of the INSTALLED APK directly from the Android PackageManager — the same
// source GMS queries when checking ApiException: 10.  This is NOT reading
// any .jks file; it reads whatever certificate was actually used to sign
// the binary on the device (i.e. the Play App Signing certificate for Play
// Store builds, or the debug certificate for flutter-run builds).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.petafinds.petafinds/cert_diag');

Future<void> showCertDiagnostics(BuildContext context) async {
  String output;
  try {
    final result = await _channel.invokeMethod<String>('getSigningCerts');
    output = result ?? '(empty response)';
  } on MissingPluginException {
    output = 'Not available on this platform.';
  } on PlatformException catch (e) {
    output = 'PlatformException\ncode: ${e.code}\nmessage: ${e.message}';
  } catch (e) {
    output = 'Unexpected error: $e';
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => _CertDialog(output: output),
  );
}

class _CertDialog extends StatelessWidget {
  const _CertDialog({required this.output});
  final String output;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Signing Certificate',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 340,
        child: SingleChildScrollView(
          child: SelectableText(
            output,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              height: 1.55,
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: output));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Certificate info copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Text('Copy All'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
