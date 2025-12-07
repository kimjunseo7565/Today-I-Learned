import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalStorageRepository {
  static const String _favoriteKey = 'favorite_products';
  static const String _currentUserKey = 'current_user';
  static const String _usersKey = 'users_data';
  static const String _userProductsKey = 'user_products_';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// 회원가입
  Future<bool> registerUser(String email, String password, String nickname) async {
    try {
      // 기존 사용자 확인
      List<Map<String, dynamic>> users = await _getAllUsers();
      bool userExists = users.any((user) => user['email'] == email);
      
      if (userExists) {
        return false; // 이미 존재하는 이메일
      }

      // 새 사용자 추가
      Map<String, dynamic> newUser = {
        'email': email,
        'password': password,
        'nickname': nickname,
        'manorTemp': 36.5,
      };
      
      users.add(newUser);
      
      // 저장
      String jsonString = jsonEncode(users);
      await _storage.write(key: _usersKey, value: jsonString);
      
      return true;
    } catch (e) {
      print('Error registering user: $e');
      return false;
    }
  }

  /// 로그인
  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    try {
      List<Map<String, dynamic>> users = await _getAllUsers();
      
      for (var user in users) {
        if (user['email'] == email && user['password'] == password) {
          // 현재 사용자 저장
          await _storage.write(key: _currentUserKey, value: jsonEncode(user));
          return user;
        }
      }
      
      return null; // 로그인 실패
    } catch (e) {
      print('Error logging in user: $e');
      return null;
    }
  }

  /// 현재 로그인된 사용자 조회
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      String? jsonString = await _storage.read(key: _currentUserKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }
      
      return jsonDecode(jsonString);
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  /// 로그아웃
  Future<void> logoutUser() async {
    try {
      await _storage.delete(key: _currentUserKey);
    } catch (e) {
      print('Error logging out: $e');
    }
  }

  /// 모든 사용자 조회 (내부 사용)
  Future<List<Map<String, dynamic>>> _getAllUsers() async {
    try {
      String? jsonString = await _storage.read(key: _usersKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  /// 사용자 상품 저장
  Future<void> addUserProduct(String userEmail, Map<String, dynamic> product) async {
    try {
      String key = _userProductsKey + userEmail;
      List<Map<String, dynamic>> userProducts = await getUserProducts(userEmail);
      
      userProducts.add(product);
      
      String jsonString = jsonEncode(userProducts);
      await _storage.write(key: key, value: jsonString);
    } catch (e) {
      print('Error adding user product: $e');
    }
  }

  /// 사용자의 상품 목록 조회
  Future<List<Map<String, dynamic>>> getUserProducts(String userEmail) async {
    try {
      String key = _userProductsKey + userEmail;
      String? jsonString = await _storage.read(key: key);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting user products: $e');
      return [];
    }
  }

  /// 모든 사용자의 상품 조회
  Future<List<Map<String, dynamic>>> getAllUserProducts() async {
    try {
      List<Map<String, dynamic>> allProducts = [];
      List<Map<String, dynamic>> users = await _getAllUsers();
      
      for (var user in users) {
        List<Map<String, dynamic>> userProducts = 
            await getUserProducts(user['email']);
        allProducts.addAll(userProducts);
      }
      
      return allProducts;
    } catch (e) {
      print('Error getting all user products: $e');
      return [];
    }
  }

  /// 관심 목록에 상품 추가
  Future<void> addFavorite(Map<String, dynamic> product) async {
    try {
      // 기존 관심 목록 불러오기
      List<Map<String, dynamic>> favorites = await getFavorites();
      
      // 중복 확인
      bool isDuplicate = favorites.any((item) => item['cid'] == product['cid']);
      if (isDuplicate) {
        return;
      }
      
      // 새 상품 추가
      favorites.add(product);
      
      // 저장
      String jsonString = jsonEncode(favorites);
      await _storage.write(key: _favoriteKey, value: jsonString);
    } catch (e) {
      print('Error adding favorite: $e');
    }
  }

  /// 관심 목록에서 상품 제거
  Future<void> removeFavorite(String productId) async {
    try {
      // 기존 관심 목록 불러오기
      List<Map<String, dynamic>> favorites = await getFavorites();
      
      // 해당 상품 제거
      favorites.removeWhere((item) => item['cid'] == productId);
      
      // 저장
      String jsonString = jsonEncode(favorites);
      await _storage.write(key: _favoriteKey, value: jsonString);
    } catch (e) {
      print('Error removing favorite: $e');
    }
  }

  /// 모든 관심 목록 조회
  Future<List<Map<String, dynamic>>> getFavorites() async {
    try {
      String? jsonString = await _storage.read(key: _favoriteKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting favorites: $e');
      return [];
    }
  }

  /// 특정 상품이 관심 목록에 있는지 확인
  Future<bool> isFavorite(String productId) async {
    try {
      List<Map<String, dynamic>> favorites = await getFavorites();
      return favorites.any((item) => item['cid'] == productId);
    } catch (e) {
      print('Error checking favorite: $e');
      return false;
    }
  }

  /// 관심 목록 초기화
  Future<void> clearFavorites() async {
    try {
      await _storage.delete(key: _favoriteKey);
    } catch (e) {
      print('Error clearing favorites: $e');
    }
  }
}
