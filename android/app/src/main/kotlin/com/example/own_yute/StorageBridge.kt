package com.example.own_yute

import android.app.Activity
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.InputStream
import java.util.concurrent.Executors

/** Accesses folders chosen with Android's Storage Access Framework. */
class StorageBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "own_yute/storage")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var pendingPick: MethodChannel.Result? = null
    private val resolver get() = activity.contentResolver

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "pickFolder") {
                if (pendingPick != null) {
                    result.error("picker_busy", "A folder picker is already open.", null)
                } else {
                    pendingPick = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    }
                    activity.startActivityForResult(intent, PICK_FOLDER_REQUEST)
                }
                return@setMethodCallHandler
            }
            worker.execute {
                try {
                    val value: Any? = when (call.method) {
                        "folderName" -> displayName(uri(call, "folder"))
                        "ensureFolder" -> ensureFolder(uri(call, "folder"), string(call, "name")).toString()
                        "exists" -> findChild(uri(call, "folder"), string(call, "name")) != null
                        "save" -> save(call)
                        "list" -> list(uri(call, "folder"))
                        "metadata" -> metadata(string(call, "path"))
                        "readToCache" -> readToCache(string(call, "path"))
                        "replace" -> replace(string(call, "path"), string(call, "source"))
                        "delete" -> delete(string(call, "path"))
                        "move" -> move(call)
                        "pathExists" -> pathExists(string(call, "path"))
                        else -> null
                    }
                    main.post {
                        if (value == null && call.method !in setOf("replace", "delete", "save")) {
                            result.notImplemented()
                        } else {
                            result.success(value)
                        }
                    }
                } catch (failure: Exception) {
                    main.post { result.error("storage_failed", failure.message ?: failure.toString(), null) }
                }
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_FOLDER_REQUEST) return false
        val result = pendingPick
        pendingPick = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result?.success(null)
            return true
        }
        try {
            val tree = data.data!!
            val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            resolver.takePersistableUriPermission(tree, flags)
            val root = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
            result?.success(root.toString())
        } catch (failure: Exception) {
            result?.error("folder_access", failure.message ?: failure.toString(), null)
        }
        return true
    }

    private fun string(call: MethodCall, key: String): String =
        call.argument<String>(key) ?: error("Missing $key")
    private fun uri(call: MethodCall, key: String): Uri = Uri.parse(string(call, key))
    private fun documentId(uri: Uri): String = DocumentsContract.getDocumentId(uri)

    private fun children(folder: Uri): List<Triple<Uri, String, String>> {
        val childUri = DocumentsContract.buildChildDocumentsUriUsingTree(folder, documentId(folder))
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        val output = mutableListOf<Triple<Uri, String, String>>()
        resolver.query(childUri, projection, null, null, null)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val typeColumn = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)
            while (cursor.moveToNext()) {
                val child = DocumentsContract.buildDocumentUriUsingTree(folder, cursor.getString(idColumn))
                output.add(Triple(child, cursor.getString(nameColumn) ?: "", cursor.getString(typeColumn) ?: ""))
            }
        }
        return output
    }

    private fun findChild(folder: Uri, name: String): Uri? = children(folder)
        .firstOrNull { it.second == name }?.first

    private fun ensureFolder(parent: Uri, name: String): Uri {
        require(name.isNotBlank() && name != "." && name != ".." && '/' !in name) { "Invalid folder name" }
        children(parent).firstOrNull { it.second == name }?.let {
            require(it.third == DocumentsContract.Document.MIME_TYPE_DIR) { "$name is already a file" }
            return it.first
        }
        return DocumentsContract.createDocument(
            resolver, parent, DocumentsContract.Document.MIME_TYPE_DIR, name
        ) ?: error("Could not create folder $name")
    }

    private fun displayName(uri: Uri): String {
        resolver.query(uri, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getString(0) ?: "Music folder"
        }
        return "Music folder"
    }

    private fun save(call: MethodCall): Map<String, String>? {
        val folder = uri(call, "folder")
        var name = string(call, "name")
        val source = File(string(call, "source"))
        require(source.isFile) { "Converted MP3 is missing" }
        val duplicate = string(call, "duplicate")
        var existing = findChild(folder, name)
        if (existing != null && duplicate == "skip") return null
        if (existing != null && duplicate == "keepBoth") {
            val base = name.substringBeforeLast('.', name)
            var number = 2
            do {
                name = "$base ($number).mp3"
                number++
                existing = findChild(folder, name)
            } while (existing != null)
        }
        val target = existing ?: DocumentsContract.createDocument(resolver, folder, "audio/mpeg", name)
            ?: error("Could not create $name")
        FileInputStream(source).use { input ->
            resolver.openOutputStream(target, "wt")?.use { output -> input.copyTo(output) }
                ?: error("Could not write $name")
        }
        return mapOf("path" to target.toString(), "name" to name, "folder" to folder.toString(), "folderName" to displayName(folder))
    }

    private fun list(root: Uri): List<Map<String, Any>> {
        val output = mutableListOf<Map<String, Any>>()
        val allowed = setOf("mp3", "m4a", "flac", "ogg", "wav")
        fun visit(folder: Uri, depth: Int) {
            if (depth > 24) return
            val folderName = displayName(folder)
            children(folder).forEach { (uri, name, type) ->
                if (type == DocumentsContract.Document.MIME_TYPE_DIR) {
                    visit(uri, depth + 1)
                } else if (name.substringAfterLast('.', "").lowercase() in allowed) {
                    output.add(metadata(uri.toString(), name) + mapOf(
                        "path" to uri.toString(),
                        "folder" to folder.toString(),
                        "folderName" to folderName,
                    ))
                }
            }
        }
        visit(root, 0)
        return output
    }

    private fun metadata(path: String, name: String? = null): Map<String, Any> {
        val retriever = MediaMetadataRetriever()
        val fallbackTitle = (name ?: if (path.startsWith("content://")) displayName(Uri.parse(path)) else File(path).name)
            .substringBeforeLast('.')
        return try {
            if (path.startsWith("content://")) retriever.setDataSource(activity, Uri.parse(path))
            else retriever.setDataSource(path)
            mapOf(
                "title" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE) ?: fallbackTitle),
                "artist" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST) ?: ""),
                "album" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM) ?: ""),
                "duration" to ((retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L) / 1000L).toInt(),
            )
        } catch (_: Exception) {
            mapOf("title" to fallbackTitle, "artist" to "", "album" to "", "duration" to 0)
        } finally {
            retriever.release()
        }
    }

    private fun stream(path: String): InputStream = if (path.startsWith("content://")) {
        resolver.openInputStream(Uri.parse(path)) ?: error("Could not read file")
    } else FileInputStream(File(path))

    private fun readToCache(path: String): String {
        val target = File.createTempFile("own_yute_audio_", ".mp3", activity.cacheDir)
        stream(path).use { input -> target.outputStream().use { input.copyTo(it) } }
        return target.absolutePath
    }

    private fun replace(path: String, source: String) {
        val target = Uri.parse(path)
        val replacement = File(source)
        require(replacement.isFile && replacement.length() > 0) { "Edited audio is empty" }
        val backup = File.createTempFile("own_yute_backup_", ".audio", activity.cacheDir)
        var safeToDeleteBackup = false
        try {
            try {
                stream(path).use { input -> backup.outputStream().use { input.copyTo(it) } }
            } catch (failure: Exception) {
                safeToDeleteBackup = true
                throw failure
            }
            try {
                FileInputStream(replacement).use { input ->
                    resolver.openOutputStream(target, "wt")?.use { output -> input.copyTo(output) }
                        ?: error("Could not update audio file")
                }
                safeToDeleteBackup = true
            } catch (failure: Exception) {
                try {
                    FileInputStream(backup).use { input ->
                        resolver.openOutputStream(target, "wt")?.use { output -> input.copyTo(output) }
                            ?: error("Could not restore original audio")
                    }
                    safeToDeleteBackup = true
                } catch (restoreFailure: Exception) {
                    throw IllegalStateException(
                        "Audio update failed and the original could not be restored. Backup: ${backup.absolutePath}. ${restoreFailure.message}", failure
                    )
                }
                throw failure
            }
        } finally {
            if (safeToDeleteBackup) backup.delete()
        }
    }

    private fun delete(path: String) {
        val removed = if (path.startsWith("content://")) {
            DocumentsContract.deleteDocument(resolver, Uri.parse(path))
        } else {
            File(path).delete()
        }
        require(removed || !pathExists(path)) { "Could not delete audio file" }
    }

    private fun pathExists(path: String): Boolean = if (path.startsWith("content://")) {
        resolver.query(Uri.parse(path), arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID), null, null, null)?.use {
            it.moveToFirst()
        } ?: false
    } else File(path).exists()

    private fun move(call: MethodCall): Map<String, String> {
        val source = string(call, "path")
        val destination = uri(call, "folder")
        val name = string(call, "name")
        require(findChild(destination, name) == null) { "A file with this name already exists" }
        val target = DocumentsContract.createDocument(resolver, destination, "audio/mpeg", name)
            ?: error("Could not create destination file")
        try {
            stream(source).use { input ->
                resolver.openOutputStream(target, "wt")?.use { output -> input.copyTo(output) }
                    ?: error("Could not write destination file")
            }
        } catch (failure: Exception) {
            DocumentsContract.deleteDocument(resolver, target)
            throw failure
        }
        val removed = if (source.startsWith("content://")) {
            DocumentsContract.deleteDocument(resolver, Uri.parse(source))
        } else {
            File(source).delete()
        }
        if (!removed) {
            DocumentsContract.deleteDocument(resolver, target)
            error("Could not remove the original file")
        }
        return mapOf("path" to target.toString(), "folder" to destination.toString(), "folderName" to displayName(destination))
    }

    fun dispose() {
        worker.shutdownNow()
        channel.setMethodCallHandler(null)
    }

    companion object { const val PICK_FOLDER_REQUEST = 50917 }
}
