package app.owlnighter

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

/**
 * Switches owlnighter's home-screen LAUNCHER icon between four owl-mood
 * variants using activity-alias components declared in AndroidManifest.xml
 * (IconIdle / IconWorried / IconAngry / IconCheer, all targeting
 * MainActivity). Exactly one alias is enabled at a time via
 * PackageManager.setComponentEnabledSetting.
 *
 * This is a separate mechanism from the home-screen widget
 * (ReadingWidgetProvider.kt) — it changes the app's own launcher icon, the
 * same technique Duolingo/Snapchat use for mood/streak icons.
 */
object AppIconSwitcher {

    private const val PREFS_NAME = "AppIconState"
    private const val PREF_LAST_MOOD = "lastMood"

    /** Mood string (Dart OwlState.name) -> activity-alias short class name. */
    private val moodToAlias = mapOf(
        "idle" to "IconIdle",
        "worried" to "IconWorried",
        "angry" to "IconAngry",
        "cheer" to "IconCheer"
    )

    /**
     * Applies [mood]'s launcher icon by enabling its activity-alias and
     * disabling the other three. No-op for unrecognized mood strings.
     * Skips all PackageManager work if [mood] already matches the last
     * mood applied (switching aliases is a real, somewhat expensive system
     * operation that can briefly restart the launcher's view of the app on
     * some OEM launchers).
     */
    fun apply(context: Context, mood: String) {
        val targetAlias = moodToAlias[mood] ?: return

        val appContext = context.applicationContext
        val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getString(PREF_LAST_MOOD, null) == mood) {
            return
        }

        Thread {
            val packageManager = appContext.packageManager
            for (aliasName in moodToAlias.values) {
                val state = if (aliasName == targetAlias) {
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                } else {
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                }
                packageManager.setComponentEnabledSetting(
                    ComponentName(appContext, "app.owlnighter.$aliasName"),
                    state,
                    PackageManager.DONT_KILL_APP
                )
            }
            prefs.edit().putString(PREF_LAST_MOOD, mood).apply()
        }.start()
    }
}
