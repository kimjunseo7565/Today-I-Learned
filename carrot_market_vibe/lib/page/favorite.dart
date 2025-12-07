import 'package:carrot_market/page/detail.dart';
import 'package:carrot_market/repository/local_storage_repository.dart';
import 'package:flutter/material.dart';
import 'package:carrot_market/utils/data_utils.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'dart:typed_data';

class MyFavoriteContents extends StatefulWidget {
  MyFavoriteContents({Key? key}) : super(key: key);

  @override
  _MyFavoriteContentsState createState() => _MyFavoriteContentsState();
}

class _MyFavoriteContentsState extends State<MyFavoriteContents> {
  late LocalStorageRepository _storageRepository;
  
  // Base64 디코딩 캐시 (성능 최적화)
  final Map<String, Uint8List> _imageCache = {};
  
  @override
  void initState() {
    super.initState();
    _storageRepository = LocalStorageRepository();
  }

  AppBar _appbarWidget() {
    return AppBar(
      title: Text(
        "관심목록",
        style: TextStyle(fontSize: 15),
      ),
    );
  }

  Widget _makeDataList(List<dynamic> datas) {
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
                  ),
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
                          style: TextStyle(fontSize: 15),
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
                ),
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

  Widget _bodyWidget() {
    return FutureBuilder(
      future: _loadMyFavoriteContentsList(),
      builder: (BuildContext context, dynamic snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("데이터 오류"));
        }
        
        if (snapshot.hasData) {
          return _makeDataList(snapshot.data);
        }
        
        return Center(child: Text("관심목록이 없습니다."));
      },
    );
  }

  Future<List<dynamic>> _loadMyFavoriteContentsList() async {
    return await _storageRepository.getFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appbarWidget(),
      body: _bodyWidget(),
    );
  }
}