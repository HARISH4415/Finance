package com.example.finance2

import android.Manifest
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import android.app.Activity
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.util.ArrayList

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.finance2/sms"

    private var pendingExcelResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSMS" -> {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")
                    
                    if (phone == null || message == null) {
                        result.error("INVALID_ARGUMENTS", "Phone or message missing", null)
                    } else {
                        // Double check permission on native side for reliability
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            if (checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                                result.error("PERMISSION_DENIED", "SMS Permission not granted", null)
                                return@setMethodCallHandler
                            }
                        }
                        sendDirectSMS(phone, message, result)
                    }
                }
                "pickExcel" -> {
                    pendingExcelResult = result
                    val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                        type = "*/*"
                        val mimeTypes = arrayOf("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "application/vnd.ms-excel")
                        putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes)
                        addCategory(Intent.CATEGORY_OPENABLE)
                    }
                    startActivityForResult(intent, 1001)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1001) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri: Uri = data.data!!
                try {
                    val inputStream: InputStream? = contentResolver.openInputStream(uri)
                    val bytes = inputStream?.readBytes()
                    if (bytes != null) {
                        pendingExcelResult?.success(bytes)
                    } else {
                        pendingExcelResult?.error("READ_ERROR", "Could not read file bytes", null)
                    }
                } catch (e: Exception) {
                    pendingExcelResult?.error("EXCEPTION", e.message, null)
                }
            } else {
                pendingExcelResult?.success(null) // Cancelled
            }
            pendingExcelResult = null
        }
    }

    private fun sendDirectSMS(phone: String, message: String, result: MethodChannel.Result) {
        try {
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                this.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val requestCode = java.util.Random().nextInt(10000)
            val sentIntent = PendingIntent.getBroadcast(
                applicationContext, 
                requestCode, 
                Intent("SMS_SENT").setPackage(packageName), 
                flags
            )

            // Split and Send
            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                val sentIntents = ArrayList<PendingIntent>()
                for (i in parts.indices) sentIntents.add(sentIntent)
                smsManager.sendMultipartTextMessage(phone, null, parts, sentIntents, null)
            } else {
                smsManager.sendTextMessage(phone, null, message, sentIntent, null)
            }

            // OPTIONAL: Try to save to Sent folder so history appears in Messages app
            try {
                val values = android.content.ContentValues()
                values.put("address", phone)
                values.put("body", message)
                values.put("date", System.currentTimeMillis())
                values.put("read", 1)
                values.put("type", 2) // 2 = SENT folder
                contentResolver.insert(android.net.Uri.parse("content://sms/sent"), values)
            } catch (e: Exception) {
                // Ignore if we don't have WRITE_SMS permission, sending is more important
            }
            
            result.success("SMS Sent")
        } catch (e: Exception) {
            result.error("SMS_FAILED", "${e.message}", e.toString())
        }
    }
}
