# GPay (NBU Paisa API) & Razorpay ProGuard / R8 Rules
-dontwarn com.google.android.apps.nbu.paisa.inapp.client.api.**
-keep class com.google.android.apps.nbu.paisa.inapp.client.api.** { *; }

-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
