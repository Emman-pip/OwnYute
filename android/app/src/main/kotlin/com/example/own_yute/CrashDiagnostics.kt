package com.example.own_yute

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.util.Log
import java.io.PrintWriter
import java.io.StringWriter
import java.text.DateFormat
import java.util.Date

/** Keeps a small, URL-free record of the last Android tool operation. */
object CrashDiagnostics {
    private const val PREFS = "own_yute_diagnostics"
    private const val TAG = "OwnYuteDiagnostics"
    @Volatile private var installed = false

    private fun scrub(value: String): String = value
        .replace(Regex("https?://\\S+"), "[url]")
        .replace(Regex("/storage/[^\\s:]+"), "[storage path]")

    @Synchronized
    fun install(context: Context) {
        if (installed) return
        installed = true
        val app = context.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, cause ->
            try {
                failure(app, "uncaught on ${thread.name}", cause, fatal = true)
            } catch (_: Throwable) {
                // The process may already be out of resources.
            }
            if (previous != null) previous.uncaughtException(thread, cause)
            else android.os.Process.killProcess(android.os.Process.myPid())
        }
    }

    fun mark(context: Context, stage: String) {
        Log.i(TAG, stage)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("stage", stage)
            .putLong("stageAt", System.currentTimeMillis())
            .commit()
    }

    fun failure(context: Context, stage: String, cause: Throwable, fatal: Boolean = false) {
        val writer = StringWriter()
        cause.printStackTrace(PrintWriter(writer))
        val summary = scrub("$stage\n${writer.toString().take(6000)}")
        Log.e(TAG, stage, cause)
        val edit = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("stage", stage)
            .putLong("stageAt", System.currentTimeMillis())
            .putString(if (fatal) "fatal" else "lastError", summary)
        edit.commit()
    }

    fun dartFailure(context: Context, message: String, stack: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("lastError", scrub("Flutter error: $message\n${stack.take(4000)}"))
            .putString("stage", "Flutter error")
            .putLong("stageAt", System.currentTimeMillis())
            .commit()
    }

    fun report(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val version = try {
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
            "${info.versionName} ($code)"
        } catch (_: Exception) {
            "unknown"
        }
        val exit = if (Build.VERSION.SDK_INT >= 30) try {
            val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            manager.getHistoricalProcessExitReasons(context.packageName, 0, 1)
                .firstOrNull()?.let { "Reason ${it.reason}, ${scrub(it.description.orEmpty().take(500))}" }
        } catch (_: Exception) {
            null
        } else null
        val whenRecorded = prefs.getLong("stageAt", 0L)
        return buildString {
            appendLine("OwnYute Android $version")
            appendLine("Android ${Build.VERSION.RELEASE}, SDK ${Build.VERSION.SDK_INT}, ${Build.SUPPORTED_ABIS.firstOrNull().orEmpty()}")
            appendLine("Last step: ${prefs.getString("stage", "none")}")
            if (whenRecorded != 0L) appendLine("At: ${DateFormat.getDateTimeInstance().format(Date(whenRecorded))}")
            if (exit != null) appendLine("Last process exit: $exit")
            prefs.getString("lastError", null)?.let { appendLine("Last tool error:\n$it") }
            prefs.getString("fatal", null)?.let { appendLine("Last fatal error:\n$it") }
        }
    }
}
