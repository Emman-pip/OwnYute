package com.example.own_yute

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference

/** Runs the bundled yt-dlp and FFmpeg executables away from the UI thread. */
class ToolBridge(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "own_yute/tools")
    private val main = Handler(Looper.getMainLooper())
    private val workers = Executors.newCachedThreadPool()
    private val ytDlpWorker = Executors.newSingleThreadExecutor()
    private val ffmpegProcesses = ConcurrentHashMap<String, Process>()

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ytDlp", "ffmpeg" -> (if (call.method == "ytDlp") ytDlpWorker else workers).execute {
                    try {
                        val id = call.argument<String>("id") ?: error("Missing task ID")
                        val args = call.argument<List<String>>("args") ?: error("Missing arguments")
                        CrashDiagnostics.mark(context, if (call.method == "ytDlp") "yt-dlp command started" else "FFmpeg command started")
                        val output = if (call.method == "ytDlp")
                            runYtDlp(id, args, call.argument<Boolean>("progress") == true)
                        else runFfmpeg(id, args)
                        CrashDiagnostics.mark(context, if (call.method == "ytDlp") "yt-dlp command finished" else "FFmpeg command finished")
                        main.post { result.success(output) }
                    } catch (failure: Throwable) {
                        if (failure is VirtualMachineError || failure is ThreadDeath) throw failure
                        CrashDiagnostics.failure(context, "tool command failed", failure)
                        main.post { result.error("tool_failed", failure.message ?: failure.toString(), null) }
                    }
                }
                "updateNightly" -> ytDlpWorker.execute {
                    try {
                        val version = updateNightly()
                        main.post { result.success(version) }
                    } catch (failure: Throwable) {
                        if (failure is VirtualMachineError || failure is ThreadDeath) throw failure
                        CrashDiagnostics.failure(context, "nightly update failed", failure)
                        main.post { result.error("update_failed", failure.message ?: failure.toString(), null) }
                    }
                }
                "cancel" -> {
                    val id = call.argument<String>("id")
                    if (id != null) {
                        YoutubeDL.getInstance().destroyProcessById(id)
                        ffmpegProcesses.remove(id)?.destroyForcibly()
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun runYtDlp(id: String, args: List<String>, streamProgress: Boolean): Map<String, Any> {
        require(args.isNotEmpty()) { "Missing yt-dlp URL" }
        YoutubeDL.getInstance().init(context)
        val request = YoutubeDLRequest(args.last()).addCommands(args.dropLast(1))
        val response = if (streamProgress) {
            YoutubeDL.getInstance().execute(request, id, { progress, _, line ->
                main.post {
                    channel.invokeMethod("progress", mapOf(
                        "id" to id,
                        "value" to progress.toDouble(),
                        "line" to line,
                    ))
                }
            })
        } else YoutubeDL.getInstance().execute(request, id)
        return mapOf(
            "exitCode" to response.exitCode,
            "stdout" to response.out,
            "stderr" to response.err,
        )
    }

    private fun updateNightly(): String {
        val ytDlp = YoutubeDL.getInstance()
        CrashDiagnostics.mark(context, "yt-dlp initialization started")
        ytDlp.init(context)
        val installed = File(context.noBackupFilesDir, "youtubedl-android/yt-dlp/yt-dlp")
        try {
            probeVersion(installed)
        } catch (failure: Exception) {
            CrashDiagnostics.failure(context, "installed yt-dlp failed validation; restoring bundled version", failure)
            restoreBundled(ytDlp, installed)
        }
        val backup = File.createTempFile("own_yute_yt_dlp_", ".bak", context.cacheDir)
        try {
            installed.copyTo(backup, overwrite = true)
        } catch (failure: Exception) {
            backup.delete()
            throw failure
        }
        var safeToDeleteBackup = true
        try {
            CrashDiagnostics.mark(context, "nightly download started")
            ytDlp.updateYoutubeDL(context, YoutubeDL.UpdateChannel.NIGHTLY)
            CrashDiagnostics.mark(context, "nightly version validation started")
            val version = probeVersion(installed)
            CrashDiagnostics.mark(context, "nightly update validated")
            return version
        } catch (failure: Throwable) {
            if (failure is VirtualMachineError || failure is ThreadDeath) throw failure
            try {
                restoreBackup(backup, installed)
                probeVersion(installed)
                CrashDiagnostics.mark(context, "previous yt-dlp restored")
            } catch (restoreFailure: Throwable) {
                failure.addSuppressed(restoreFailure)
                try {
                    restoreBundled(ytDlp, installed)
                    CrashDiagnostics.mark(context, "bundled yt-dlp restored")
                } catch (bundledFailure: Throwable) {
                    failure.addSuppressed(bundledFailure)
                    safeToDeleteBackup = false
                    throw IOException("Nightly update failed and yt-dlp recovery failed. Backup: ${backup.absolutePath}", failure)
                }
            }
            clearUpdateVersion()
            throw failure
        } finally {
            if (safeToDeleteBackup) backup.delete()
        }
    }

    private fun restoreBundled(ytDlp: YoutubeDL, installed: File) {
        if (installed.exists() && !installed.delete()) throw IOException("Could not remove invalid yt-dlp")
        ytDlp.init_ytdlp(context, installed.parentFile!!)
        probeVersion(installed)
        clearUpdateVersion()
    }

    private fun restoreBackup(backup: File, installed: File) {
        val staged = File(installed.parentFile, "yt-dlp.restore")
        try {
            backup.copyTo(staged, overwrite = true)
            if (!staged.renameTo(installed)) staged.copyTo(installed, overwrite = true)
        } finally {
            staged.delete()
        }
    }

    private fun clearUpdateVersion() {
        context.getSharedPreferences("youtubedl-android", Context.MODE_PRIVATE).edit()
            .remove("dlpVersion").remove("dlpVersionName").commit()
    }

    private fun probeVersion(installed: File): String {
        require(installed.isFile && installed.length() > 0) { "yt-dlp executable is missing" }
        val nativeDir = File(context.applicationInfo.nativeLibraryDir)
        val python = File(nativeDir, "libpython.so")
        require(python.isFile) { "Bundled Python is missing" }
        val packages = File(context.noBackupFilesDir, "youtubedl-android/packages")
        val pythonHome = File(packages, "python/usr")
        val builder = ProcessBuilder(python.absolutePath, installed.absolutePath, "--version")
            .redirectErrorStream(true)
        builder.environment().apply {
            this["LD_LIBRARY_PATH"] = listOf(
                File(packages, "python/usr/lib").absolutePath,
                File(packages, "ffmpeg/usr/lib").absolutePath,
                File(packages, "aria2c/usr/lib").absolutePath,
            ).joinToString(":")
            this["SSL_CERT_FILE"] = File(packages, "python/usr/etc/tls/cert.pem").absolutePath
            this["PATH"] = (System.getenv("PATH") ?: "") + ":" + nativeDir.absolutePath
            this["PYTHONHOME"] = pythonHome.absolutePath
            this["HOME"] = pythonHome.absolutePath
            this["TMPDIR"] = context.cacheDir.absolutePath
        }
        val process = builder.start()
        val output = ByteArrayOutputStream()
        val readFailure = AtomicReference<Throwable?>()
        val reader = Thread {
            try {
                process.inputStream.use { input ->
                    val buffer = ByteArray(4096)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        if (output.size() < 16384) output.write(buffer, 0, minOf(count, 16384 - output.size()))
                    }
                }
            } catch (failure: Throwable) {
                readFailure.set(failure)
            }
        }.apply { isDaemon = true; start() }
        val deadline = System.nanoTime() + 20_000_000_000L
        var exitCode: Int
        while (true) {
            try {
                exitCode = process.exitValue()
                break
            } catch (_: IllegalThreadStateException) {
                if (System.nanoTime() >= deadline) {
                    process.destroy()
                    throw IOException("yt-dlp version check timed out")
                }
                Thread.sleep(50)
            }
        }
        reader.join(1000)
        readFailure.get()?.let { throw IOException("Could not read yt-dlp version", it) }
        val text = output.toString(Charsets.UTF_8.name()).trim()
        val version = text.lineSequence().lastOrNull()?.trim().orEmpty()
        if (exitCode != 0 || !Regex("^\\d{4}\\.\\d{1,2}\\.\\d{1,2}.*").matches(version)) {
            throw IOException("yt-dlp version check failed: ${text.take(300)}")
        }
        return version
    }

    private fun runFfmpeg(id: String, args: List<String>): Map<String, Any> {
        FFmpeg.getInstance().init(context)
        val executable = File(context.applicationInfo.nativeLibraryDir, "libffmpeg.so")
        require(executable.exists()) { "Bundled FFmpeg executable is missing" }
        val packages = File(context.noBackupFilesDir, "youtubedl-android/packages")
        val ffmpegLibraries = File(packages, "ffmpeg/usr/lib")
        require(ffmpegLibraries.isDirectory) { "Bundled FFmpeg libraries are missing" }
        val command = listOf(executable.absolutePath) + args
        val builder = ProcessBuilder(command)
        builder.environment()["LD_LIBRARY_PATH"] = listOf(
            File(packages, "python/usr/lib").absolutePath,
            ffmpegLibraries.absolutePath,
            File(packages, "aria2c/usr/lib").absolutePath,
        ).joinToString(":")
        builder.environment()["PATH"] = context.applicationInfo.nativeLibraryDir + ":" + (System.getenv("PATH") ?: "")
        val process = builder.start()
        ffmpegProcesses[id] = process
        val error = StringBuilder()
        val errorReader = Thread {
            process.errorStream.bufferedReader().useLines { lines -> lines.forEach { error.appendLine(it) } }
        }
        errorReader.start()
        val output = process.inputStream.bufferedReader().readText()
        val code = process.waitFor()
        errorReader.join()
        ffmpegProcesses.remove(id)
        return mapOf("exitCode" to code, "stdout" to output, "stderr" to error.toString())
    }

    fun dispose() {
        ffmpegProcesses.values.forEach { it.destroyForcibly() }
        ffmpegProcesses.clear()
        workers.shutdownNow()
        ytDlpWorker.shutdownNow()
        channel.setMethodCallHandler(null)
    }
}
