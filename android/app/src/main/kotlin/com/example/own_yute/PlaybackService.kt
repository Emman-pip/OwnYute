package com.example.own_yute

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.MediaPlayer
import android.media.AudioAttributes
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.IBinder

/** Keeps the current audio playing with Android media notification controls. */
class PlaybackService : Service() {
    private var player: MediaPlayer? = null
    private var title = "OwnYute"
    private var artist = ""
    private var source: String? = null
    private var paused = false
    private var prepared = false
    private var started = false
    private var pendingSeek: Int? = null
    private var audioManager: AudioManager? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(NotificationChannel(CHANNEL, "Music playback", NotificationManager.IMPORTANCE_LOW))
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
        when (intent?.action) {
            ACTION_PLAY -> {
                val source = intent.getStringExtra("source") ?: return START_NOT_STICKY
                this.source = source
                title = intent.getStringExtra("title") ?: "OwnYute"
                artist = intent.getStringExtra("artist") ?: ""
                val position = intent.getIntExtra("position", 0)
                started = false
                startForeground(NOTIFICATION_ID, notification())
                play(source, position)
            }
            ACTION_PAUSE -> {
                if (prepared) player?.pause()
                paused = true
                started = false
                emit("paused", null)
                updateNotification()
            }
            ACTION_RESUME -> {
                paused = false
                if (prepared) startPlayer()
                updateNotification()
            }
            ACTION_SEEK -> {
                val to = intent.getIntExtra("position", 0)
                emit("buffering", null)
                if (prepared) player?.seekTo(to) else pendingSeek = to
            }
            ACTION_PREVIOUS -> emit("previous", null)
            ACTION_NEXT -> emit("next", null)
            ACTION_STOP -> {
                player?.release()
                player = null
                prepared = false
                started = false
                audioManager?.abandonAudioFocus(null)
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        } catch (failure: Exception) {
            fail(failure.message ?: "Playback failed.")
        }
        return START_STICKY
    }

    private fun play(source: String, position: Int) {
        player?.release()
        player = null
        prepared = false
        started = false
        pendingSeek = null
        paused = false
        try {
            val next = MediaPlayer()
            next.setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build())
            next.setOnPreparedListener { ready ->
                if (player === ready) {
                    try {
                        prepared = true
                        emit("duration", ready.duration)
                        val startAt = pendingSeek ?: position
                        if (startAt > 0) ready.seekTo(startAt)
                        else emit("ready", null)
                        pendingSeek = null
                        if (!paused) startPlayer()
                        if (player === ready) updateNotification()
                    } catch (failure: Exception) {
                        fail(failure.message ?: "Could not prepare audio.")
                    }
                }
            }
            next.setOnCompletionListener { completed ->
                if (player === completed) emit("ended", null)
            }
            next.setOnSeekCompleteListener { seeked ->
                if (player === seeked) emit("ready", null)
            }
            next.setOnInfoListener { informed, what, _ ->
                if (player === informed) {
                    if (what == MediaPlayer.MEDIA_INFO_BUFFERING_START) emit("buffering", null)
                    if (what == MediaPlayer.MEDIA_INFO_BUFFERING_END) emit("ready", null)
                }
                true
            }
            next.setOnErrorListener { failed, what, extra ->
                if (player === failed) fail("Playback failed ($what, $extra). Check the audio file or stream.")
                true
            }
            player = next
            if (source.startsWith("content://")) next.setDataSource(this, Uri.parse(source))
            else next.setDataSource(source)
            next.prepareAsync()
        } catch (failure: Exception) {
            fail(failure.message ?: "Could not prepare audio.")
        }
    }

    private fun startPlayer() {
        try {
            val active = player ?: return
            val focus = audioManager?.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
            if (focus == AudioManager.AUDIOFOCUS_REQUEST_FAILED) {
                fail("Another app has audio focus. Try playing again.")
                return
            }
            active.start()
            started = true
            emit("started", null)
            updateNotification()
        } catch (failure: Exception) {
            fail(failure.message ?: "Could not start audio.")
        }
    }

    private fun fail(message: String) {
        emit("error", message)
        player?.release()
        player = null
        prepared = false
        started = false
        audioManager?.abandonAudioFocus(null)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun notification(): Notification {
        val openApp = PendingIntent.getActivity(this, 10,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val previous = action(ACTION_PREVIOUS, 11)
        val pauseOrResume = action(if (started) ACTION_PAUSE else ACTION_RESUME, 12)
        val next = action(ACTION_NEXT, 13)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
            else Notification.Builder(this)
        return builder
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setContentText(artist)
            .setContentIntent(openApp)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .addAction(Notification.Action.Builder(android.R.drawable.ic_media_previous, "Previous", previous).build())
            .addAction(Notification.Action.Builder(
                if (started) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (started) "Pause" else "Play", pauseOrResume).build())
            .addAction(Notification.Action.Builder(android.R.drawable.ic_media_next, "Next", next).build())
            .setStyle(Notification.MediaStyle().setShowActionsInCompactView(0, 1, 2))
            .build()
    }

    private fun action(name: String, requestCode: Int): PendingIntent = PendingIntent.getService(
        this, requestCode, Intent(this, PlaybackService::class.java).setAction(name),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun updateNotification() {
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification())
    }

    private fun emit(method: String, value: Any?) {
        events?.invoke(method, value)
    }

    /** Live playback state so a reopened UI can reattach. Null when idle. */
    fun state(): Map<String, Any?>? {
        val active = player ?: return null
        return mapOf(
            "source" to source,
            "title" to title,
            "artist" to artist,
            "position" to (try { active.currentPosition } catch (_: Exception) { 0 }),
            "duration" to (try { active.duration } catch (_: Exception) { 0 }),
            "playing" to (started && !paused),
            "prepared" to prepared,
        )
    }

    override fun onDestroy() {
        player?.release()
        player = null
        if (instance === this) instance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_PLAY = "own_yute.PLAY"
        const val ACTION_PAUSE = "own_yute.PAUSE"
        const val ACTION_RESUME = "own_yute.RESUME"
        const val ACTION_STOP = "own_yute.STOP"
        const val ACTION_SEEK = "own_yute.SEEK"
        const val ACTION_PREVIOUS = "own_yute.PREVIOUS"
        const val ACTION_NEXT = "own_yute.NEXT"
        private const val CHANNEL = "own_yute_playback"
        private const val NOTIFICATION_ID = 14
        var events: ((String, Any?) -> Unit)? = null
        var instance: PlaybackService? = null
            private set
    }
}
