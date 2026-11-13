package com.rafiimam.phonevitals

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.hardware.SensorManager
import android.os.*
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channel = "com.rafiimam.phonevitals/diagnostics"
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getBatteryDetail" -> result.success(batteryDetail())
                    "getThermal" -> result.success(thermal())
                    "getMemoryStorage" -> result.success(memoryStorage())
                    "getCpuInfo" -> result.success(cpuInfo())
                    "getSensors" -> result.success(sensors())
                    "getInstalledApps" -> result.success(installedApps())
                    "getSystemIntegrity" -> result.success(systemIntegrity())
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "openUsageAccessSettings" -> { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)); result.success(true) }
                    "getUsageStats" -> result.success(usageStats())
                    "listSharedFiles" -> result.success(sharedFiles())
                    "getBootInfo" -> result.success(bootInfo())
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.success(null) }
        }
    }

    private fun batteryDetail(): Map<String, Any?> {
        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        val pct = if (level >= 0 && scale > 0) level * 100 / scale else bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        val health = when (intent?.getIntExtra(BatteryManager.EXTRA_HEALTH, -1)) {
            BatteryManager.BATTERY_HEALTH_GOOD -> "Good"; BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Overheat"
            BatteryManager.BATTERY_HEALTH_DEAD -> "Dead"; BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "Over Voltage"
            BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "Unspecified Failure"; BatteryManager.BATTERY_HEALTH_COLD -> "Cold"; else -> "Unknown" }
        val status = when (intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1)) {
            BatteryManager.BATTERY_STATUS_CHARGING -> "Charging"; BatteryManager.BATTERY_STATUS_FULL -> "Full"
            BatteryManager.BATTERY_STATUS_DISCHARGING -> "Discharging"; BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "Not Charging"; else -> "Unknown" }
        val cycle = if (Build.VERSION.SDK_INT >= 34) intent?.getIntExtra("android.os.extra.CYCLE_COUNT", -1) ?: -1 else -1
        return mapOf("level" to pct, "health" to health, "status" to status,
            "tempC" to ((intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1) ?: -1) / 10.0),
            "voltageMv" to (intent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1) ?: -1),
            "technology" to (intent?.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY) ?: "Unknown"),
            "cycleCount" to cycle,
            "currentNowUa" to bm.getLongProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW),
            "chargeCounterUah" to bm.getLongProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER))
    }

    private fun thermal(): Map<String, Any?> {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (Build.VERSION.SDK_INT < 29) return mapOf("label" to "Unavailable (Android <10)", "status" to -1, "headroom" to Double.NaN)
        val s = pm.currentThermalStatus
        val label = when (s) { 0 -> "None - normal"; 1 -> "Light throttling"; 2 -> "Moderate throttling"; 3 -> "Severe throttling"; 4 -> "Critical"; 5 -> "Emergency"; 6 -> "Shutdown imminent"; else -> "Unknown" }
        val head = try { pm.getThermalHeadroom(60).toDouble() } catch (e: Exception) { Double.NaN }
        return mapOf("label" to label, "status" to s, "headroom" to head)
    }

    private fun memoryStorage(): Map<String, Any?> {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mi = ActivityManager.MemoryInfo(); am.getMemoryInfo(mi)
        val stat = StatFs(Environment.getDataDirectory().path)
        val total = stat.totalBytes; val free = stat.availableBytes
        return mapOf("totalRamMb" to (mi.totalMem / (1024*1024)), "availRamMb" to (mi.availMem / (1024*1024)), "lowMemory" to mi.lowMemory,
            "totalStorageGb" to (total / 1e9), "freeStorageGb" to (free / 1e9),
            "storageUsedPct" to (if (total>0) ((total-free)*100/total).toInt() else 0),
            "uptimeHours" to (SystemClock.elapsedRealtime() / 3600000.0))
    }

    private fun cpuInfo(): Map<String, Any?> {
        val cores = Runtime.getRuntime().availableProcessors()
        val hardware = try { File("/proc/cpuinfo").readLines().firstOrNull { it.startsWith("Hardware") || it.startsWith("model name") }?.substringAfter(":")?.trim() ?: "Unknown" } catch (e: Exception) { "Unknown" }
        val freqs = (0 until cores).map { i -> try { File("/sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq").readText().trim().toIntOrNull() ?: -1 } catch (e: Exception) { -1 } }
        return mapOf("cores" to cores, "hardware" to hardware, "maxFreqKhz" to freqs, "abi" to (Build.SUPPORTED_ABIS.firstOrNull() ?: "Unknown"))
    }

    private fun sensors(): List<Map<String, Any?>> {
        val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        return sm.getSensorList(android.hardware.Sensor.TYPE_ALL).map { mapOf("name" to it.name, "vendor" to it.vendor, "type" to it.type, "powerMa" to it.power.toDouble()) }
    }

    private val dangerous = setOf("android.permission.CAMERA","android.permission.RECORD_AUDIO","android.permission.ACCESS_FINE_LOCATION","android.permission.READ_CONTACTS","android.permission.READ_SMS","android.permission.READ_CALL_LOG","android.permission.READ_EXTERNAL_STORAGE","android.permission.WRITE_EXTERNAL_STORAGE","android.permission.SYSTEM_ALERT_WINDOW","android.permission.REQUEST_INSTALL_PACKAGES","android.permission.READ_MEDIA_IMAGES","android.permission.POST_NOTIFICATIONS")
    private fun installedApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val flags = PackageManager.GET_PERMISSIONS
        val apps = try { pm.getInstalledApplications(flags) } catch (e: Exception) { emptyList<ApplicationInfo>() }
        return apps.map { ai ->
            val pi = try { pm.getPackageInfo(ai.packageName, PackageManager.GET_PERMISSIONS) } catch (e: Exception) { null }
            val perms = (pi?.requestedPermissions?.toList() ?: emptyList()).filter { it in dangerous }
            val installer = try { if (Build.VERSION.SDK_INT >= 30) pm.getInstallSourceInfo(ai.packageName).installingPackageName ?: "unknown" else @Suppress("DEPRECATION") pm.getInstallerPackageName(ai.packageName) ?: "unknown" } catch (e: Exception) { "unknown" }
            mapOf("packageName" to ai.packageName, "label" to pm.getApplicationLabel(ai).toString(),
                "version" to (pi?.versionName ?: ""), "installer" to installer,
                "firstInstallMs" to (pi?.firstInstallTime ?: 0L), "lastUpdateMs" to (pi?.lastUpdateTime ?: 0L),
                "isSystem" to ((ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                "targetSdk" to ai.targetSdkVersion, "dangerousPermissions" to perms)
        }.sortedBy { it["label"].toString().lowercase() }
    }

    private fun bootInfo(): Map<String, Any?> {
        val bc = try { Settings.Global.getInt(contentResolver, Settings.Global.BOOT_COUNT, -1) } catch (e: Exception) { -1 }
        val up = SystemClock.elapsedRealtime()
        return mapOf("bootCount" to bc, "uptimeMs" to up, "bootWallMs" to (System.currentTimeMillis() - up))
    }

    private fun systemIntegrity(): Map<String, Any?> {
        val verified = sysProp("ro.boot.verifiedbootstate").ifEmpty { "unavailable" }
        val rootClues = mutableListOf<String>()
        listOf("/system/bin/su","/system/xbin/su","/sbin/su","/data/local/tmp/frida-server").forEach { if (File(it).exists()) rootClues.add(it) }
        try { Runtime.getRuntime().exec(arrayOf("which","su")).let { if (it.waitFor()==0) rootClues.add("su in PATH") } } catch (e: Exception) {}
        if (Build.TAGS?.contains("test-keys") == true) rootClues.add("test-keys build")
        return mapOf("securityPatch" to (Build.VERSION.SECURITY_PATCH ?: "Unknown"), "fingerprint" to Build.FINGERPRINT,
            "verifiedBootState" to verified, "debuggable" to (sysProp("ro.debuggable") == "1"),
            "rootSuspected" to rootClues.isNotEmpty(), "rootClues" to rootClues,
            "systemTimeDriftSeconds" to 0, "buildType" to (Build.TYPE ?: "Unknown"))
    }
    private fun sysProp(key: String): String { return try { val c = Class.forName("android.os.SystemProperties"); val m = c.getMethod("get", String::class.java); (m.invoke(null, key) as? String) ?: "" } catch (e: Exception) { "" } }

    private fun hasUsageAccess(): Boolean {
        val ops = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= 29) ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName) else @Suppress("DEPRECATION") ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }
    private fun usageStats(): List<Map<String, Any?>> {
        if (!hasUsageAccess()) return emptyList()
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis(); val start = end - 7L*24*3600*1000
        return usm.queryUsageStats(UsageStatsManager.INTERVAL_WEEKLY, start, end).map { mapOf("packageName" to it.packageName, "totalForegroundMs" to it.totalTimeInForeground, "lastTimeUsed" to it.lastTimeUsed) }
    }

    /// Shared files via MediaStore-facing directories we can legally list.
    /// Full MediaStore querying + header validation is v0.2 - see PLAN.md.
    /// v0.1 lists Download + Documents top-level, hashes files >1MB for duplicates.
    private fun sharedFiles(): List<Map<String, Any?>> {
        val dirs = listOf(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS))
        val out = mutableListOf<Map<String, Any?>>()
        for (d in dirs) { d?.listFiles()?.forEach { f -> if (f.isFile) {
            var sha: String? = null
            if (f.length() in (1024*1024)..(200L*1024*1024)) { sha = try { val md = MessageDigest.getInstance("SHA-256"); f.inputStream().use { inp -> val buf = ByteArray(8192); var n: Int; while (inp.read(buf).also { n = it } > 0) md.update(buf, 0, n) }; md.digest().joinToString("") { "%02x".format(it) } } catch (e: Exception) { null } }
            val headerOk: Boolean? = when { f.name.lowercase().endsWith(".jpg") || f.name.lowercase().endsWith(".jpeg") -> try { val b = ByteArray(2); f.inputStream().use { it.read(b) }; (b[0] == 0xFF.toByte() && b[1] == 0xD8.toByte()) } catch (e: Exception) { false }
                f.name.lowercase().endsWith(".png") -> try { val b = ByteArray(4); f.inputStream().use { it.read(b) }; (b[0] == 0x89.toByte()) } catch (e: Exception) { false }
                else -> null }
            out.add(mapOf("path" to f.absolutePath, "size" to f.length(), "sha256" to sha, "headerOk" to headerOk))
        } } }
        return out
    }
}
