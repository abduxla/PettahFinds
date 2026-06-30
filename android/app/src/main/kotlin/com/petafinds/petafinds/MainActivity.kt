package com.petafinds.petafinds

import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import java.security.MessageDigest

class MainActivity : FlutterActivity() {

    override fun onStart() {
        super.onStart()
        logSigningCerts()
    }

    // ---------------------------------------------------------------------------
    // Signing-certificate diagnostic.
    // Prints every SHA-1 and SHA-256 of all certificates that signed this APK.
    //
    // API 26-27  : reads the legacy GET_SIGNATURES block (v1 / JAR signing).
    // API 28+    : reads GET_SIGNING_CERTIFICATES (v2 / v3 / v4).
    //              - hasMultipleSigners()  → v1/v2 multi-signer APK: logs each signer.
    //              - single signer (v3)   → logs the active cert and any key-rotation
    //                                       history from signingCertificateHistory.
    // ---------------------------------------------------------------------------
    private fun logSigningCerts() {
        try {
            val pkg = packageName
            Log.w(TAG, "══════════════════════════════════════════════")
            Log.w(TAG, "Package : $pkg")
            Log.w(TAG, "API lvl : ${Build.VERSION.SDK_INT}")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val info = packageManager.getPackageInfo(
                    pkg, PackageManager.GET_SIGNING_CERTIFICATES
                )
                val si = info.signingInfo
                if (si == null) {
                    Log.e(TAG, "signingInfo is null")
                    return
                }

                if (si.hasMultipleSigners()) {
                    // v1/v2 multi-signer — log each signer
                    si.apkContentsSigners.forEachIndexed { idx, cert ->
                        printCert(cert, "Signer ${idx + 1} of ${si.apkContentsSigners.size}")
                    }
                } else {
                    // v3/v4 single signer (possibly with key rotation)
                    val active = si.apkContentsSigners.firstOrNull()
                    if (active != null) printCert(active, "Active signer")

                    val history = si.signingCertificateHistory
                    if (history != null && history.size > 1) {
                        Log.w(TAG, "── Key-rotation history (${history.size} entries) ──")
                        history.forEachIndexed { idx, cert ->
                            printCert(cert, "History[${idx + 1}]")
                        }
                    }
                }
            } else {
                // API 26-27: legacy signature block
                @Suppress("DEPRECATION")
                val info = packageManager.getPackageInfo(pkg, PackageManager.GET_SIGNATURES)
                @Suppress("DEPRECATION")
                val sigs = info.signatures
                if (sigs.isNullOrEmpty()) {
                    Log.e(TAG, "No signatures found (legacy path)")
                    return
                }
                sigs.forEachIndexed { idx, cert ->
                    printCert(cert, "Legacy sig ${idx + 1} of ${sigs.size}")
                }
            }

            Log.w(TAG, "══════════════════════════════════════════════")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read signing cert: $e")
        }
    }

    private fun printCert(sig: Signature, label: String) {
        val bytes = sig.toByteArray()
        Log.w(TAG, "── $label ──")
        Log.w(TAG, "SHA-1:   ${fingerprint(bytes, "SHA-1")}")
        Log.w(TAG, "SHA-256: ${fingerprint(bytes, "SHA-256")}")
    }

    private fun fingerprint(certBytes: ByteArray, algo: String): String =
        MessageDigest.getInstance(algo)
            .digest(certBytes)
            .joinToString(":") { "%02X".format(it) }

    companion object {
        private const val TAG = "PETTAHFINDS_CERT"
    }
}
