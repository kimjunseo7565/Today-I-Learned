import 'package:carrot_market/components/manor_temperature_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:carrot_market/utils/data_utils.dart';
import 'package:carrot_market/repository/local_storage_repository.dart';
import 'dart:convert';
import 'dart:typed_data';

class DetailContentView extends StatefulWidget {
  final Map<String, dynamic>? data;
  DetailContentView({Key? key, this.data}) : super(key: key);

  @override
  _DetailContentViewState createState() => _DetailContentViewState();
}

class _DetailContentViewState extends State<DetailContentView>
    with SingleTickerProviderStateMixin {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _storageRepository = LocalStorageRepository();
  Size? size;
  List<Map<String, String>> imgList = [];
  late ValueNotifier<int> _current; // setState 없이 값 변경
  double scrollpositionToAlpha = 0;
  ScrollController _controller = ScrollController();
  AnimationController? _animationController;
  Animation? _colorTween;
  bool? isMyFavoriteContent;
  
  // Base64 디코딩 캐시 (스크롤 성능 최적화)
  Uint8List? _decodedImageCache;
  String? _cachedImageUrl;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _current = ValueNotifier<int>(0); // ValueNotifier 초기화
    _pageController = PageController();
    isMyFavoriteContent = false;
    _checkFavoriteStatus();
    _animationController = AnimationController(vsync: this);
    _colorTween = ColorTween(begin: Colors.white, end: Colors.black)
        .animate(_animationController!);
    // 스크롤 리스너 - setState 없이 값만 업데이트 (성능 최적화)
    _controller.addListener(() {
      if(_controller.offset > 255) {
        scrollpositionToAlpha = 255;
      } else {
        scrollpositionToAlpha = _controller.offset;
      }
      _animationController!.value = scrollpositionToAlpha / 255;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController?.dispose();
    _current.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// 현재 상품이 관심 목록에 있는지 확인
  Future<void> _checkFavoriteStatus() async {
    bool isFavorite = await _storageRepository.isFavorite(widget.data!['cid']);
    setState(() {
      isMyFavoriteContent = isFavorite;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    size = MediaQuery.of(context).size;
    _current.value = 0;
    
    List<String> imageUrls = [];
    
    try {
      if (widget.data == null) {
        imageUrls = ['assets/images/ara-1.jpg'];
      } else {
        final hasImages = widget.data?.containsKey("images") ?? false;
        
        if (hasImages) {
          final imagesField = widget.data!["images"];
          if (imagesField is List) {
            imageUrls = List<String>.from(imagesField);
          } else {
            imageUrls = ['assets/images/ara-1.jpg'];
          }
        } else {
          final imageField = widget.data!["image"];
          if (imageField != null) {
            imageUrls = [imageField.toString()];
          } else {
            imageUrls = ['assets/images/ara-1.jpg'];
          }
        }
      }
    } catch (e) {
      imageUrls = ['assets/images/ara-1.jpg'];
    }
    
    imgList = imageUrls.asMap().entries.map((entry) {
      return { "id": entry.key.toString(), "url": entry.value };
    }).toList();
  }

  Widget _makeIcon(IconData icon) {
    return AnimatedBuilder(
      animation: _colorTween!,
      builder:(context,child) =>
        Icon(icon, color: _colorTween!.value)
    );
  }

  Widget _buildCarouselImage(String imageUrl) {
    // Base64 이미지인지 확인 (Base64는 보통 매우 긴 문자열)
    if (imageUrl.length > 1000 && !imageUrl.startsWith('assets/')) {
      // Base64 이미지 처리 (캐시 사용)
      try {
        // 캐시 확인 - 같은 이미지면 디코딩된 바이트 재사용
        if (_cachedImageUrl != imageUrl) {
          _decodedImageCache = Uint8List.fromList(base64Decode(imageUrl));
          _cachedImageUrl = imageUrl;
        }
        
        return Image.memory(
          _decodedImageCache!,
          width: size!.width,
          fit: BoxFit.fill,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading Base64 image in detail: $error');
            return Image.asset(
              'assets/images/ara-1.jpg',
              width: size!.width,
              fit: BoxFit.fill,
            );
          },
        );
      } catch (e) {
        print('Base64 decode error in detail: $e');
        print('Image URL that failed: $imageUrl');
        return Image.asset(
          'assets/images/ara-1.jpg',
          width: size!.width,
          fit: BoxFit.fill,
        );
      }
    } else {
      // 일반 asset 이미지
      return Image.asset(
        imageUrl.isEmpty ? 'assets/images/ara-1.jpg' : imageUrl,
        width: size!.width,
        fit: BoxFit.fill,
      );
    }
  }

  Widget _makeSliderImage() {
    // imgList가 비어있으면 기본 이미지만 표시
    if (imgList.isEmpty) {
      return RepaintBoundary(
        child: Container(
          color: Colors.black,
          width: size!.width,
          height: size!.width,
          child: _buildCarouselImage('assets/images/ara-1.jpg'),
        ),
      );
    }

    return RepaintBoundary(
      child: Container(
        color: Colors.black,
        width: size!.width,
        height: size!.width,
        child: Stack(
          children: [
            Hero(
              tag: widget.data!["cid"],
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  // 마우스 드래그로 이미지 이동
                  _pageController.position.moveTo(
                    _pageController.offset - details.delta.dx
                  );
                },
                onHorizontalDragEnd: (details) {
                  // 드래그 끝났을 때 페이지 스냅
                  double velocity = details.velocity.pixelsPerSecond.dx;
                  if (velocity.abs() > 100) {
                    _pageController.animateToPage(
                      velocity > 0 
                        ? (_pageController.page?.toInt() ?? 0) - 1
                        : (_pageController.page?.toInt() ?? 0) + 1,
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  } else {
                    _pageController.animateToPage(
                      (_pageController.page?.round() ?? 0),
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: PageView.builder(
                  controller: _pageController,
                  physics: NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    _current.value = index;
                  },
                  itemCount: imgList.length,
                  itemBuilder: (context, index) {
                    String imageUrl = imgList[index]["url"]?.toString() ?? 'assets/images/ara-1.jpg';
                    return Container(
                      width: size!.width,
                      height: size!.width,
                      color: Colors.black,
                      child: _buildCarouselImage(imageUrl),
                    );
                  },
                ),
              ),
            ),
            if (imgList.length > 1)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<int>(
                  valueListenable: _current,
                  builder: (context, currentIndex, child) {
                    return Container(
                      color: Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(imgList.length, (index) {
                          return Container(
                            width: 10.0,
                            height: 10.0,
                            margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 5.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: currentIndex == index
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.4),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _sellerSimpleInfo() {
    // 판매자 닉네임과 매너온도 가져오기
    String sellerNickname = widget.data?['sellerNickname']?.toString() ?? '개발하는남자';
    double manorTemp = 37.5;
    if (widget.data?.containsKey('manorTemp') ?? false) {
      try {
        manorTemp = double.parse(widget.data!['manorTemp'].toString());
      } catch (e) {
        manorTemp = 37.5;
      }
    }
    
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundImage: Image.asset("assets/images/user.png").image,
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sellerNickname,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16
                )
              ),
              Text(
                widget.data?['location'] ?? "제주시 도담동",
              )
            ],
          ),
          Expanded(child: ManorTemperature(manorTemp: manorTemp)),
        ],
      ),
    );
  }

  Widget _line() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      height: 1,
      color: Colors.grey.withOpacity(0.3),
    );
  }

  Widget _contentDetail() {
    String description = widget.data?['description'] ?? "상품 설명이 없습니다.";
    String category = widget.data?['category'] ?? "기타";
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:[
          SizedBox(height: 20),
          Text(
            widget.data!["title"],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          Text(
            "$category ∙ 22시간 전",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 15),
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
            ),
          ),
          SizedBox(height: 15),
          Text(
            "채팅 3 ∙ 관심 ${widget.data?['likes'] ?? '0'} ∙ 조회 295",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 15),
        ]
      )
    );
  }

  Widget _otherCellContents() {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "판매자님의 판매 상품",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "모두보기",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          )
        ],
      ),
    );
  }

  Widget _bodyWidget() {
    return CustomScrollView(
      controller: _controller,
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            [
              _makeSliderImage(),
              _sellerSimpleInfo(),
              _line(),
              _contentDetail(),
              _line(),
              _otherCellContents(),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          sliver: SliverGrid(
            gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Container(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          color: Colors.grey,
                          height: 120,
                        ),
                      ),
                      Text("상품 제목", style: TextStyle(fontSize: 14),),
                      Text("금액",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
              childCount: 20,
            ),
          )
        )
      ]
    );
  }

  Widget _bottomBarWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      width: size!.width,
      height: 55,
      child: Row(children: [
        GestureDetector(
          onTap: () async {
            try {
              // 상태 토글
              bool newFavoriteState = !isMyFavoriteContent!;
              
              // 로컬 스토리지에 저장/제거
              if (newFavoriteState) {
                await _storageRepository.addFavorite(widget.data!);
              } else {
                await _storageRepository.removeFavorite(widget.data!['cid']);
              }
              
              // 완료 후 UI 업데이트
              setState(() {
                isMyFavoriteContent = newFavoriteState;
              });
              
              // 스낵바 표시
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: Duration(milliseconds: 1000),
                    content: Text(
                      newFavoriteState
                        ? "관심 목록에 추가됐습니다."
                        : "관심 목록에 제거됐습니다",
                    ),
                  ),
                );
              }
            } catch (e) {
              print('Error toggling favorite: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: Duration(milliseconds: 1000),
                    content: Text("오류가 발생했습니다"),
                  ),
                );
              }
            }
          },
          child: SvgPicture.asset(
            isMyFavoriteContent! 
              ? "assets/svg/heart_on.svg"
              : "assets/svg/heart_off.svg",
            width: 25,
            height: 25,
            color: Color(0xfff08f4f),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 15, right: 10),
          width: 1,
          height: 40,
          color: Colors.grey.withOpacity(0.3),
        ),
        Column(
          children: [
            Text(
              DataUtils.calcStringToWon(widget.data!["price"]),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.data!["isNegotiable"] == false)
              Text("가격제안불가", style: TextStyle(fontSize: 14, color: Colors.grey))
          ],
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: Color(0xfff08f4f),
                ),
                child: Text("채팅으로 거래하기",
                  style:TextStyle(
                    color:Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold))
              ),
            ],
          ),
        ),
      ],)
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController!,
      builder: (context, child) {
        return Scaffold(
          key: scaffoldKey,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.white.withAlpha(scrollpositionToAlpha.toInt()),
            elevation: 0,
            actions: [
              IconButton(
                onPressed: () {}, icon: _makeIcon(Icons.share)),
              IconButton(
                onPressed: () {}, icon: _makeIcon(Icons.more_vert)),
            ],
          ),
          body: _bodyWidget(),
          bottomNavigationBar: _bottomBarWidget(),
        );
      },
    );
  }
}