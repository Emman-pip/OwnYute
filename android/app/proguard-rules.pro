# Flutter enables R8 code shrinking and obfuscation for release builds.
# The bundled youtubedl-android tool library and its
# org.apache.commons.compress.archivers.zip dependency are loaded through
# reflection when yt-dlp and FFmpeg unpack their bundled packages. R8 cannot
# see those reflective references, so it strips the classes (for example
# AsiExtraField) and the release app crashes on the first tool use with
# "class ... is not a concrete class" / ExceptionInInitializerError.
#
# Keep both packages intact. These rules mirror the ones the upstream
# youtubedl-android library is meant to publish as consumer rules.
-keep class com.yausername.** { *; }
-keep class org.apache.commons.compress.archivers.zip.** { *; }
