package com.qintx.esim_tool

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import android.telephony.euicc.EuiccManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "esim_tool/installed_esim_discovery"
    private val jsonFileChannelName = "esim_tool/json_file_transfer"
    private val phoneStateRequestCode = 2401
    private val importJsonRequestCode = 2402
    private val exportJsonRequestCode = 2403
    private var pendingDiscoveryResult: MethodChannel.Result? = null
    private var pendingImportJsonResult: MethodChannel.Result? = null
    private var pendingExportJsonResult: MethodChannel.Result? = null
    private var pendingExportJsonContent: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "discoverInstalledEsims" -> discoverInstalledEsims(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, jsonFileChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "importJsonFile" -> importJsonFile(result)
                "exportJsonFile" -> exportJsonFile(call.arguments as? Map<*, *>, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun importJsonFile(result: MethodChannel.Result) {
        if (pendingImportJsonResult != null) {
            result.error("busy", "已有一个 JSON 导入请求正在进行", null)
            return
        }
        pendingImportJsonResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/*", "*/*"))
        }
        try {
            startActivityForResult(intent, importJsonRequestCode)
        } catch (error: Exception) {
            pendingImportJsonResult = null
            result.error("open_failed", error.localizedMessage, null)
        }
    }

    private fun exportJsonFile(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (pendingExportJsonResult != null) {
            result.error("busy", "已有一个 JSON 导出请求正在进行", null)
            return
        }
        val json = arguments?.get("json") as? String
        if (json.isNullOrBlank()) {
            result.success(false)
            return
        }
        val fileName = arguments?.get("fileName") as? String ?: "esim-profiles.json"
        pendingExportJsonResult = result
        pendingExportJsonContent = json
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        try {
            startActivityForResult(intent, exportJsonRequestCode)
        } catch (error: Exception) {
            pendingExportJsonResult = null
            pendingExportJsonContent = null
            result.error("create_failed", error.localizedMessage, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            importJsonRequestCode -> handleImportJsonResult(resultCode, data?.data)
            exportJsonRequestCode -> handleExportJsonResult(resultCode, data?.data)
        }
    }

    private fun handleImportJsonResult(resultCode: Int, uri: Uri?) {
        val result = pendingImportJsonResult ?: return
        pendingImportJsonResult = null
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            val json = contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }
            result.success(json)
        } catch (error: Exception) {
            result.error("read_failed", error.localizedMessage, null)
        }
    }

    private fun handleExportJsonResult(resultCode: Int, uri: Uri?) {
        val result = pendingExportJsonResult ?: return
        val json = pendingExportJsonContent
        pendingExportJsonResult = null
        pendingExportJsonContent = null
        if (resultCode != RESULT_OK || uri == null || json == null) {
            result.success(false)
            return
        }
        try {
            contentResolver.openOutputStream(uri)?.bufferedWriter(Charsets.UTF_8)?.use { it.write(json) }
            result.success(true)
        } catch (error: Exception) {
            result.error("write_failed", error.localizedMessage, null)
        }
    }

    private fun discoverInstalledEsims(result: MethodChannel.Result) {
        if (!hasRequiredPhonePermissions()) {
            pendingDiscoveryResult = result
            ActivityCompat.requestPermissions(
                this,
                requiredPhonePermissions().toTypedArray(),
                phoneStateRequestCode,
            )
            return
        }
        result.success(buildDiscoveryResult())
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != phoneStateRequestCode) return

        val result = pendingDiscoveryResult ?: return
        pendingDiscoveryResult = null
        if (hasRequiredPhonePermissions()) {
            result.success(buildDiscoveryResult())
        } else {
            result.success(
                mapOf(
                    "supported" to supportsEsim(),
                    "permissionGranted" to false,
                    "failureReason" to "permissionDenied",
                    "note" to "没有电话状态权限，无法自动读取系统可见的 SIM/eSIM 信息。",
                    "profiles" to emptyList<Map<String, Any?>>()
                )
            )
        }
    }

    private fun hasPhoneStatePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_PHONE_STATE,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasPhoneNumbersPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_PHONE_NUMBERS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requiredPhonePermissions(): List<String> {
        return buildList {
            if (!hasPhoneStatePermission()) add(Manifest.permission.READ_PHONE_STATE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !hasPhoneNumbersPermission()) {
                add(Manifest.permission.READ_PHONE_NUMBERS)
            }
        }
    }

    private fun hasRequiredPhonePermissions(): Boolean {
        return hasPhoneStatePermission() && hasPhoneNumbersPermission()
    }

    private fun supportsEsim(): Boolean {
        val euiccManager = getSystemService(Context.EUICC_SERVICE) as? EuiccManager
        return euiccManager?.isEnabled == true
    }

    @SuppressLint("MissingPermission")
    private fun buildDiscoveryResult(): Map<String, Any?> {
        val supportsEsim = supportsEsim()
        val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
        val activeSubscriptions = try {
            subscriptionManager?.activeSubscriptionInfoList ?: emptyList()
        } catch (securityException: SecurityException) {
            return mapOf(
                "supported" to supportsEsim,
                "permissionGranted" to false,
                "failureReason" to "permissionDenied",
                "note" to "系统拒绝读取 SIM/eSIM 信息：${securityException.localizedMessage}",
                "profiles" to emptyList<Map<String, Any?>>()
            )
        }
        val availableSubscriptions = subscriptionManager?.bestEffortInactiveSubscriptions()
            ?: emptyList()

        val activeIds = activeSubscriptions.map { it.subscriptionId }.toSet()
        val mergedSubscriptions = (activeSubscriptions + availableSubscriptions)
            .distinctBy { subscription -> subscription.uniqueKey() }
        val profiles = mergedSubscriptions.map { subscription ->
            subscription.toProfileMap(isActive = activeIds.contains(subscription.subscriptionId))
        }
        val inactiveCount = profiles.count { it["isActive"] == false }
        val note = when {
            profiles.isNotEmpty() && inactiveCount > 0 -> "已尝试读取当前启用和系统可返回的未启用蜂窝套餐；未启用 eSIM 受系统限制，可能仍不完整。"
            profiles.isNotEmpty() -> "已尝试读取启用套餐和可用套餐；本机系统未返回未启用 eSIM，可能是系统限制。"
            !supportsEsim -> "当前设备或系统未报告 eSIM 支持。"
            else -> "系统没有返回可见的 SIM/eSIM 套餐，可能没有权限、没有启用蜂窝套餐，或 eSIM 处于停用状态且系统不开放。"
        }
        return mapOf(
            "supported" to supportsEsim,
            "permissionGranted" to true,
            "failureReason" to if (profiles.isEmpty()) "noProfilesFound" else null,
            "note" to note,
            "profiles" to profiles,
        )
    }

    @SuppressLint("HardwareIds")
    private fun SubscriptionInfo.toProfileMap(isActive: Boolean): Map<String, Any?> {
        val embedded = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) isEmbedded else null
        val confidence = when (embedded) {
            true -> "high"
            false -> "medium"
            null -> "medium"
        }
        return mapOf(
            "carrierName" to carrierName?.toString(),
            "displayName" to displayName?.toString(),
            "countryIso" to countryIso,
            "mobileCountryCode" to mccCompat(),
            "mobileNetworkCode" to mncCompat(),
            "phoneNumber" to bestEffortPhoneNumber(),
            "iccid" to iccId.takeIf { it.isNotBlank() },
            "systemIdentifier" to "android-subscription-$subscriptionId",
            "isEmbedded" to embedded,
            "isActive" to isActive,
            "platform" to "android",
            "confidence" to confidence,
        )
    }

    @SuppressLint("MissingPermission")
    private fun SubscriptionInfo.bestEffortPhoneNumber(): String? {
        val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
        val candidates = mutableListOf<String?>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                candidates.add(subscriptionManager?.getPhoneNumber(subscriptionId))
            } catch (_: Exception) {
                // Some devices/carriers still deny or cannot provide the number.
            }
        }

        candidates.add(number)

        try {
            val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            candidates.add(telephonyManager?.createForSubscriptionId(subscriptionId)?.line1Number)
        } catch (_: Exception) {
            // Deprecated fallback; best effort only.
        }

        return candidates
            .asSequence()
            .mapNotNull { it?.trim() }
            .firstOrNull { it.isNotBlank() }
    }

    @Suppress("UNCHECKED_CAST")
    private fun SubscriptionManager.bestEffortInactiveSubscriptions(): List<SubscriptionInfo> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return emptyList()
        return listOf("getAvailableSubscriptionInfoList", "getAccessibleSubscriptionInfoList")
            .asSequence()
            .mapNotNull { methodName ->
                try {
                    javaClass.getMethod(methodName).invoke(this) as? List<SubscriptionInfo>
                } catch (_: Exception) {
                    null
                }
            }
            .firstOrNull()
            ?: emptyList()
    }

    private fun SubscriptionInfo.uniqueKey(): String {
        return listOfNotNull(
            iccId.takeIf { it.isNotBlank() },
            subscriptionId.toString(),
            displayName?.toString(),
            carrierName?.toString(),
        ).joinToString("|")
    }

    private fun SubscriptionInfo.mccCompat(): String? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) mccString else mcc.toString().takeIf { it != "0" }
    }

    private fun SubscriptionInfo.mncCompat(): String? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) mncString else mnc.toString().takeIf { it != "0" }
    }
}
