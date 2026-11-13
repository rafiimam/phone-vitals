package com.rafiimam.phonevitals
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
/// Records boots and clean shutdowns in SharedPreferences ("flutter." prefix is
/// how shared_preferences exposes keys to native code: flutter.pv_*)
/// On BOOT_COMPLETED: bump boot count. On ACTION_SHUTDOWN: set clean marker -
/// its ABSENCE after a heartbeat is how Dart infers an unclean exit.
class BootReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val sp = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    when (intent.action) {
      Intent.ACTION_BOOT_COMPLETED -> { val c = sp.getLong("flutter.pv_boot_count", 0L); sp.edit().putLong("flutter.pv_boot_count", c+1).putLong("flutter.pv_last_boot_ms", System.currentTimeMillis()).apply() }
      Intent.ACTION_SHUTDOWN, Intent.ACTION_REBOOT -> { sp.edit().putBoolean("flutter.pv_clean_exit", true).apply() }
    }
  }
}
