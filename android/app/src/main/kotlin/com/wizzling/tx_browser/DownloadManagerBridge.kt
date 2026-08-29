package com.wizzling.tx_browser

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Environment
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class DownloadManagerBridge(private val context: Context) : MethodChannel.MethodCallHandler {

    private val downloadManager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "enqueueDownload" -> {
                val url = call.argument<String>("url")
                val fileName = call.argument<String>("fileName") ?: "download"
                val mimeType = call.argument<String>("mimeType")
                val userAgent = call.argument<String>("userAgent")
                val cookies = call.argument<String>("cookies")

                if (url.isNullOrEmpty()) {
                    result.error("INVALID_URL", "URL cannot be null or empty", null)
                    return
                }

                try {
                    val downloadId = enqueue(url, fileName, mimeType, userAgent, cookies)
                    result.success(downloadId)
                } catch (e: Exception) {
                    result.error("ENQUEUE_FAILED", e.localizedMessage, null)
                }
            }

            "queryDownload" -> {
                val downloadId = call.argument<Number>("downloadId")?.toLong()
                if (downloadId == null) {
                    result.error("INVALID_ID", "Download ID cannot be null", null)
                    return
                }

                try {
                    val statusMap = queryStatus(downloadId)
                    result.success(statusMap)
                } catch (e: Exception) {
                    result.error("QUERY_FAILED", e.localizedMessage, null)
                }
            }

            "cancelDownload" -> {
                val downloadId = call.argument<Number>("downloadId")?.toLong()
                if (downloadId == null) {
                    result.error("INVALID_ID", "Download ID cannot be null", null)
                    return
                }

                val removed = downloadManager.remove(downloadId)
                result.success(removed > 0)
            }

            "openFile" -> {
                val filePath = call.argument<String>("filePath")
                val mimeType = call.argument<String>("mimeType") ?: "*/*"

                if (filePath.isNullOrEmpty()) {
                    result.error("INVALID_PATH", "File path cannot be null or empty", null)
                    return
                }

                try {
                    openFile(filePath, mimeType)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("OPEN_FAILED", e.localizedMessage, null)
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun enqueue(
        url: String,
        suggestedFileName: String,
        mimeType: String?,
        userAgent: String?,
        cookies: String?
    ): Long {
        val uri = Uri.parse(url)
        val request = DownloadManager.Request(uri)

        val cleanFileName = sanitizeFileName(suggestedFileName)
        val safeFileName = getUniqueFileName(cleanFileName)

        // Set destination in public Downloads directory
        request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, safeFileName)
        request.setTitle(safeFileName)
        request.setDescription("Tx Browser Download")

        if (!mimeType.isNullOrEmpty()) {
            request.setMimeType(mimeType)
        }

        if (!userAgent.isNullOrEmpty()) {
            request.addRequestHeader("User-Agent", userAgent)
        }

        if (!cookies.isNullOrEmpty()) {
            request.addRequestHeader("Cookie", cookies)
        }

        request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
        request.setAllowedOverMetered(true)
        request.setAllowedOverRoaming(true)

        return downloadManager.enqueue(request)
    }

    private fun queryStatus(downloadId: Long): Map<String, Any?> {
        val query = DownloadManager.Query().setFilterById(downloadId)
        val cursor: Cursor? = downloadManager.query(query)

        val resultMap = mutableMapOf<String, Any?>()

        cursor?.use {
            if (it.moveToFirst()) {
                val bytesDownloadedIndex = it.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                val totalBytesIndex = it.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
                val statusIndex = it.getColumnIndex(DownloadManager.COLUMN_STATUS)
                val localUriIndex = it.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI)
                val reasonIndex = it.getColumnIndex(DownloadManager.COLUMN_REASON)

                val bytesDownloaded = if (bytesDownloadedIndex != -1) it.getLong(bytesDownloadedIndex) else 0L
                val totalBytes = if (totalBytesIndex != -1) it.getLong(totalBytesIndex) else 0L
                val status = if (statusIndex != -1) it.getInt(statusIndex) else -1
                val localUriString = if (localUriIndex != -1) it.getString(localUriIndex) else null
                val reason = if (reasonIndex != -1) it.getInt(reasonIndex) else 0

                val statusString = when (status) {
                    DownloadManager.STATUS_PENDING -> "pending"
                    DownloadManager.STATUS_RUNNING -> "downloading"
                    DownloadManager.STATUS_PAUSED -> "paused"
                    DownloadManager.STATUS_SUCCESSFUL -> "completed"
                    DownloadManager.STATUS_FAILED -> "failed"
                    else -> "unknown"
                }

                var resolvedFilePath = localUriString
                if (localUriString != null && localUriString.startsWith("file://")) {
                    resolvedFilePath = Uri.parse(localUriString).path
                }

                resultMap["status"] = statusString
                resultMap["bytesDownloaded"] = bytesDownloaded
                resultMap["totalBytes"] = totalBytes
                resultMap["filePath"] = resolvedFilePath
                resultMap["reason"] = reason
            }
        }

        return resultMap
    }

    private fun openFile(filePath: String, mimeType: String) {
        val file = File(filePath)
        val uri: Uri = if (file.exists()) {
            try {
                FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            } catch (e: Exception) {
                Uri.fromFile(file)
            }
        } else {
            Uri.parse(filePath)
        }

        val resolvedMimeType = if (mimeType.isEmpty() || mimeType == "*/*") {
            val extension = MimeTypeMap.getFileExtensionFromUrl(filePath)
            if (!extension.isNullOrEmpty()) {
                MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.lowercase()) ?: "*/*"
            } else {
                "*/*"
            }
        } else {
            mimeType
        }

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, resolvedMimeType)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
        }

        context.startActivity(intent)
    }

    private fun sanitizeFileName(name: String): String {
        return name.replace("[\\\\/:*?\"<>|]".toRegex(), "_").trim()
    }

    private fun getUniqueFileName(fileName: String): String {
        val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val file = File(downloadDir, fileName)
        if (!file.exists()) return fileName

        val dotIndex = fileName.lastIndexOf('.')
        val baseName = if (dotIndex != -1) fileName.substring(0, dotIndex) else fileName
        val extension = if (dotIndex != -1) fileName.substring(dotIndex) else ""

        var count = 1
        while (true) {
            val candidate = if (extension.isNotEmpty()) "${baseName} ($count).${extension}" else "${baseName} ($count)"
            if (!File(downloadDir, candidate).exists()) {
                return candidate
            }
            count++
        }
    }
}
