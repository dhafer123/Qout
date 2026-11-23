# R8 rules for release builds (picked up by Flutter's Gradle plugin).

# google_mlkit_text_recognition refers to the Chinese, Devanagari, Japanese
# and Korean recognizers, which ship as separate optional dependencies. Qout
# only reads Latin script (`TextRecognizer()` in lib/core/ocr/label_ocr.dart
# defaults to it), so those classes are absent on purpose and never called.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
