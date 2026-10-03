package com.example.findipro

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class FindiProAppWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.findipro_appwidget_layout)

        // Intent to launch the main app on header/root click
        val mainIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val mainPendingIntent = PendingIntent.getActivity(
            context,
            0,
            mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_header, mainPendingIntent)

        // Intent to launch search on search bar click
        val searchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", "/explore")
            putExtra("action", "search")
        }
        val searchPendingIntent = PendingIntent.getActivity(
            context,
            1,
            searchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_search_btn, searchPendingIntent)

        // Quick Category Action: Plumbing
        val plumbingIntent = createCategoryIntent(context, "Plumbing", 2)
        views.setOnClickPendingIntent(R.id.widget_cat_plumbing, plumbingIntent)

        // Quick Category Action: Electrical
        val electricalIntent = createCategoryIntent(context, "Electrical", 3)
        views.setOnClickPendingIntent(R.id.widget_cat_electrical, electricalIntent)

        // Quick Category Action: Cleaning
        val cleaningIntent = createCategoryIntent(context, "Cleaning", 4)
        views.setOnClickPendingIntent(R.id.widget_cat_cleaning, cleaningIntent)

        // Quick Category Action: Mechanic
        val mechanicIntent = createCategoryIntent(context, "Mechanic", 5)
        views.setOnClickPendingIntent(R.id.widget_cat_mechanic, mechanicIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun createCategoryIntent(context: Context, category: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", "/category")
            putExtra("category", category)
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}

