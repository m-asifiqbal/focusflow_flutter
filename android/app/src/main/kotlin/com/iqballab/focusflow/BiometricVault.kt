package com.iqballab.focusflow

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.util.concurrent.atomic.AtomicBoolean
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * The vault's biometric key copy on Android (channel `focusflow/biometric_vault`).
 *
 * What: one small secret (the vault data key, base64) encrypted with an
 * AES-256-GCM Android Keystore key that needs a fresh strong-biometric match
 * for EVERY use (`setUserAuthenticationRequired`, validity 0) and is
 * invalidated when fingerprints are added. Reading shows the system prompt;
 * the Keystore only releases the plaintext after the match (CryptoObject).
 * Why this exists instead of flutter_secure_storage's biometric mode: that
 * plugin drives the framework prompt from a worker thread, ignores the
 * "Use PIN" button (the call never answered), leaks a thread per prompt and
 * can answer a call twice (a crash). Here: androidx BiometricPrompt on the
 * main thread, every call answered exactly once, "Use PIN" / cancel answered
 * at once, one prompt at a time, and nothing is shown while the activity
 * cannot host a prompt (that is what used to crash).
 *
 * Replies: the secret / true / null (no copy, or invalidated and removed),
 * or an error code — `cancelled` (user, "Use PIN", timeout, lock-out),
 * `busy` (a prompt is already open), `unavailable` (no strong biometrics /
 * activity not ready), `error`.
 */
class BiometricVault(private val activity: FragmentActivity) {

    private val prefs: SharedPreferences =
        activity.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** The open prompt (main thread only). */
    private var active: BiometricPrompt? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val reply = Once(result)
        try {
            when (call.method) {
                "available" -> reply.success(canAuthenticate())
                "read" -> read(call, reply)
                "write" -> write(call, reply)
                "delete" -> {
                    delete(call.argument<String>("key") ?: "")
                    reply.success(null)
                }
                "cancel" -> {
                    cancelPrompt()
                    reply.success(null)
                }
                else -> reply.notImplemented()
            }
        } catch (t: Throwable) {
            reply.error("error", t.javaClass.simpleName, null)
        }
    }

    // ── operations ──────────────────────────────────────────────

    private fun read(call: MethodCall, reply: Once) {
        val name = call.argument<String>("key") ?: return reply.error("error", "no key", null)
        val iv = prefs.getString("$name.iv", null)
        val data = prefs.getString("$name.ct", null)
        val key = loadKey()
        if (iv == null || data == null || key == null) return reply.success(null)
        val cipher = try {
            Cipher.getInstance(TRANSFORM).also {
                it.init(
                    Cipher.DECRYPT_MODE,
                    key,
                    GCMParameterSpec(TAG_BITS, Base64.decode(iv, Base64.NO_WRAP)),
                )
            }
        } catch (e: KeyPermanentlyInvalidatedException) {
            // New fingerprint enrolled: the copy can never be read again.
            delete(name)
            return reply.success(null)
        } catch (e: Exception) {
            delete(name)
            return reply.success(null)
        }
        prompt(call, cipher, reply) { done ->
            val plain = done.doFinal(Base64.decode(data, Base64.NO_WRAP))
            reply.success(String(plain, Charsets.UTF_8))
        }
    }

    private fun write(call: MethodCall, reply: Once) {
        val name = call.argument<String>("key") ?: return reply.error("error", "no key", null)
        val value = call.argument<String>("value") ?: return reply.error("error", "no value", null)
        // A fresh key every time: the old copy is gone with the old key.
        delete(name)
        val cipher = try {
            Cipher.getInstance(TRANSFORM).also { it.init(Cipher.ENCRYPT_MODE, createKey()) }
        } catch (e: Exception) {
            return reply.error("unavailable", e.javaClass.simpleName, null)
        }
        prompt(call, cipher, reply) { done ->
            val sealed = done.doFinal(value.toByteArray(Charsets.UTF_8))
            prefs.edit()
                .putString("$name.iv", Base64.encodeToString(done.iv, Base64.NO_WRAP))
                .putString("$name.ct", Base64.encodeToString(sealed, Base64.NO_WRAP))
                .apply()
            reply.success(true)
        }
    }

    private fun delete(name: String) {
        prefs.edit().remove("$name.iv").remove("$name.ct").apply()
        try {
            KeyStore.getInstance(KEYSTORE).apply { load(null) }.deleteEntry(ALIAS)
        } catch (_: Exception) {
        }
    }

    // ── prompt ──────────────────────────────────────────────────

    private fun canAuthenticate(): Boolean =
        BiometricManager.from(activity)
            .canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) ==
            BiometricManager.BIOMETRIC_SUCCESS

    private fun cancelPrompt() {
        val p = active ?: return
        active = null
        try {
            p.cancelAuthentication()
        } catch (_: Throwable) {
        }
    }

    /**
     * Shows the system prompt for [cipher] and runs [onAuthenticated] with
     * the unlocked cipher. Answers [reply] exactly once whatever happens.
     */
    private fun prompt(
        call: MethodCall,
        cipher: Cipher,
        reply: Once,
        onAuthenticated: (Cipher) -> Unit,
    ) {
        if (active != null) return reply.error("busy", "A prompt is already open", null)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            activity.isFinishing || activity.isDestroyed ||
            activity.supportFragmentManager.isStateSaved || !canAuthenticate()
        ) {
            return reply.error("unavailable", "Cannot show the prompt now", null)
        }
        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(r: BiometricPrompt.AuthenticationResult) {
                active = null
                val c = r.cryptoObject?.cipher
                if (c == null) {
                    reply.error("error", "No cipher", null)
                    return
                }
                try {
                    onAuthenticated(c)
                } catch (t: Throwable) {
                    reply.error("error", t.javaClass.simpleName, null)
                }
            }

            override fun onAuthenticationError(code: Int, message: CharSequence) {
                active = null
                // "Use PIN", back, tap outside, lock-out, time-out, cancelled
                // by the system: the user did not authenticate.
                reply.error("cancelled", "$code", null)
            }
            // onAuthenticationFailed: one wrong finger — the prompt stays open.
        }
        try {
            val prompt = BiometricPrompt(
                activity,
                ContextCompat.getMainExecutor(activity),
                callback,
            )
            val info = BiometricPrompt.PromptInfo.Builder()
                .setTitle(call.argument<String>("title") ?: "")
                .setSubtitle(call.argument<String>("subtitle"))
                .setNegativeButtonText(call.argument<String>("negative") ?: "")
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .setConfirmationRequired(false)
                .build()
            active = prompt
            prompt.authenticate(info, BiometricPrompt.CryptoObject(cipher))
        } catch (t: Throwable) {
            active = null
            reply.error("unavailable", t.javaClass.simpleName, null)
        }
    }

    // ── key ─────────────────────────────────────────────────────

    private fun loadKey(): SecretKey? = try {
        KeyStore.getInstance(KEYSTORE).apply { load(null) }.getKey(ALIAS, null) as? SecretKey
    } catch (_: Exception) {
        null
    }

    private fun createKey(): SecretKey {
        val spec = KeyGenParameterSpec.Builder(
            ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    // Every use needs a fresh strong-biometric match.
                    setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
                } else {
                    @Suppress("DEPRECATION")
                    setUserAuthenticationValidityDurationSeconds(-1)
                }
            }
            .build()
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
            .apply { init(spec) }
            .generateKey()
    }

    /** Wraps a [MethodChannel.Result] so it can only be answered once. */
    private class Once(private val result: MethodChannel.Result) {
        private val done = AtomicBoolean(false)

        fun success(value: Any?) {
            if (done.compareAndSet(false, true)) result.success(value)
        }

        fun error(code: String, message: String?, details: Any?) {
            if (done.compareAndSet(false, true)) result.error(code, message, details)
        }

        fun notImplemented() {
            if (done.compareAndSet(false, true)) result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL = "focusflow/biometric_vault"
        private const val PREFS = "ff_biometric_vault_v3"
        private const val KEYSTORE = "AndroidKeyStore"
        private const val ALIAS = "ff_biometric_vault_key_v3"
        private const val TRANSFORM = "AES/GCM/NoPadding"
        private const val TAG_BITS = 128
    }
}
