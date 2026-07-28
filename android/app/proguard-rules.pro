# ML Kit and Play Services do reflection-based class loading internally;
# without these keep rules, R8 can strip classes they need at runtime.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# sqflite's SQL type coercion uses reflection on model classes it's given.
-keep class com.tekartik.sqflite.** { *; }
