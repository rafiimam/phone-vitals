package com.rafiimam.phonevitals
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
/// Boot/shutdown bookkeeping in the same SharedPreferences file Dart uses
/// (shared_preferences exposes keys to native code with the "flutter." prefix).
/// - ACTION_SHUTDOWN / ACTION_REBOOT: a user/system-initiated power-off or restart
///   is starting -> mark this boot as ending cleanly.
/// - BOOT_COMPLETED: move that flag into pv_prev_boot_clean (so Dart can judge the
///   PREVIOUS boot), reset it for the new boot, and stamp the boot time.
/// An unexpected power loss / kernel panic sends NEITHER broadcast, so the flag
/// stays false - that asymmetry is the failure signal the recorder relies on.
class BootReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val sp = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    when (intent.action) {
      Intent.ACTION_BOOT_COMPLETED -> {
        val wasClean = sp.getBoolean("flutter.pv_clean_exit", false)
        val c = sp.getLong("flutter.pv_boot_count", 0L)
        sp.edit()
          .putBoolean("flutter.pv_prev_boot_clean", wasClean)
          .putBoolean("flutter.pv_clean_exit", false)
          .putLong("flutter.pv_boot_count", c + 1)
          .putLong("flutter.pv_last_boot_ms", System.currentTimeMillis())
          .apply()
      }
      Intent.ACTION_SHUTDOWN, Intent.ACTION_REBOOT -> {
        sp.edit().putBoolean("flutter.pv_clean_exit", true).apply()
      }
    }
  }
}
