# proguard
# TensorFlow Lite Wrapper
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }

# Ignorar advertencias de clases faltantes de GPU si no se usan explícitamente
-dontwarn org.tensorflow.lite.**
-dontwarn java.lang.invoke.*
