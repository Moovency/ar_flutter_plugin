package io.carius.lars.ar_flutter_plugin

import android.app.Activity
import android.content.Context
import androidx.annotation.NonNull
import androidx.appcompat.app.AppCompatActivity
import com.google.ar.core.ArCoreApk
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** ArFlutterPlugin */
class ArFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel: MethodChannel
  private lateinit var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding

  private lateinit var context: Context
  private lateinit var activity: Activity

  override fun onAttachedToEngine(
      @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
  ) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ar_flutter_plugin")
    channel.setMethodCallHandler(this)

    this.flutterPluginBinding = flutterPluginBinding
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "isArEnabled" -> {
        checkArEnabled(result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun checkArEnabled( @NonNull result: Result) {
    // requestInstall(Activity, true) will triggers installation of
    // Google Play Services for AR if necessary.

    // Ensure that Google Play Services for AR and ARCore device profile data are
    // installed and up to date.
    try {

      when (ArCoreApk.getInstance().checkAvailability(context)) {
        ArCoreApk.Availability.SUPPORTED_INSTALLED -> {
          // Success: Safe to create the AR session.
          result.success(true)
        }
        else -> {
          result.success(false)
        }
      }
    } catch ( e: Exception) {
      result.success(false)
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onDetachedFromActivity() {
    channel.setMethodCallHandler(null)
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    this.flutterPluginBinding.platformViewRegistry.registerViewFactory(
        "ar_flutter_plugin", AndroidARViewFactory(binding.activity, flutterPluginBinding.binaryMessenger))
    this.activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }
}
