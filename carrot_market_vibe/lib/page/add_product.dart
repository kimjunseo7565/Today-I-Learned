import 'package:flutter/material.dart';
import 'package:carrot_market/repository/local_storage_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'login.dart';

class AddProductPage extends StatefulWidget {
  AddProductPage({Key? key}) : super(key: key);

  @override
  _AddProductPageState createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _storageRepository = LocalStorageRepository();
  String? _selectedCategory;
  String? _selectedLocation; // 거래 희망 장소
  bool _isNegotiable = false;
  List<String> _selectedImages = []; // 여러 이미지 저장 (Base64)
  bool _isSelling = true; // true: 판매하기, false: 나눔하기
  bool _showMaxImagesMessage = false; // 최대 이미지 도달 메시지

  final List<String> _categories = [
    '디지털기기',
    '생활가전',
    '가구/인테리어',
    '의류',
    '식품',
    '기타'
  ];

  final List<String> _locations = [
    '아라동',
    '오라동',
    '도남동'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleAddProduct() async {
    Map<String, dynamic>? currentUser = await _storageRepository.getCurrentUser();
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상품 등록을 위해 로그인이 필요합니다.')),
      );
      Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
        return LoginPage();
      }));
      return;
    }

    String title = _titleController.text.trim();
    String description = _descriptionController.text.trim();
    String location = _selectedLocation ?? '';

    // 나눔하기인 경우 가격 검증 스킵, 판매하기인 경우만 가격 검증
    String price;
    if (_isSelling) {
      price = _priceController.text.trim();
      if (price.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('가격을 입력해주세요.')),
        );
        return;
      }
      if (int.tryParse(price) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('올바른 가격을 입력해주세요.')),
        );
        return;
      }
    } else {
      price = '무료나눔'; // 나눔하기 선택 시 "무료나눔" 저장
    }

    if (title.isEmpty || description.isEmpty || location.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('모든 필드를 입력해주세요.')),
      );
      return;
    }

    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    // 모든 선택된 이미지를 저장 (없으면 기본 이미지 리스트)
    List<String> imageDataList = _selectedImages.isNotEmpty 
        ? _selectedImages 
        : ['assets/images/ara-1.jpg'];
    
    Map<String, dynamic> newProduct = {
      'cid': 'user_${timestamp}',
      'title': title,
      'price': price,
      'description': description,
      'location': location,
      'category': _selectedCategory,
      'isNegotiable': _isSelling ? _isNegotiable : false, // 나눔하기는 협상 불가
      'image': imageDataList[0], // 대표 사진 (첫 번째 이미지)
      'images': imageDataList, // 모든 이미지 리스트
      'likes': '0',
      'sellerEmail': currentUser['email'],
      'sellerNickname': currentUser['nickname'],
      'manorTemp': currentUser['manorTemp'] ?? 36.5,
    };

    await _storageRepository.addUserProduct(currentUser['email'], newProduct);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('상품이 등록되었습니다.')),
    );

    Navigator.of(context).pop();
  }

  void _pickImage() async {
    if (_selectedImages.length >= 5) {
      setState(() {
        _showMaxImagesMessage = true;
      });
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showMaxImagesMessage = false;
          });
        }
      });
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        List<int> imageBytes;
        
        if (result.files.single.bytes != null) {
          imageBytes = result.files.single.bytes!;
        } else {
          File imageFile = File(result.files.single.path!);
          imageBytes = await imageFile.readAsBytes();
        }
        
        String base64String = base64Encode(imageBytes);
        
        setState(() {
          _selectedImages.add(base64String);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지가 선택되었습니다')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지를 선택할 수 없습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('내 물건 팔기'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {},
            child: Text('임시저장', style: TextStyle(color: Colors.grey)),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 이미지 선택 영역
            _buildImageSection(),
            Divider(height: 1),
            
            // 제목 입력
            _buildSectionTitle('제목'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: '제목을 입력해주세요.',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            Divider(height: 1),

            // 자세한 설명
            _buildSectionTitle('자세한 설명'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText: '덕풍1동에 올림 게시글 내용을 작성해 주세요.\n(판매 금지 물품은 게시가 제한될 수 있어요.)\n\n신뢰할 수 있는 거래를 위해 자세히 적어주세요.\n과학기술정보통신부, 한국 인터넷진흥원과 함께해요.',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                    maxLines: 8,
                  ),
                ),
              ),
            ),
            Divider(height: 1),

            // 자주 쓰는 문구
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              child: Text(
                '자주 쓰는 문구',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),

            // 카테고리
            _buildSectionTitle('카테고리'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: _buildCategoryDropdown(),
            ),
            Divider(height: 1),

            // 가격 섹션
            _buildSectionTitle('가격'),
            
            // 판매하기 / 나눔하기 버튼
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isSelling = true;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isSelling ? Colors.grey[300] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isSelling ? Colors.grey[400]! : Colors.grey[300]!,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '판매하기',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _isSelling ? Colors.black : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isSelling = false;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isSelling ? Color(0xFF333333) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: !_isSelling ? Color(0xFF333333) : Colors.grey[300]!,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '나눔하기',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: !_isSelling ? Colors.white : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 가격 입력 (판매하기일 때만 표시)
            if (_isSelling)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: TextField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        hintText: '₩ 가격을 입력해주세요.',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
              ),

            // 가격 제안 받기 (판매하기일 때만 표시)
            if (_isSelling)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isNegotiable,
                      onChanged: (value) {
                        setState(() {
                          _isNegotiable = value ?? false;
                        });
                      },
                    ),
                    Text('가격 제안 받기', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            Divider(height: 1),

            // 거래 정보
            _buildSectionTitle('거래 정보'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLocation,
                      isExpanded: true,
                      hint: Row(
                        children: [
                          Text(
                            '거래 희망 장소',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                          Spacer(),
                          Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                      items: _locations.map((String location) {
                        return DropdownMenuItem<String>(
                          value: location,
                          child: Text(location),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedLocation = value;
                        });
                      },
                      icon: SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
            Divider(height: 1),

            // 보여줄 동네 설정
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Row(
                children: [
                  Text(
                    '보여줄 동네 설정',
                    style: TextStyle(fontSize: 14),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),

            SizedBox(height: 20),

            // 작성 완료 버튼
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              child: ElevatedButton(
                onPressed: _handleAddProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF08F4F),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '작성 완료',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Padding(
      padding: EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '사진',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Upload button on the left
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[100],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 28, color: Colors.grey),
                      SizedBox(height: 4),
                      Text(
                        '${_selectedImages.length}/5',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              // Image thumbnails on the right
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      _selectedImages.length,
                      (index) => Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!, width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  base64Decode(_selectedImages[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            // 대표 사진 label on first image
                            if (index == 0)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    '대표 사진',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            // Delete button on top-right
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Message when max images reached
          if (_showMaxImagesMessage)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                '이미지는 최대 5장까지 선택 할 수 있어요.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(15, 15, 15, 0),
      child: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          icon: Icon(Icons.chevron_right),
          items: _categories.map((String category) {
            return DropdownMenuItem<String>(
              value: category,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(category),
              ),
            );
          }).toList(),
          onChanged: (String? value) {
            setState(() {
              _selectedCategory = value;
            });
          },
        ),
      ),
    );
  }
}
