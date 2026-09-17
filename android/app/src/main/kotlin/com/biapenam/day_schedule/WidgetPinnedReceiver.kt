package com.biapenam.day_schedule

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast

class WidgetPinnedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.i("DayScheduleWidget", "Widget pin callback received")
        Toast.makeText(
            context,
            context.getString(R.string.widget_pin_added),
            Toast.LENGTH_SHORT
        ).show()
    }
}
