# OkHttp3 est référencé optionnellement par uCrop (téléchargement d'images distantes).
# Cette fonctionnalité n'est pas utilisée dans l'app, on supprime les avertissements R8.
-dontwarn okhttp3.Call
-dontwarn okhttp3.Dispatcher
-dontwarn okhttp3.OkHttpClient
-dontwarn okhttp3.Request$Builder
-dontwarn okhttp3.Request
-dontwarn okhttp3.Response
-dontwarn okhttp3.ResponseBody

# PyTorch Lite Android — classes chargées par réflexion et JNI.
# R8 les supprimerait sinon, causant ClassNotFoundException au runtime.
-keep class org.pytorch.** { *; }
-keep class com.facebook.jni.** { *; }
-keep class com.facebook.soloader.** { *; }
-dontwarn org.pytorch.**
-dontwarn com.facebook.jni.**
-dontwarn com.facebook.soloader.**
