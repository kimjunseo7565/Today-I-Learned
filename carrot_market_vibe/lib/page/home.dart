import 'package:carrot_market/repository/contents_repository.dart';
import 'package:carrot_market/repository/local_storage_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'detail.dart';
import 'package:carrot_market/utils/data_utils.dart';
import 'login.dart';
import 'add_product.dart';
import 'dart:convert';
import 'dart:typed_data';

class Home extends StatefulWidget {
  Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String? currentLocation;
  ContentsRepository? contentsRepository;
  late LocalStorageRepository _storageRepository;
  final Map<String, String> locationTypeToString = {
    "ara" : "아라동",
    "ora" : "오라동",
    "donam" : "도남동",
  };
  
  // Base64 디코딩 캐시 (성능 최적화)
  final Map<String, Uint8List> _imageCache = {};

  @override
  void initState() {
    super.initState();
    currentLocation = "ara";
    _storageRepository = LocalStorageRepository();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    contentsRepository = ContentsRepository();
  }

  AppBar _appbarWidget() {
    return AppBar(
      title: GestureDetector(
        onTap: () {
          print("click");
        },
        child: PopupMenuButton<String>(
          offset: Offset(0, 25),
          shape: ShapeBorder.lerp(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            1,
          ),
          onSelected: (String where){
            setState(() {
              currentLocation = where;
            });
          },
          itemBuilder: (BuildContext context) {
            return [
              PopupMenuItem(value: "ara", child: Text("아라동")),
              PopupMenuItem(value: "ora", child: Text("오라동")),
              PopupMenuItem(value: "donam", child: Text("도남동")),
            ];
          },
          child: Row(
            children: [
              Text(locationTypeToString[currentLocation]!),
              Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
      elevation: 1,
      actions: [
        IconButton(onPressed: () {}, icon: Icon(Icons.search)),
        IconButton(onPressed: () {}, icon: Icon(Icons.tune)),
        IconButton(
          onPressed: () {},
          icon: SvgPicture.asset(
            "assets/svg/bell.svg",
            width: 22,
          )
        ),
        IconButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
              return AddProductPage();
            }));
          },
          icon: Icon(Icons.add_circle_outline),
          tooltip: '상품 등록',
        ),
        _buildUserSection(),
      ],
    );
  }

  Widget _buildUserSection() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _storageRepository.getCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data != null) {
          // 로그인된 상태: 닉네임 표시
          String nickname = snapshot.data!['nickname'] ?? '사용자';
          return Padding(
            padding: EdgeInsets.only(right: 10),
            child: Center(
              child: Text(
                nickname,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          );
        } else {
          // 로그아웃된 상태: 로그인 버튼 표시
          return IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
                return LoginPage();
              }));
            },
            icon: Icon(Icons.person_outline),
            tooltip: '로그인',
          );
        }
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadContents() async {
    try {
      // 기본 상품 불러오기
      final String location = currentLocation ?? 'ara';
      List<Map<String, String>> defaultProducts = 
          await contentsRepository!.loadcontentsFromLocation(location);
      
      // 사용자 상품 불러오기
      List<Map<String, dynamic>> userProducts = 
          await _storageRepository.getAllUserProducts();
      
      // 선택된 위치 코드에 해당하는 한글 이름으로 변환
      String locationName = locationTypeToString[location] ?? '아라동';
      
      // 사용자 상품을 현재 위치로 필터링
      List<Map<String, dynamic>> filteredUserProducts = [];
      for (var product in userProducts) {
        try {
          String productLocation = product['location']?.toString() ?? '';
          // 위치명이 포함되어 있으면 (예: "제주 제주시 도남동" contains "도남동")
          if (productLocation.contains(locationName)) {
            filteredUserProducts.add(product);
          }
        } catch (e) {
          // 필터링 에러 무시
        }
      }
      
      // 두 목록 합치기
      List<Map<String, dynamic>> allProducts = [];
      
      // 기본 상품을 dynamic으로 변환
      for (var product in defaultProducts) {
        try {
          allProducts.add(Map<String, dynamic>.from(product));
        } catch (e) {
          // 변환 에러 무시
        }
      }
      
      // 필터링된 사용자 상품 추가
      allProducts.addAll(filteredUserProducts);
      
      return allProducts;
    } catch (e) {
      rethrow;
    }
  }

  Widget _buildImage(String imageUrl, double width, double height) {
    // Base64 이미지인지 확인 (Base64는 보통 매우 긴 문자열)
    if (imageUrl.length > 1000 && !imageUrl.startsWith('assets/')) {
      // Base64 이미지 처리 (캐시 사용)
      try {
        // 캐시에 없으면 디코딩 후 저장
        if (!_imageCache.containsKey(imageUrl)) {
          _imageCache[imageUrl] = Uint8List.fromList(base64Decode(imageUrl));
        }
        
        return Image.memory(
          _imageCache[imageUrl]!,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading Base64 image: $error');
            _imageCache.remove(imageUrl); // 캐시에서 제거
            return Image.asset(
              'assets/images/ara-1.jpg',
              width: width,
              height: height,
              fit: BoxFit.cover,
            );
          },
        );
      } catch (e) {
        print('Base64 decode error: $e');
        return Image.asset(
          'assets/images/ara-1.jpg',
          width: width,
          height: height,
          fit: BoxFit.cover,
        );
      }
    } else {
      // 일반 asset 이미지
      return Image.asset(
        imageUrl.isEmpty ? 'assets/images/ara-1.jpg' : imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    }
  }

  _makeDataList(List<Map<String, dynamic>> datas) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemBuilder: (BuildContext _context, int index) {
        var data = datas[index];
        
        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
              return DetailContentView(
                data: data,
              );
            }));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  child: Hero(
                    tag: data["cid"]?.toString() ?? "unknown",
                    child: _buildImage(data["image"]?.toString() ?? "assets/images/ara-1.jpg", 100, 100),
                  )
                ),
                Expanded(
                  child: Container(
                    height: 100,
                    padding: const EdgeInsets.only(left: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data["title"]?.toString() ?? "",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15)
                        ),
                        SizedBox(height: 5),
                        Text(
                          data["location"]?.toString() ?? "",
                          style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.3)),
                        ),
                        SizedBox(height: 5),
                        Text(
                          DataUtils.calcStringToWon(data["price"]?.toString() ?? "0"),
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SvgPicture.asset(
                                "assets/svg/heart_off.svg",
                                width: 13,
                                height: 13,
                              ),
                              SizedBox(width: 5),
                              Text(data["likes"]?.toString() ?? "0"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
      itemCount: datas.length,
      separatorBuilder: (BuildContext _context, int index) {
        return Container(height: 1, color: Colors.black.withOpacity(0.4));
      },
    );
  }

  Widget _bodyWidget() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadContents(),
      builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot){
        if(snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator());
        }
          
        if (snapshot.hasError) {
          print('DEBUG: FutureBuilder Error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("데이터 오류"),
                SizedBox(height: 10),
                Text(
                  "${snapshot.error}",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          return _makeDataList(snapshot.data!);
        }
        
        return Center(child: Text("해당 지역에 데이터가 없습니다."));
      }
    );
    
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appbarWidget(),
      body: _bodyWidget(),
    );
  }
}

