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
import android.app.Activity
import android.content.ContentUris
import android.net.Uri
import android.provider.MediaStore
import android.app.ApplicationExitInfo
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import android.app.usage.StorageStatsManager
import android.os.storage.StorageManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channel = "com.rafiimam.phonevitals/diagnostics"
    private var pendingDelete: MethodChannel.Result? = null
    private var pendingDeletePaths: List<String> = emptyList()
    private val reqDelete = 4471
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
                    "getInstalledApps" -> runAsync(result) { installedApps() }
                    "getSystemIntegrity" -> result.success(systemIntegrity())
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "openUsageAccessSettings" -> { startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)); result.success(true) }
                    "getUsageStats" -> result.success(usageStats())
                    "listSharedFiles" -> runAsync(result) { sharedFiles() }
                    "getBootInfo" -> result.success(bootInfo())
                    "deleteFiles" -> { val u = (call.argument<List<String>>("uris") ?: emptyList()); val p = (call.argument<List<String>>("paths") ?: emptyList()); deleteFiles(u, p, result) }
                    "getAppStorageStats" -> appStorageStatsAsync(result)
                    "openAppSettings" -> { val pkg = call.argument<String>("package") ?: ""; try { startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) } catch (e: Exception) {}; result.success(true) }
                    "getOwnExitReasons" -> result.success(ownExitReasons())
                    "llmModelInfo" -> { val f = brainFile(); result.success(mapOf("path" to f.absolutePath, "exists" to f.exists(), "sizeBytes" to if (f.exists()) f.length() else 0L)) }
                    "llmGenerate" -> { val prompt = call.argument<String>("prompt") ?: ""; llmGenerateAsync(prompt, result) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.success(null) }
        }
    }

    /// Heavy probes (package scans, MediaStore + hashing) must not run on the
    /// platform thread - that is the UI thread, and a media-heavy phone would
    /// jank or ANR. Same pattern as appStorageStatsAsync.
    private fun <T> runAsync(result: MethodChannel.Result, block: () -> T) {
        Thread {
            val v = try { block() } catch (e: Throwable) { null }
            runOnUiThread { try { result.success(v) } catch (e: Exception) {} }
        }.start()
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
        // Sentinel rule (honesty labels): an unsupported reading is null /
        // Unavailable, never a magic number passed off as a measurement.
        val tempRaw = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE) ?: Int.MIN_VALUE
        val voltRaw = intent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, Int.MIN_VALUE) ?: Int.MIN_VALUE
        val curNow = bm.getLongProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
        val chargeCtr = bm.getLongProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
        return mapOf("level" to pct, "health" to health, "status" to status,
            "tempC" to (if (tempRaw == Int.MIN_VALUE) null else tempRaw / 10.0),
            "voltageMv" to (if (voltRaw == Int.MIN_VALUE) null else voltRaw),
            "technology" to (intent?.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY) ?: "Unknown"),
            "cycleCount" to cycle,
            "currentNowUa" to (if (curNow == Long.MIN_VALUE) null else curNow),
            "chargeCounterUah" to (if (chargeCtr == Long.MIN_VALUE) null else chargeCtr))
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
        listOf("/system/bin/su","/system/xbin/su","/sbin/su").forEach { if (File(it).exists()) rootClues.add(it) }
        try { Runtime.getRuntime().exec(arrayOf("which","su")).let { if (it.waitFor()==0) rootClues.add("su in PATH") } } catch (e: Exception) {}
        if (Build.TAGS?.contains("test-keys") == true) rootClues.add("test-keys build")
        return mapOf("securityPatch" to (Build.VERSION.SECURITY_PATCH ?: "Unknown"), "fingerprint" to Build.FINGERPRINT,
            "verifiedBootState" to verified, "debuggable" to (sysProp("ro.debuggable") == "1"),
            "rootSuspected" to rootClues.isNotEmpty(), "rootClues" to rootClues,
            "systemTimeDriftSeconds" to null, "buildType" to (Build.TYPE ?: "Unknown"))
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
        // WEEKLY buckets can repeat a package; merge: sum foreground, keep latest use.
        val merged = LinkedHashMap<String, LongArray>()
        for (u in usm.queryUsageStats(UsageStatsManager.INTERVAL_WEEKLY, start, end)) {
            val a = merged.getOrPut(u.packageName) { longArrayOf(0L, 0L) }
            a[0] += u.totalTimeInForeground
            if (u.lastTimeUsed > a[1]) a[1] = u.lastTimeUsed
        }
        return merged.map { mapOf("packageName" to it.key, "totalForegroundMs" to it.value[0], "lastTimeUsed" to it.value[1]) }
    }

    /// Shared files via MediaStore-facing directories we can legally list.
    /// Full MediaStore querying + header validation is v0.2 - see PLAN.md.
    /// v0.1 lists Download + Documents top-level, hashes files >1MB for duplicates.
    private fun sharedFiles(): List<Map<String, Any?>> {
        val dirs = listOf(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS))
        val out = mutableListOf<Map<String, Any?>>()
        for (d in dirs) { d?.listFiles()?.forEach { f -> if (f.isFile) {
            val sha: String? = null // filled later, only for size-colliding files
            val headerOk: Boolean? = when { f.name.lowercase().endsWith(".jpg") || f.name.lowercase().endsWith(".jpeg") -> try { val b = ByteArray(2); f.inputStream().use { it.read(b) }; (b[0] == 0xFF.toByte() && b[1] == 0xD8.toByte()) } catch (e: Exception) { false }
                f.name.lowercase().endsWith(".png") -> try { val b = ByteArray(4); f.inputStream().use { it.read(b) }; (b[0] == 0x89.toByte()) } catch (e: Exception) { false }
                else -> null }
            out.add(mapOf("path" to f.absolutePath, "size" to f.length(), "sha256" to sha, "headerOk" to headerOk, "uri" to null))
        } } }
        mediaStoreFiles(out)
        addCollisionHashes(out)
        return out
    }

    private fun sha256Of(open: () -> java.io.InputStream?): String? {
        return try { val md = MessageDigest.getInstance("SHA-256"); open()?.use { inp -> val buf = ByteArray(8192); var n: Int; while (inp.read(buf).also { n = it } > 0) md.update(buf, 0, n) }; md.digest().joinToString("") { "%02x".format(it) } } catch (e: Exception) { null }
    }

    /// Duplicate detection only needs hashes for files whose SIZE collides
    /// with another file's size - unique sizes cannot be duplicates. Hashing
    /// every photo on the phone (old behaviour) wasted seconds and battery.
    private fun addCollisionHashes(out: MutableList<Map<String, Any?>>) {
        val counts = HashMap<Long, Int>()
        for (e in out) { val s = (e["size"] as? Number)?.toLong() ?: 0L; if (s in (1024*1024)..(200L*1024*1024)) counts[s] = (counts[s] ?: 0) + 1 }
        for (i in out.indices) {
            val e = out[i]
            val s = (e["size"] as? Number)?.toLong() ?: 0L
            if (s !in (1024*1024)..(200L*1024*1024) || (counts[s] ?: 0) < 2) continue
            val uriStr = e["uri"] as? String
            val sha = if (uriStr != null) sha256Of { contentResolver.openInputStream(Uri.parse(uriStr)) } else sha256Of { File(e["path"].toString()).inputStream() }
            if (sha != null) out[i] = e + ("sha256" to sha)
        }
    }

    /// MediaStore merge: files the legacy directory listing cannot see under
    /// scoped storage, each with its content URI - the URI is what makes the
    /// system-consent delete (createDeleteRequest) possible in Storage Doctor.
    private fun mediaStoreFiles(into: MutableList<Map<String, Any?>>) {
        try {
            val coll = MediaStore.Files.getContentUri("external")
            val proj = arrayOf(MediaStore.Files.FileColumns._ID, MediaStore.Files.FileColumns.DISPLAY_NAME, MediaStore.Files.FileColumns.SIZE, MediaStore.Files.FileColumns.RELATIVE_PATH, MediaStore.Files.FileColumns.DATA)
            contentResolver.query(coll, proj, null, null, null)?.use { c ->
                val idI = c.getColumnIndex(MediaStore.Files.FileColumns._ID)
                val nameI = c.getColumnIndex(MediaStore.Files.FileColumns.DISPLAY_NAME)
                val sizeI = c.getColumnIndex(MediaStore.Files.FileColumns.SIZE)
                val relI = c.getColumnIndex(MediaStore.Files.FileColumns.RELATIVE_PATH)
                val dataI = c.getColumnIndex(MediaStore.Files.FileColumns.DATA)
                if (idI < 0 || nameI < 0 || sizeI < 0) return
                val seen = into.map { it["path"].toString() }.toHashSet()
                while (c.moveToNext()) {
                    val name = c.getString(nameI) ?: continue
                    val rel = if (relI >= 0) c.getString(relI) ?: "" else ""
                    val dataPath = if (dataI >= 0) c.getString(dataI) else null
                    val path = dataPath ?: ("/storage/emulated/0/" + rel + name)
                    if (!seen.add(path)) continue
                    val size = c.getLong(sizeI)
                    val uri = ContentUris.withAppendedId(coll, c.getLong(idI))
                    val sha: String? = null // filled later, only for size-colliding files
                    val lower = name.lowercase()
                    val headerOk: Boolean? = when { lower.endsWith(".jpg") || lower.endsWith(".jpeg") -> try { val b = ByteArray(2); contentResolver.openInputStream(uri)?.use { it.read(b) }; (b[0] == 0xFF.toByte() && b[1] == 0xD8.toByte()) } catch (e: Exception) { false }
                        lower.endsWith(".png") -> try { val b = ByteArray(4); contentResolver.openInputStream(uri)?.use { it.read(b) }; (b[0] == 0x89.toByte()) } catch (e: Exception) { false }
                        else -> null }
                    into.add(mapOf("path" to path, "size" to size, "sha256" to sha, "headerOk" to headerOk, "uri" to uri.toString()))
                }
            }
        } catch (e: Exception) {}
    }

    /// Storage Doctor deletion. MediaStore URIs go through Android's own
    /// consent dialog (createDeleteRequest, API 30+) - the user approves the
    /// exact batch; nothing is deleted silently. Plain paths (legacy listing)
    /// are deleted directly only where the OS lets this app write.
    private fun deleteFiles(uriStrs: List<String>, paths: List<String>, result: MethodChannel.Result) {
        val uriList = uriStrs.mapNotNull { try { Uri.parse(it) } catch (e: Exception) { null } }
        if (uriList.isEmpty() || Build.VERSION.SDK_INT < 30) {
            var ok = true
            for (u in uriList) { try { if (contentResolver.delete(u, null, null) <= 0) ok = false } catch (e: Exception) { ok = false } }
            for (p in paths) { try { val f = File(p); if (f.exists() && !f.delete()) ok = false } catch (e: Exception) { ok = false } }
            result.success(ok); return
        }
        if (pendingDelete != null) { result.success(false); return }
        pendingDelete = result; pendingDeletePaths = paths
        try {
            val pi = MediaStore.createDeleteRequest(contentResolver, uriList)
            startIntentSenderForResult(pi.intentSender, reqDelete, null, 0, 0, 0)
        } catch (e: Exception) { pendingDelete = null; pendingDeletePaths = emptyList(); result.success(false) }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == reqDelete) {
            val r = pendingDelete; pendingDelete = null
            val paths = pendingDeletePaths; pendingDeletePaths = emptyList()
            if (resultCode == Activity.RESULT_OK) {
                var ok = true
                for (p in paths) { try { val f = File(p); if (f.exists() && !f.delete()) ok = false } catch (e: Exception) { ok = false } }
                r?.success(ok)
            } else { r?.success(false) }
        }
    }

    /// Cache Radar data: per-UID app/data/cache bytes via StorageStatsManager.
    /// Only works when the user has granted Usage Access (PACKAGE_USAGE_STATS);
    /// returns empty otherwise. Runs on a worker thread - 100+ packages is slow.
    private fun appStorageStatsAsync(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 26) { result.success(emptyList<Map<String, Any?>>()); return }
        if (!hasUsageAccess()) { result.success(emptyList<Map<String, Any?>>()); return }
        Thread {
            val out = mutableListOf<Map<String, Any?>>()
            try {
                val ssm = getSystemService(Context.STORAGE_STATS_SERVICE) as StorageStatsManager
                val sm = getSystemService(Context.STORAGE_SERVICE) as StorageManager
                val uuid = sm.getUuidForPath(Environment.getDataDirectory())
                val pm = packageManager
                val apps = try { pm.getInstalledApplications(0) } catch (e: Exception) { emptyList<ApplicationInfo>() }
                for (ai in apps) {
                    try { val st = ssm.queryStatsForUid(uuid, ai.uid); out.add(mapOf("packageName" to ai.packageName, "appBytes" to st.appBytes, "dataBytes" to st.dataBytes, "cacheBytes" to st.cacheBytes)) } catch (e: Exception) {}
                }
            } catch (e: Throwable) {}
            runOnUiThread { try { result.success(out) } catch (e: Exception) {} }
        }.start()
    }

    /// ApplicationExitInfo: Android stores exit reasons ONLY for the caller's
    /// own UID (other packages need the DUMP signature permission). This is
    /// the recorder's self-awareness: was BlackBox MD itself force-stopped,
    /// low-memory killed, or did it crash between sessions?
    private fun ownExitReasons(): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT < 30) return emptyList()
        return try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            am.getHistoricalProcessExitReasons(packageName, 0, 10).map { ei ->
                val label = when (ei.reason) {
                    ApplicationExitInfo.REASON_EXIT_SELF -> "Exited normally"
                    ApplicationExitInfo.REASON_SIGNALED -> "Killed by a system signal"
                    ApplicationExitInfo.REASON_LOW_MEMORY -> "Killed: system was low on memory"
                    ApplicationExitInfo.REASON_CRASH -> "BlackBox MD crashed"
                    ApplicationExitInfo.REASON_CRASH_NATIVE -> "BlackBox MD native crash"
                    ApplicationExitInfo.REASON_ANR -> "BlackBox MD stopped responding (ANR)"
                    ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "Initialization failure"
                    ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "Killed: permission change"
                    ApplicationExitInfo.REASON_USER_REQUESTED -> "Force-stopped / swiped away by user or battery manager"
                    ApplicationExitInfo.REASON_USER_STOPPED -> "Stopped by user"
                    ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "A dependency process died"
                    else -> "Other (code ${ei.reason})"
                }
                mapOf("reason" to label, "timeMs" to ei.timestamp, "description" to (ei.description ?: ""))
            }
        } catch (e: Exception) { emptyList() }
    }

    // ---- On-device brain (Phase 3b): MediaPipe LLM Inference ----
    private fun brainFile(): File = File(filesDir, "dr_brain.task")
    @Volatile private var llm: LlmInference? = null

    private fun llmGenerateAsync(prompt: String, result: MethodChannel.Result) {
        Thread {
            try {
                val f = brainFile()
                if (!f.exists()) { runOnUiThread { result.error("NO_MODEL", "On-device model not downloaded", null) }; return@Thread }
                val options = LlmInference.LlmInferenceOptions.builder().setModelPath(f.absolutePath).setMaxTokens(4096).build()
                val engine = llm ?: LlmInference.createFromOptions(applicationContext, options).also { llm = it }
                val out = engine.generateResponse(prompt) ?: ""
                runOnUiThread { try { result.success(out) } catch (e: Exception) {} }
            } catch (e: Throwable) {
                runOnUiThread { try { result.error("LLM_ERROR", e.message ?: e.toString(), null) } catch (x: Exception) {} }
            }
        }.start()
    }
}
