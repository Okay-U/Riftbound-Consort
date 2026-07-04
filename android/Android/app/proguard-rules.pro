-keeppackagenames **
-keep class skip.** { *; }
-keep class tools.skip.** { *; }
-keep class kotlin.jvm.functions.** {*;}
-keep class com.sun.jna.** { *; }
-dontwarn java.awt.**
-keep class * implements com.sun.jna.** { *; }
-keep class * implements skip.bridge.** { *; }
-keep class **._ModuleBundleAccessor_* { *; }
-keep class riftcount.module.** { *; }

# Tink (via androidx.security:security-crypto, used by SkipKeychain) references
# compile-time-only errorprone annotations absent from the runtime classpath.
# Safe to ignore during R8 shrinking of the release build.
-dontwarn com.google.errorprone.annotations.**
