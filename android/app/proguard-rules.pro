# Flutter discovers the generated plugin registrant at runtime.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Preserve the Android activity and the novel protected-font decoder entry points.
-keep class com.mangaplus.app.MainActivity { *; }
-keep class com.mangaplus.app.Woff2Decoder { *; }
-keep class com.mangaplus.app.Woff2Decoder$* { *; }
-keep class com.mangaplus.app.MknovWoff2DecoderKt { *; }

# flutter_js invokes its QuickJS/JSC bridge through FFI and documents these
# keep rules for Android release builds with code/resource shrinking enabled.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class de.prosiebensat1digital.** { *; }
