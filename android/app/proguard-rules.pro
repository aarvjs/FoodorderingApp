# PayU & GPay (NBU Paisa API) ProGuard / R8 Rules
-dontwarn com.google.android.apps.nbu.paisa.inapp.client.api.**
-dontwarn com.payu.**

-keep class com.payu.** { *; }
-keep class com.google.android.apps.nbu.paisa.inapp.client.api.** { *; }
