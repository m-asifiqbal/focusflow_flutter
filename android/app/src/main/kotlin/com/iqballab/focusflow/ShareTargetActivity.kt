package com.iqballab.focusflow

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log

/**
 * The app's entry in Android's share sheet ("Share" from a browser, YouTube,
 * any app that shares text or a link). Invisible: it reads the shared text and
 * subject, hands them to [MainActivity] in the app's own task, and finishes.
 *
 * Why a separate activity instead of an intent filter on MainActivity: a share
 * starts its target inside the *sharing app's* task. MainActivity there would
 * be a second copy of the app (a second Flutter engine on the same encrypted
 * database) stacked on top of the browser. Forwarding with NEW_TASK |
 * REORDER_TO_FRONT reaches the one running copy (or starts it), the same way
 * the home-screen widgets open the app.
 *
 * Dart saves the text as a new note (lib/features/notes/presentation/
 * shared_note_intake.dart). Nothing is sent anywhere.
 */
class ShareTargetActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            forward(intent)
        } catch (e: Exception) {
            Log.w(TAG, "Share could not be handed over: ${e.message}")
        }
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }

    private fun forward(source: Intent?) {
        if (source?.action != Intent.ACTION_SEND) return
        val text = source.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.trim().orEmpty()
        val subject = source.getCharSequenceExtra(Intent.EXTRA_SUBJECT)?.toString()?.trim().orEmpty()
        if (text.isEmpty() && subject.isEmpty()) return
        startActivity(
            Intent(this, MainActivity::class.java)
                .setAction(ACTION_SHARE)
                .putExtra(EXTRA_TEXT, text.take(MAX_TEXT))
                .putExtra(EXTRA_SUBJECT, subject.take(MAX_SUBJECT))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        )
    }

    companion object {
        private const val TAG = "FFShare"

        /** MainActivity's action and extras for a forwarded share. */
        const val ACTION_SHARE = "com.iqballab.focusflow.action.SHARE"
        const val EXTRA_TEXT = "ff.text"
        const val EXTRA_SUBJECT = "ff.subject"

        /** A note body, not a book: longer shares are cut. */
        private const val MAX_TEXT = 100_000
        private const val MAX_SUBJECT = 500
    }
}
