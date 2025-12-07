import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FavoriteProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  final Map<String, String> _favoriteItems = {};

  Set<String> get favoriteItemIds => _favoriteItems.keys.toSet();

  Map<String, String> get favoriteItemsMap => _favoriteItems;

  Future<void> loadFavorites() async {
    if (_userId == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('favorites')
          .get();

      _favoriteItems.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _favoriteItems[doc.id] = data['restaurantId'] ?? '';
      }
      notifyListeners();
    } catch (e) {
      print('Lỗi khi tải favorites: $e');
    }
  }

  bool isFavorite(String menuItemId) {
    return _favoriteItems.containsKey(menuItemId);
  }

  Future<void> toggleFavorite(String menuItemId, String restaurantId) async {
    if (_userId == null) return;
    final favoriteRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('favorites')
        .doc(menuItemId);

    if (isFavorite(menuItemId)) {
      // Xóa khỏi favorites
      await favoriteRef.delete();
      _favoriteItems.remove(menuItemId);
    } else {
      await favoriteRef.set({
        'menuItemId': menuItemId,
        'restaurantId': restaurantId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _favoriteItems[menuItemId] = restaurantId;
    }

    notifyListeners();
  }
}