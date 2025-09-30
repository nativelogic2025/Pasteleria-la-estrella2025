// lib/product_notifier.dart

import 'package:flutter/material.dart';

// Un simple notificador que avisará cuando los productos cambien.
class ProductNotifier extends ChangeNotifier {
  void productsHaveChanged() {
    // Avisa a todos los que estén escuchando.
    notifyListeners();
  }
}