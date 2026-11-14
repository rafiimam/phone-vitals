package com.rafiimam.phonevitals
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
/// Boot/shutdown bookkeeping in the same SharedPreferences file Dart uses
/// (shared_preferences exposes keys to native code with the "flutter." prefix).
/// - ACTION_SHUTDOWN / ACTION_REBOOT: a user/system-initiated power-off or restart
///   is starting -> mark this boot as ending cleanly, AND capture the vitals at
///   the shutdown moment (battery level, temperature, thermal status). A
///   "clean" broadcast at 3% battery or thermal-critical is not a calm user
///   power-off - it is evidence, and the recorder's verdict needs it.
/// - BOOT_COMPLETED: move flag + vitals into pv_prev_* (so Dart can judge the
///   PREVIOUS boot), reset them for the new boot, and stamp the boot time.
/// An unexpected power loss / kernel panic sends NEITHER broadcast, so the flag
/// stays false - that asymmetry is the failure signal the recorder relies on.
/// commit() (not apply()) for the shutdown writes: the shutdown window is
/// tight and an async flush can be lost with the process.
class BootReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val sp = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    when (intent.action) {
      Intent.ACTION_BOOT_COMPLETED -> {
        val wasClean = sp.getBoolean("flutter.pv_clean_exit", false)
        val vitals = sp.getString("flutter.pv_shutdown_vitals", null)
        val c = sp.getLong("flutter.pv_boot_count", 0L)
        val e = sp.edit()
          .putBoolean("flutter.pv_prev_boot_clean", wasClean)
          .putBoolean("flutter.pv_clean_exit", false)
          .remove("flutter.pv_shutdown_vitals")
          .putLong("flutter.pv_boot_count", c + 1)
          .putLong("flutter.pv_last_boot_ms", System.currentTimeMillis())
        if (vitals != null) e.putString("flutter.pv_prev_shutdown_vitals", vitals) else e.remove("flutter.pv_prev_shutdown_vitals")
        e.commit()
      }
      Intent.ACTION_SHUTDOWN, Intent.ACTION_REBOOT -> {
        val b = try { context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)) } catch (ex: Exception) { null }
        val level = b?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = b?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val pct = if (level >= 0 && scale > 0) level * 100 / scale else -1
        val temp = b?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE) ?: Int.MIN_VALUE
        val thermal = if (Build.VERSION.SDK_INT >= 29) {
          try { (context.getSystemService(Context.POWER_SERVICE) as PowerManager).currentThermalStatus } catch (ex: Exception) { -1 }
        } else -1
        sp.edit()
          .putBoolean("flutter.pv_clean_exit", true)
          .putString("flutter.pv_shutdown_vitals", "$pct|$temp|$thermal|${System.currentTimeMillis()}")
          .commit()
      }
    }
  }
}
