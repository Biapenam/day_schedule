package com.biapenam.day_schedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import org.json.JSONArray
import java.util.Calendar

class ScheduleWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == Intent.ACTION_DATE_CHANGED ||
            intent.action == Intent.ACTION_TIMEZONE_CHANGED
        ) {
            val manager = AppWidgetManager.getInstance(context)
            val provider = ComponentName(context, ScheduleWidgetProvider::class.java)
            manager.getAppWidgetIds(provider).forEach { id ->
                updateAppWidget(context, manager, id)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private const val TAG = "DayScheduleWidget"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.schedule_widget_layout)
            val launchIntent =
                context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            // 日期显示
            val cal = Calendar.getInstance()
            val todayJavaWeekday = cal.get(Calendar.DAY_OF_WEEK)
            val flutterWeekday = when (todayJavaWeekday) {
                Calendar.MONDAY -> 1
                Calendar.TUESDAY -> 2
                Calendar.WEDNESDAY -> 3
                Calendar.THURSDAY -> 4
                Calendar.FRIDAY -> 5
                Calendar.SATURDAY -> 6
                Calendar.SUNDAY -> 7
                else -> 1
            }
            val month = cal.get(Calendar.MONTH) + 1
            val day = cal.get(Calendar.DAY_OF_MONTH)
            val weekNames =
                arrayOf("", "周一", "周二", "周三", "周四", "周五", "周六", "周日")
            views.setTextViewText(
                R.id.widget_date,
                "${month}月${day}日 · ${weekNames[flutterWeekday]}"
            )

            // 课程数据由 Dart 侧 WidgetService 计算好当天课程后写入：
            // HomeWidget.saveWidgetData('today_courses', json)
            // 键值原样存储在 HomeWidgetPreferences 中，这里只负责解析渲染。
            val prefs: SharedPreferences = context.getSharedPreferences(
                "HomeWidgetPreferences",
                Context.MODE_PRIVATE
            )
            val json = prefs.getString("today_courses", "[]") ?: "[]"
            val courses = mutableListOf<Pair<String, String>>()
            try {
                val arr = JSONArray(json)
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    val name = obj.optString("name", "")
                    val time = obj.optString("time", "")
                    val location = obj.optString("location", "")
                    val detail = buildString {
                        if (time.isNotEmpty()) append(time)
                        if (location.isNotEmpty()) {
                            if (isNotEmpty()) append("  ")
                            append(location)
                        }
                    }
                    if (name.isNotEmpty()) courses.add(name to detail)
                }
            } catch (e: Exception) {
                Log.w(TAG, "解析 today_courses 失败，显示空状态", e)
            }

            // 填充最多 3 条
            val slots = listOf(
                R.id.widget_course_1,
                R.id.widget_course_2,
                R.id.widget_course_3
            )
            val showCount = minOf(courses.size, 3)
            for (i in slots.indices) {
                if (i < showCount) {
                    val (name, detail) = courses[i]
                    val line =
                        if (detail.isNotEmpty()) "● $name   $detail" else "● $name"
                    views.setTextViewText(slots[i], line)
                } else {
                    views.setTextViewText(slots[i], "")
                }
            }

            when {
                courses.isEmpty() -> {
                    views.setTextViewText(
                        R.id.widget_course_1,
                        context.getString(R.string.widget_no_courses)
                    )
                    views.setTextViewText(R.id.widget_more, "")
                }
                courses.size > 3 ->
                    views.setTextViewText(
                        R.id.widget_more,
                        context.getString(R.string.widget_more_courses, courses.size - 3)
                    )
                else ->
                    views.setTextViewText(
                        R.id.widget_more,
                        context.getString(R.string.widget_course_count, courses.size)
                    )
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
