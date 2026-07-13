package app.owlnighter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val APP_ICON_CHANNEL = "app.owlnighter/app_icon"

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_ICON_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "setMood") {
                    val mood = call.argument<String>("mood")
                    if (mood == null) {
                        result.error("INVALID_ARGUMENT", "Missing 'mood' argument", null)
                    } else {
                        AppIconSwitcher.apply(applicationContext, mood)
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
