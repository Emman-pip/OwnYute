package com.example.own_yute

import android.content.Intent
import android.content.pm.PackageManager
import android.Manifest
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var playerChannel: MethodChannel? = null
    private var toolBridge: ToolBridge? = null
    private var storageBridge: StorageBridge? = null
    private var diagnosticsChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        CrashDiagnostics.install(applicationContext)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        toolBridge = ToolBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        storageBridge = StorageBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        diagnosticsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "own_yute/diagnostics")
        diagnosticsChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "report" -> result.success(CrashDiagnostics.report(applicationContext))
                "recordDart" -> {
                    CrashDiagnostics.dartFailure(
                        applicationContext,
                        call.argument<String>("message").orEmpty(),
                        call.argument<String>("stack").orEmpty(),
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        playerChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "own_yute/player")
        PlaybackService.events = { method, value ->
            runOnUiThread { playerChannel?.invokeMethod(method, value) }
        }
        playerChannel?.setMethodCallHandler { call, result ->
            val action = when (call.method) {
                "play" -> PlaybackService.ACTION_PLAY
                "pause" -> PlaybackService.ACTION_PAUSE
                "resume" -> PlaybackService.ACTION_RESUME
                "seek" -> PlaybackService.ACTION_SEEK
                "stop" -> PlaybackService.ACTION_STOP
                else -> null
            }
            if (action == null) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val intent = Intent(this, PlaybackService::class.java).setAction(action)
                if (action == PlaybackService.ACTION_PLAY) {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 50918)
                    }
                    intent.putExtra("source", call.argument<String>("url"))
                    intent.putExtra("position", call.argument<Int>("position") ?: 0)
                    intent.putExtra("title", call.argument<String>("title"))
                    intent.putExtra("artist", call.argument<String>("artist"))
                    if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent)
                    else startService(intent)
                } else {
                    if (action == PlaybackService.ACTION_SEEK) {
                        intent.putExtra("position", call.argument<Int>("position") ?: 0)
                    }
                    startService(intent)
                }
                result.success(null)
            } catch (failure: Exception) {
                result.error("playback_failed", failure.message, null)
            }
        }
    }

    @Deprecated("Uses the platform document picker result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (storageBridge?.onActivityResult(requestCode, resultCode, data) != true) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onDestroy() {
        PlaybackService.events = null
        playerChannel = null
        toolBridge?.dispose()
        storageBridge?.dispose()
        diagnosticsChannel?.setMethodCallHandler(null)
        diagnosticsChannel = null
        super.onDestroy()
    }
}
