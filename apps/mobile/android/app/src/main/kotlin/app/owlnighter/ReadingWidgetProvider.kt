package app.owlnighter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Calendar

/**
 * Home-screen widget for owlnighter's nightly reading habit.
 *
 * The widget's look changes on two axes:
 *   1. Whether tonight's reading is already done (`hasReadToday`), and
 *   2. The time of day (morning/day, evening, late-night), computed here from
 *      the DEVICE clock so the bucket advances even when the app is closed, as
 *      long as Android calls [onUpdate] (see updatePeriodMillis in
 *      res/xml/reading_widget_info.xml — Android floors this near 30 min).
 *
 * State is read from the SharedPreferences file the Flutter `home_widget`
 * plugin writes to ("HomeWidgetPreferences"); the Dart side keeps it fresh via
 * HomeWidgetBridge.publish(...). All art is simple native vector drawables in
 * owlnighter's own brand palette — no Flutter, no third-party assets.
 */
class ReadingWidgetProvider : AppWidgetProvider() {

    /** Time-of-day buckets. Boundaries mirror `readingTimeBucketFor` in Dart. */
    private enum class TimeBucket { DAY, EVENING, NIGHT }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateOne(context, appWidgetManager, id)
        }
    }

    private fun updateOne(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        // Same prefs file the home_widget plugin saves into.
        val prefs = context.getSharedPreferences(
            "HomeWidgetPreferences",
            Context.MODE_PRIVATE
        )
        val hasReadToday = prefs.getBoolean("hasReadToday", false)
        // home_widget may store a Dart int as either Int or Long depending on
        // the platform channel codec — read defensively so we never crash.
        val streak = readInt(prefs, "currentStreak", 0)

        val views = RemoteViews(context.packageName, R.layout.widget_reading)

        val bucket = timeBucket()
        applyState(context, views, hasReadToday, bucket, streak)

        // Tapping anywhere opens the app (deep-link hint passed as an extra so
        // MainActivity/Flutter can route to the library or current plan).
        val launch = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("owlnighter.from_widget", true)
        }
        val pending = PendingIntent.getActivity(
            context,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pending)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    /** Choose background, accent glyph, and copy for the current state. */
    private fun applyState(
        context: Context,
        views: RemoteViews,
        hasReadToday: Boolean,
        bucket: TimeBucket,
        streak: Int
    ) {
        val bgRes: Int
        val accentRes: Int
        val title: String
        val subtitle: String

        if (hasReadToday) {
            bgRes = R.drawable.widget_bg_done
            accentRes = R.drawable.accent_check
            title = "Nicely done tonight"
            subtitle = if (streak > 0) {
                "$streak-day streak and counting."
            } else {
                "Reading complete for today."
            }
        } else {
            when (bucket) {
                TimeBucket.DAY -> {
                    bgRes = R.drawable.widget_bg_day
                    accentRes = R.drawable.accent_moon
                    title = "Tonight's reading is waiting"
                    subtitle = "Settle in whenever you're ready."
                }
                TimeBucket.EVENING -> {
                    bgRes = R.drawable.widget_bg_evening
                    accentRes = R.drawable.accent_moon
                    title = "Time to read"
                    subtitle = "A few pages before the night winds down."
                }
                TimeBucket.NIGHT -> {
                    bgRes = R.drawable.widget_bg_night
                    accentRes = R.drawable.accent_flame
                    title = if (streak > 0) {
                        "Don't lose your $streak-day streak"
                    } else {
                        "Keep tonight's promise"
                    }
                    subtitle = "Finish tonight's reading before midnight."
                }
            }
        }

        views.setInt(R.id.widget_root, "setBackgroundResource", bgRes)
        views.setImageViewResource(R.id.widget_accent, accentRes)
        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_subtitle, subtitle)
    }

    /** Wall-clock bucket from the device time. Mirrors the Dart helper. */
    private fun timeBucket(): TimeBucket {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return when {
            hour >= 21 || hour < 5 -> TimeBucket.NIGHT
            hour >= 17 -> TimeBucket.EVENING
            else -> TimeBucket.DAY
        }
    }

    /** SharedPreferences.getInt throws if the value was stored as a Long. */
    private fun readInt(
        prefs: android.content.SharedPreferences,
        key: String,
        default: Int
    ): Int = try {
        prefs.getInt(key, default)
    } catch (e: ClassCastException) {
        prefs.getLong(key, default.toLong()).toInt()
    }
}
