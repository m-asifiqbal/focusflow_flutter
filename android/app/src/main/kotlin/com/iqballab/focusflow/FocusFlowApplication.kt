package com.iqballab.focusflow

import android.app.Application
import com.gdelataillade.alarm.services.AlarmRingingLiveData

/**
 * Brings the alarm screen to the front *the moment an alarm starts ringing*.
 *
 * The `alarm` package rings from a foreground service and relies on a
 * full-screen intent to show a screen — which Android only honours while the
 * phone is locked or the screen is off; with the phone in use it shows a
 * heads-up and nothing else, so the screen only appeared after a tap.
 * A real alarm clock opens its screen itself. Android lets an app do that
 * from the background when the user allowed "Display over other apps"
 * (see [AlarmActivity.bringToFront]); this Application class is the one place
 * that is alive whenever the service is — the alarm's broadcast starts the
 * process, this runs before the service does, and no Flutter engine is needed.
 */
class FocusFlowApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AlarmRingingLiveData.instance.observeForever { ringing ->
            if (ringing == true) AlarmActivity.bringToFront(this)
        }
    }
}
