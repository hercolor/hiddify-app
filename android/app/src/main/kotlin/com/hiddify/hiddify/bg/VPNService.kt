package com.hiddify.hiddify.bg
import android.util.Log

import com.hiddify.hiddify.Settings
import android.content.Intent
import android.content.pm.PackageManager.NameNotFoundException
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import com.hiddify.core.libbox.Notification
import com.hiddify.hiddify.BuildConfig
import com.hiddify.hiddify.constant.PerAppProxyMode
import com.hiddify.hiddify.ktx.toIpPrefix
import com.hiddify.core.libbox.TunOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

class VPNService : VpnService(), PlatformInterfaceWrapper {

    companion object {
        private const val TAG = "A/VPNService"
    }

    private val service = BoxService(this, this)

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int) =
        service.onStartCommand()

    override fun onBind(intent: Intent): IBinder {
        val binder = super.onBind(intent)
        if (binder != null) {
            return binder
        }
        return service.onBind(intent)
    }

    override fun onDestroy() {
        service.onDestroy()
    }

    override fun onRevoke() {
        runBlocking {
            withContext(Dispatchers.Main) {
                service.onRevoke()
            }
        }
    }

    override fun autoDetectInterfaceControl(fd: Int) {
        val protected = protect(fd)
        debugLog("protect outbound socket fd=$fd result=$protected")
    }

    var systemProxyAvailable = false
    var systemProxyEnabled = false
    fun addIncludePackage(builder: Builder, packageName: String) {
        if (packageName == this.packageName) { 
            debugLog("Cannot include current app")
            return
        }
        try {     
            debugLog("Including app package")
            builder.addAllowedApplication(packageName)
        } catch (e: NameNotFoundException) {
        }
    }

    fun addExcludePackage(builder: Builder, packageName: String) {
        try {     
            debugLog("Excluding app package")
            builder.addDisallowedApplication(packageName)
        } catch (e: NameNotFoundException) {
        }
    }

    override fun openTun(options: TunOptions): Int {
        debugLog("openTun: starting VPN, mtu=${options.mtu}, autoRoute=${options.autoRoute}")
        var hasPermission = false
        for (i in 0 until 20) {
            if (prepare(this) != null) {
                Log.w("VPN", "android: missing vpn permission")
            } else {
                hasPermission = true
                break
            }
            Thread.sleep(50)
        }

        if (!hasPermission) {
             error("android: missing vpn permission")
    }
//        service.fileDescriptor?.close()

        val builder = Builder()
            .setSession("BflyVPN")
            .setMtu(options.mtu)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        val inet4Address = options.inet4Address
        var inet4AddressCount = 0
        while (inet4Address.hasNext()) {
            val address = inet4Address.next()
            builder.addAddress(address.address(), address.prefix())
            inet4AddressCount++
        }

        val inet6Address = options.inet6Address
        var ignoredInet6AddressCount = 0
        while (inet6Address.hasNext()) {
            inet6Address.next()
            ignoredInet6AddressCount++
        }
        debugLog("openTun: added IPv4 addresses=$inet4AddressCount, ignored IPv6 addresses=$ignoredInet6AddressCount")

        if (options.autoRoute) {
            builder.addDnsServer(options.dnsServerAddress.value)
            debugLog("openTun: DNS server configured")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val inet4RouteAddress = options.inet4RouteAddress
                var inet4RouteCount = 0
                if (inet4RouteAddress.hasNext()) {
                    while (inet4RouteAddress.hasNext()) {
                        builder.addRoute(inet4RouteAddress.next().toIpPrefix())
                        inet4RouteCount++
                    }
                } else {
                    builder.addRoute("0.0.0.0", 0)
                    inet4RouteCount++
                }
                debugLog("openTun: IPv4 routes=$inet4RouteCount, defaultRoute=true")

                val inet6RouteAddress = options.inet6RouteAddress
                var ignoredInet6RouteCount = 0
                if (inet6RouteAddress.hasNext()) {
                    while (inet6RouteAddress.hasNext()) {
                        inet6RouteAddress.next()
                        ignoredInet6RouteCount++
                    }
                }
                debugLog("openTun: IPv6 disabled, ignored IPv6 routes=$ignoredInet6RouteCount, addDefaultIPv6=false")

                val inet4RouteExcludeAddress = options.inet4RouteExcludeAddress
                while (inet4RouteExcludeAddress.hasNext()) {
                    builder.excludeRoute(inet4RouteExcludeAddress.next().toIpPrefix())
                }

                val inet6RouteExcludeAddress = options.inet6RouteExcludeAddress
                while (inet6RouteExcludeAddress.hasNext()) {
                    inet6RouteExcludeAddress.next()
                }
            } else {
                val inet4RouteAddress = options.inet4RouteRange
                var inet4RouteCount = 0
                if (inet4RouteAddress.hasNext()) {
                    while (inet4RouteAddress.hasNext()) {
                        val address = inet4RouteAddress.next()
                        builder.addRoute(address.address(), address.prefix())
                        inet4RouteCount++
                    }
                } else {
                    builder.addRoute("0.0.0.0", 0)
                    inet4RouteCount++
                }
                debugLog("openTun: IPv4 routes=$inet4RouteCount, defaultRoute=true")

                val inet6RouteAddress = options.inet6RouteRange
                var ignoredInet6RouteCount = 0
                if (inet6RouteAddress.hasNext()) {
                    while (inet6RouteAddress.hasNext()) {
                        inet6RouteAddress.next()
                        ignoredInet6RouteCount++
                    }
                }
                debugLog("openTun: IPv6 disabled, ignored IPv6 routes=$ignoredInet6RouteCount, addDefaultIPv6=false")
            }

            if (Settings.perAppProxyEnabled) {
                val appList = Settings.perAppProxyList
                if (Settings.perAppProxyMode == PerAppProxyMode.INCLUDE) {
                    appList.forEach {
                        addIncludePackage(builder,it)
                    }
//                    addIncludePackage(builder,packageName)
                } else {
                    appList.forEach {
                        addExcludePackage(builder,it)
                    }
                    addExcludePackage(builder,packageName)
                }
            } else {
                val includePackage = options.includePackage
                if (includePackage.hasNext()) {
                    while (includePackage.hasNext()) {
                        addIncludePackage(builder,includePackage.next())
                    }
                    //                    addIncludePackage(builder,packageName)
                }else {
                    val excludePackage = options.excludePackage
                    if (excludePackage.hasNext()) {
                        while (excludePackage.hasNext()) {
                            addExcludePackage(builder, excludePackage.next())
                        }
                    }

                    addExcludePackage(builder, packageName)
                }
                
            }
        }

        if (options.isHTTPProxyEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            systemProxyAvailable = true
            systemProxyEnabled = Settings.systemProxyEnabled
            if (systemProxyEnabled) builder.setHttpProxy(
                ProxyInfo.buildDirectProxy(
                    options.httpProxyServer, options.httpProxyServerPort
                )
            )
        } else {
            systemProxyAvailable = false
            systemProxyEnabled = false
        }

        val pfd = builder.establish() ?: error("android: the application is not prepared or is revoked")
        service.fileDescriptor = pfd
        debugLog("openTun: established tun fd=${pfd.fd}")
        return pfd.fd
    }

//    override fun writeLog(message: String) = service.writeLog(message)

    override fun sendNotification(notification: Notification) {
//        service.sendNotification(notification)
    }

    private fun debugLog(message: String) {
        if (BuildConfig.DEBUG || Settings.debugMode) {
            Log.d(TAG, message)
        }
    }
}
