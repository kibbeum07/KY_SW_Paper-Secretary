import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const PaperAssistantApp());
}

// ⚠️ 파이썬 FastAPI 서버 주소
// 시연할 때는 노트북 IP 주소에 맞게 수정하세요.
const String serverUrl = 'http://127.0.0.1:8001';

List<Map<String, dynamic>> savedDocuments = [];

const Color kPrimary = Color(0xff6C4AB6);
const Color kPrimaryDark = Color(0xff3D2C8D);
const Color kBackground = Color(0xffF7F3FF);
const Color kCard = Colors.white;
const Color kText = Color(0xff22223B);
const Color kSubText = Color(0xff6B6B80);

class PaperAssistantApp extends StatelessWidget {
  const PaperAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '종이 비서',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: kBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          primary: kPrimary,
          secondary: kPrimaryDark,
          background: kBackground,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: kBackground,
          foregroundColor: kText,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: kText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kPrimaryDark,
            side: const BorderSide(color: Color(0xffD7C9FF)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xffFAF9FF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xffDDD6F7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xffDDD6F7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kPrimary, width: 1.5),
          ),
          labelStyle: const TextStyle(color: kSubText),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xffEEE9FF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class PageShell extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const PageShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(padding: padding, child: child),
        ),
      ),
    );
  }
}

void showAppMessage(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

/* ================= 로그인 화면 ================= */

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final idController = TextEditingController();
  final pwController = TextEditingController();

  bool isLoading = false;

  Future<void> login() async {
    if (idController.text.trim().isEmpty || pwController.text.trim().isEmpty) {
      showAppMessage(context, '알림', '아이디와 비밀번호를 입력해주세요.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/login'),
        body: {
          'user_id': idController.text.trim(),
          'password': pwController.text.trim(),
        },
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentTypePage(
              userId: data['user_id'],
              userName: data['name'],
            ),
          ),
        );
      } else {
        showAppMessage(context, '로그인 실패', data['message'] ?? '로그인에 실패했습니다.');
      }
    } catch (e) {
      showAppMessage(context, '서버 연결 실패', '파이썬 서버가 실행 중인지 확인해주세요.');
    }

    if (mounted) setState(() => isLoading = false);
  }

  void goSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageShell(
        child: Column(
          children: [
            const SizedBox(height: 28),
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: kPrimary.withOpacity(0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.description_rounded,
                color: kPrimary,
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '종이 비서',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: kText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '어려운 문서를 쉽게 요약하고\n필요한 정보만 정리해주는 AI 문서 도우미',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: kSubText, height: 1.45),
            ),
            const SizedBox(height: 28),
            AppCard(
              child: Column(
                children: [
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline),
                      labelText: '아이디',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: pwController,
                    obscureText: true,
                    onSubmitted: (_) => login(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.lock_outline),
                      labelText: '비밀번호',
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : login,
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('로그인'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: goSignup,
                    child: const Text('처음이라면 회원가입하기'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================= 회원가입 화면 ================= */

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final idController = TextEditingController();
  final pwController = TextEditingController();
  final nameController = TextEditingController();

  bool isLoading = false;

  Future<void> signup() async {
    if (idController.text.trim().isEmpty ||
        pwController.text.trim().isEmpty ||
        nameController.text.trim().isEmpty) {
      showAppMessage(context, '알림', '아이디, 비밀번호, 이름을 모두 입력해주세요.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/signup'),
        body: {
          'user_id': idController.text.trim(),
          'password': pwController.text.trim(),
          'name': nameController.text.trim(),
        },
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('알림'),
          content: Text(data['message'] ?? '회원가입 처리 완료'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (data['success'] == true) Navigator.pop(context);
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (e) {
      showAppMessage(context, '서버 연결 실패', '파이썬 서버가 실행 중인지 확인해주세요.');
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: PageShell(
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '새 계정 만들기',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '문서 분석 결과를 저장하기 위해 계정을 만들어주세요.',
                style: TextStyle(color: kSubText),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.badge_outlined),
                  labelText: '이름',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline),
                  labelText: '아이디',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pwController,
                obscureText: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline),
                  labelText: '비밀번호',
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : signup,
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('회원가입 완료'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ================= 문서 형식 선택 화면 ================= */

class DocumentTypePage extends StatelessWidget {
  final String userId;
  final String userName;

  const DocumentTypePage({
    super.key,
    required this.userId,
    required this.userName,
  });

  void logout(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void goUpload(BuildContext context, String type, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UploadPage(
          userId: userId,
          documentType: type,
          documentTitle: title,
        ),
      ),
    );
  }

  Widget typeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String type,
    required Color iconBg,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => goUpload(context, type, title),
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 30, color: kPrimaryDark),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(color: kSubText, height: 1.35),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kSubText, size: 30),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('문서 선택'),
        actions: [
          IconButton(
            tooltip: '저장폴더',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SavedFolderPage(userId: userId),
              ),
            ),
            icon: const Icon(Icons.folder_outlined),
          ),
          IconButton(
            tooltip: '로그아웃',
            onPressed: () => logout(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: PageShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$userName님, 안녕하세요 👋',
              style: const TextStyle(fontSize: 18, color: kSubText),
            ),
            const SizedBox(height: 8),
            const Text(
              '어떤 문서를 분석할까요?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: kText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '모든 문서는 요약과 핵심 정보 추출을 진행하고, 계약서는 위험도 분석이 추가됩니다.',
              style: TextStyle(fontSize: 15, color: kSubText, height: 1.45),
            ),
            const SizedBox(height: 24),
            typeCard(
              context,
              icon: Icons.gavel_rounded,
              title: '계약서',
              subtitle: '요약, 핵심 조항, 위험도 색상 표시',
              type: 'contract',
              iconBg: const Color(0xffFFF0F0),
            ),
            typeCard(
              context,
              icon: Icons.assignment_rounded,
              title: '신청서 / 안내문',
              subtitle: '제출 기한, 준비물, 작성 항목 정리',
              type: 'notice',
              iconBg: const Color(0xffEEF4FF),
            ),
            typeCard(
              context,
              icon: Icons.receipt_long_rounded,
              title: '영수증 / 고지서',
              subtitle: '금액, 날짜, 기관명 등 핵심 정보 추출',
              type: 'receipt',
              iconBg: const Color(0xffF0FFF4),
            ),
            typeCard(
              context,
              icon: Icons.insert_drive_file_rounded,
              title: '기타 문서',
              subtitle: 'OCR 텍스트 추출 및 쉬운 말 요약',
              type: 'general',
              iconBg: const Color(0xffF6F1FF),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================= 문서 업로드 및 분석 화면 ================= */

class UploadPage extends StatefulWidget {
  final String userId;
  final String documentType;
  final String documentTitle;

  const UploadPage({
    super.key,
    required this.userId,
    required this.documentType,
    required this.documentTitle,
  });

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final ImagePicker picker = ImagePicker();

  List<Uint8List> imageBytesList = [];
  List<String> imageNameList = [];

  bool isLoading = false;

  Future<void> pickMultipleImages() async {
    final List<XFile> images = await picker.pickMultiImage(
      imageQuality: 100,
      maxWidth: 2400,
      maxHeight: 2400,
    );

    if (images.isNotEmpty) {
      for (final image in images) {
        final bytes = await image.readAsBytes();
        imageBytesList.add(bytes);
        imageNameList.add(image.name);
      }
      setState(() {});
    }
  }

  Future<void> takePhoto() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        imageBytesList.add(bytes);
        imageNameList.add(image.name);
      });
    }
  }

  void removeImage(int index) {
    setState(() {
      imageBytesList.removeAt(index);
      imageNameList.removeAt(index);
    });
  }

  Future<void> analyzeDocument() async {
    if (imageBytesList.isEmpty) {
      showAppMessage(context, '알림', '먼저 문서를 1장 이상 업로드해주세요.');
      return;
    }

    setState(() => isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$serverUrl/analyze_multi'),
      );

      request.fields['user_id'] = widget.userId;
      request.fields['document_type'] = widget.documentType;

      for (int i = 0; i < imageBytesList.length; i++) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            imageBytesList[i],
            filename: imageNameList[i],
          ),
        );
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = jsonDecode(responseBody);

      if (data['success'] == false) {
        showAppMessage(
          context,
          '분석 실패',
          data['summary'] ?? '문서 분석 중 오류가 발생했습니다.',
        );
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultPage(
            result: data,
            documentTitle: widget.documentTitle,
            documentType: widget.documentType,
            userId: widget.userId,
          ),
        ),
      );
    } catch (e) {
      showAppMessage(
        context,
        '분석 오류',
        '파이썬 서버가 실행 중인지, /analyze_multi 기능이 추가되었는지 확인해주세요.',
      );
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isContract = widget.documentType == 'contract';

    return Scaffold(
      appBar: AppBar(title: Text('${widget.documentTitle} 업로드')),
      body: PageShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.documentTitle} 문서를 추가해주세요',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: kText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isContract
                  ? '여러 장을 추가하면 전체 내용을 합쳐 위험도까지 분석합니다.'
                  : '여러 장을 추가하면 전체 OCR 텍스트를 합쳐 요약합니다.',
              style: const TextStyle(color: kSubText, height: 1.45),
            ),
            const SizedBox(height: 22),
            AppCard(
              child: imageBytesList.isEmpty
                  ? SizedBox(
                      height: 230,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 58,
                            color: kPrimary,
                          ),
                          SizedBox(height: 14),
                          Text(
                            '아직 추가된 문서가 없습니다.',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: kText,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '갤러리 또는 카메라로 문서를 추가해주세요.',
                            style: TextStyle(color: kSubText),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: imageBytesList.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.memory(
                                imageBytesList[index],
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: InkWell(
                                onTap: () => removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.58),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: kPrimaryDark.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${index + 1}쪽',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : pickMultipleImages,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('갤러리'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : takePhoto,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('촬영'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed: imageBytesList.isEmpty || isLoading
                    ? null
                    : analyzeDocument,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  isLoading ? '분석 중...' : '${imageBytesList.length}장 문서 분석 시작',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================= 분석 결과 화면 ================= */

class ResultPage extends StatelessWidget {
  final Map<String, dynamic> result;
  final String documentTitle;
  final String documentType;
  final String userId;

  const ResultPage({
    super.key,
    required this.result,
    required this.documentTitle,
    required this.documentType,
    required this.userId,
  });

  Color getRiskColor(String? level) {
    if (level == '위험') return const Color(0xffFFE5E5);
    if (level == '주의') return const Color(0xffFFF3D6);
    if (level == '안전') return const Color(0xffE7F8ED);
    return Colors.grey.shade200;
  }

  Color getRiskTextColor(String? level) {
    if (level == '위험') return const Color(0xffD62828);
    if (level == '주의') return const Color(0xffD97706);
    if (level == '안전') return const Color(0xff1B8A4A);
    return Colors.black54;
  }

  IconData getRiskIcon(String? level) {
    if (level == '위험') return Icons.warning_rounded;
    if (level == '주의') return Icons.error_outline_rounded;
    if (level == '안전') return Icons.check_circle_rounded;
    return Icons.info_outline_rounded;
  }

  Widget sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryDark, size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kText,
            ),
          ),
        ],
      ),
    );
  }

  Widget resultBox(String text) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      child: SelectableText(
        text.isEmpty ? '내용이 없습니다.' : text,
        style: const TextStyle(height: 1.5, color: kText),
      ),
    );
  }

  Widget keyInfoBox(Map<String, dynamic> keyInfo) {
    if (keyInfo.isEmpty) return resultBox('추출된 핵심 정보가 없습니다.');

    return AppCard(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: keyInfo.entries.map((entry) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xffF0ECFF))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kText,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value.toString(),
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: kSubText),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> saveDocument(BuildContext context) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/save_document'),
        body: {
          'user_id': userId,
          'title': documentTitle,
          'doc_type': documentType,
          'summary': result['summary'] ?? '',
          'risk_level': result['risk_level'] ?? '',
          'ocr_text': result['ocr_text'] ?? '',
        },
      );

      final data = jsonDecode(response.body);

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(data['success'] == true ? '저장 완료' : '저장 실패'),
          content: Text(data['message'] ?? '처리 결과를 확인할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('저장 오류'),
          content: const Text('서버와 연결할 수 없어 구글 시트에 저장하지 못했습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> keyInfo = Map<String, dynamic>.from(
      result['key_info'] ?? {},
    );
    final String riskLevel = result['risk_level'] ?? '해당 없음';
    final String riskMessage =
        result['risk_message'] ?? '위험도 분석이 적용되지 않는 문서입니다.';

    return Scaffold(
      appBar: AppBar(title: const Text('분석 결과')),
      body: PageShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$documentTitle 분석 결과',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: kText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI가 문서 내용을 요약하고 핵심 정보를 정리했습니다.',
              style: TextStyle(color: kSubText),
            ),
            const SizedBox(height: 22),
            sectionTitle('문서 요약', Icons.summarize_rounded),
            resultBox(result['summary'] ?? ''),
            sectionTitle('핵심 정보', Icons.fact_check_rounded),
            keyInfoBox(keyInfo),
            if (documentType == 'contract') ...[
              sectionTitle('계약서 위험도 분석', Icons.security_rounded),
              AppCard(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(22),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: getRiskColor(riskLevel),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        getRiskIcon(riskLevel),
                        color: getRiskTextColor(riskLevel),
                        size: 42,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        riskLevel,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: getRiskTextColor(riskLevel),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        riskMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(height: 1.45, color: kText),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            sectionTitle('OCR 추출 텍스트', Icons.text_snippet_rounded),
            resultBox(result['ocr_text'] ?? ''),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => saveDocument(context),
                icon: const Icon(Icons.save_alt_rounded),
                label: const Text('앱 내 저장폴더에 저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================= 저장폴더 화면 ================= */

class SavedFolderPage extends StatefulWidget {
  final String userId;

  const SavedFolderPage({super.key, required this.userId});

  @override
  State<SavedFolderPage> createState() => _SavedFolderPageState();
}

class _SavedFolderPageState extends State<SavedFolderPage> {
  List<Map<String, dynamic>> documents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadDocuments();
  }

  Future<void> loadDocuments() async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/get_documents?user_id=${widget.userId}'),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        final List list = data['documents'] ?? [];

        setState(() {
          documents = list.map((e) => Map<String, dynamic>.from(e)).toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('저장폴더')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : documents.isEmpty
          ? const Center(
              child: Text(
                '저장된 문서가 없습니다.',
                style: TextStyle(color: kSubText, fontSize: 16),
              ),
            )
          : PageShell(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '저장된 분석 결과',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '카드를 누르면 저장된 문서 내용을 자세히 볼 수 있습니다.',
                    style: TextStyle(color: kSubText),
                  ),
                  const SizedBox(height: 18),
                  ...documents.asMap().entries.map((entry) {
                    final index = entry.key;
                    final doc = entry.value;

                    return InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SavedDocumentDetailPage(document: doc),
                          ),
                        );
                      },
                      child: AppCard(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xffF1EAFF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.folder_rounded,
                                color: kPrimaryDark,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${index + 1}. ${doc['title'] ?? '제목 없음'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                      color: kText,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${doc['created_at'] ?? ''} · ${doc['risk_level'] ?? ''}',
                                    style: const TextStyle(
                                      color: kSubText,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    doc['summary'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: kSubText,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: kSubText,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}

/* ================= 저장 문서 상세보기 화면 ================= */

class SavedDocumentDetailPage extends StatelessWidget {
  final Map<String, dynamic> document;

  const SavedDocumentDetailPage({super.key, required this.document});

  String _value(String key) {
    final value = document[key];
    if (value == null) return '';
    return value.toString();
  }

  Color _riskBackground(String riskLevel) {
    if (riskLevel == '위험') return const Color(0xffFFE5E5);
    if (riskLevel == '주의') return const Color(0xffFFF3D6);
    if (riskLevel == '안전') return const Color(0xffE7F8ED);
    return const Color(0xffF1EAFF);
  }

  Color _riskTextColor(String riskLevel) {
    if (riskLevel == '위험') return const Color(0xffD62828);
    if (riskLevel == '주의') return const Color(0xffD97706);
    if (riskLevel == '안전') return const Color(0xff1B8A4A);
    return kPrimaryDark;
  }

  Widget detailSection({
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: kPrimaryDark, size: 22),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(18),
          child: SelectableText(
            content.trim().isEmpty ? '내용이 없습니다.' : content,
            style: const TextStyle(color: kText, height: 1.5, fontSize: 15),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _value('title').isEmpty ? '제목 없음' : _value('title');
    final type = _value('type').isEmpty ? _value('doc_type') : _value('type');
    final riskLevel = _value('risk_level').isEmpty
        ? '해당 없음'
        : _value('risk_level');

    return Scaffold(
      appBar: AppBar(title: const Text('문서 상세보기')),
      body: PageShell(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              padding: const EdgeInsets.all(22),
              margin: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: kText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_value('created_at')} · $type',
                    style: const TextStyle(color: kSubText, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _riskBackground(riskLevel),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '위험도: $riskLevel',
                      style: TextStyle(
                        color: _riskTextColor(riskLevel),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            detailSection(
              title: '문서 요약',
              icon: Icons.summarize_rounded,
              content: _value('summary'),
            ),
            detailSection(
              title: 'OCR 원문',
              icon: Icons.text_snippet_rounded,
              content: _value('ocr_text'),
            ),
          ],
        ),
      ),
    );
  }
}
