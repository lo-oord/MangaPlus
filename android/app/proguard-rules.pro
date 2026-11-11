# Flutter discovers the generated plugin registrant at runtime.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Preserve the Android activity and the novel protected-font decoder entry points.
-keep class com.mangaplus.app.MainActivity { *; }
-keep class com.mangaplus.app.Woff2Decoder { *; }
-keep class com.mangaplus.app.Woff2Decoder$* { *; }
-keep class com.mangaplus.app.MknovWoff2DecoderKt { *; }
