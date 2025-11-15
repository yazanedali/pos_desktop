import 'package:flutter/material.dart';

class TopAlert {
  static void show({
    required BuildContext context,
    required String message,
    bool isError = false,
    bool isWarning = false,
    int durationSeconds = 2,
    double widthPercentage = 0.4,
  }) {
    // إنشاء OverlayEntry
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            top: 50, // المسافة من الأعلى
            left:
                MediaQuery.of(context).size.width * ((1 - widthPercentage) / 2),
            right:
                MediaQuery.of(context).size.width * ((1 - widthPercentage) / 2),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      isError
                          ? (isWarning ? Colors.orange : Colors.red)
                          : Colors.green,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () {
                        overlayEntry?.remove();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    // إضافة الـ Overlay
    Overlay.of(context).insert(overlayEntry);

    // إزالة التلقائية بعد مدة قصيرة
    Future.delayed(Duration(seconds: durationSeconds), () {
      if (overlayEntry?.mounted == true) {
        overlayEntry?.remove();
      }
    });
  }

  // دالة مساعدة للرسائل الناجحة
  static void showSuccess({
    required BuildContext context,
    required String message,
    int durationSeconds = 2,
  }) {
    show(
      context: context,
      message: message,
      isError: false,
      durationSeconds: durationSeconds,
      isWarning: false,
    );
  }

  static void showWarning({
    required BuildContext context,
    required String message,
    int durationSeconds = 3, // مدة أطول قليلاً للرسائل المهمة
  }) {
    show(
      context: context,
      message: message,
      isError: true,
      durationSeconds: durationSeconds,
      isWarning: true,
    );
  }

  // دالة مساعدة للرسائل الخطأ
  static void showError({
    required BuildContext context,
    required String message,
    int durationSeconds = 3, // مدة أطول قليلاً للرسائل المهمة
  }) {
    show(
      context: context,
      message: message,
      isError: true,
      durationSeconds: durationSeconds,
      isWarning: false,
    );
  }
}
