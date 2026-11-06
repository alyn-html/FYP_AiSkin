import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart' show InputImage;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../theme/app_theme.dart';
import '../services/scan_store.dart';
import '../services/ai_chat_service.dart';
import '../services/diary_store.dart';
import '../services/routine_store.dart';

enum _ScanPhase { upload, scanning, results }

class ScanScreen extends StatefulWidget {
  final VoidCallback? onViewRoutine;
  final String initialTab;
  final int navRequestId;
  const ScanScreen({super.key, this.onViewRoutine, this.initialTab = 'scan', this.navRequestId = 0});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ChatMsg {
  final String role; // 'ai' or 'user'
  final String text;
  final Uint8List? image;
  bool addedToRoutine;
  _ChatMsg(this.role, this.text, [this.image, this.addedToRoutine = false]);
}

class _ValidationResult {
  final String? rejection;
  final Rect? faceBox;
  _ValidationResult(this.rejection, this.faceBox);
}

class _ScanScreenState extends State<ScanScreen> {
  static const labels = [
    'Acne breakout',
    'Excess oiliness',
    'Dryness / dehydration',
    'Dark circles / eye bags',
    'Redness / rosacea',
  ];
  static List<Color> get _metricColors => [AppColors.coral, const Color(0xFFF0C070), const Color(0xFFB890C8), const Color(0xFF7FB069), AppColors.green];

  // Photo-quality thresholds: average brightness (0-255) and how much of the frame the face should fill.
  static const _minLuminance = 50.0;
  static const _maxLuminance = 220.0;
  static const _minFaceShare = 0.08;

  late String _tab = widget.initialTab;
  _ScanPhase _phase = _ScanPhase.upload;
  double _progress = 0;
  Timer? _progressTimer;
  File? _selectedImage;
  FullSkinAnalysis? _fullAnalysis;

  final _chatCtrl = TextEditingController();
  final List<_ChatMsg> _messages = [
    _ChatMsg('ai', "Hi! I'm your AI skin assistant 🌸 Ask me a question or attach a photo of a skin concern."),
  ];
  bool _aiThinking = false;
  String? _previousInteractionId;
  Uint8List? _pendingImageBytes;
  String? _pendingImageMime;
  static const _quickPrompts = ['Dry patches on arm', 'Skin redness tips', 'Foods for clear skin', 'Acne prevention'];

  @override
  void initState() {
    super.initState();
    AiUsage.instance.load();
  }

  @override
  void didUpdateWidget(covariant ScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navRequestId != oldWidget.navRequestId) {
      setState(() {
        _tab = widget.initialTab;
        _phase = _ScanPhase.upload;
      });
    }
  }

  // Checks lighting and face presence/position on the real captured photo.
  // Returns a rejection message on failure, or the detected face box (if any) on success.
  Future<_ValidationResult> _validatePhoto(File file, img.Image decoded) async {
    int total = 0, count = 0;
    final stepX = (decoded.width / 40).ceil().clamp(1, 200);
    final stepY = (decoded.height / 40).ceil().clamp(1, 200);
    for (int y = 0; y < decoded.height; y += stepY) {
      for (int x = 0; x < decoded.width; x += stepX) {
        final p = decoded.getPixel(x, y);
        final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        total += lum.round();
        count++;
      }
    }
    final avgLum = count == 0 ? 128.0 : total / count;
    if (avgLum < _minLuminance) return _ValidationResult('Too dark — find brighter, more even lighting and try again.', null);
    if (avgLum > _maxLuminance) return _ValidationResult('Too bright — avoid strong backlight or direct flash glare.', null);

    final detector = FaceDetector(options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast));
    List<Face> faces = [];
    try {
      faces = await detector.processImage(InputImage.fromFile(file));
    } catch (e) {
      debugPrint('Face detection unavailable, skipping face check: $e');
      return _ValidationResult(null, null);
    } finally {
      detector.close();
    }

    if (faces.isEmpty) return _ValidationResult("No face detected — make sure your face is clearly visible and well-lit.", null);
    if (faces.length > 1) return _ValidationResult('Multiple faces detected — please photograph just yourself.', null);

    final face = faces.first;
    final faceArea = face.boundingBox.width * face.boundingBox.height;
    final imageArea = decoded.width * decoded.height;
    if (imageArea > 0 && faceArea / imageArea < _minFaceShare) {
      return _ValidationResult('Move closer — your face should fill more of the frame.', null);
    }

    return _ValidationResult(null, face.boundingBox);
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    final file = File(picked.path);
    final decoded = img.decodeImage(file.readAsBytesSync());
    if (decoded == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't read that photo — please try another.")));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral)),
              const SizedBox(width: 16),
              const Text('Checking photo quality…'),
            ],
          ),
        ),
      ),
    );
    _ValidationResult validation;
    try {
      validation = await _validatePhoto(file, decoded);
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    if (!mounted) return;

    if (validation.rejection != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validation.rejection!), backgroundColor: AppColors.coralDeep));
      return;
    }

    setState(() {
      _selectedImage = file;
      _phase = _ScanPhase.scanning;
      _progress = 0;
    });

    // Real Gemini analysis runs in the background — the progress bar below is just pacing,
    // capped short of 100% until the real result actually comes back.
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 90), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _progress = (_progress + 1).clamp(0, 92));
    });

    FullSkinAnalysis? analysis;
    String? errorMsg;
    try {
      analysis = await _runFullAnalysis(decoded);
    } catch (e) {
      debugPrint('Full skin analysis failed: $e');
      final msg = e.toString();
      if (msg.contains('Add your Gemini API key')) {
        errorMsg = "The AI analysis isn't fully set up — check that a real API key is in ai_chat_service.dart.";
      } else if (msg.contains('SocketException') || msg.contains('Failed host lookup') || msg.contains('Network is unreachable')) {
        errorMsg = "Looks like you're offline — check your connection and try again.";
      } else if (msg.contains('429')) {
        errorMsg = 'Too many requests right now — wait a moment and try again.';
      } else if (msg.contains('404')) {
        errorMsg = "The AI model couldn't be found — it may need a different model name in ai_chat_service.dart.";
      } else {
        errorMsg = 'Analysis failed: ${msg.length > 120 ? msg.substring(0, 120) : msg}';
      }
    }

    _progressTimer?.cancel();
    if (!mounted) return;

    if (analysis == null) {
      setState(() => _phase = _ScanPhase.upload);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg ?? 'Analysis failed.'), backgroundColor: AppColors.coralDeep));
      return;
    }

    debugPrint('Full analysis for ${file.path}: score=${analysis.healthScore}, top=${analysis.topConcern}, scores=${analysis.concernScores}');

    final savedPhotoPath = await _persistScanPhoto(file);

    await ScanStore.instance.addResult(
      analysis.concernScores,
      concernReasons: analysis.concernReasons,
      zoneNotes: analysis.zoneNotes,
      summary: analysis.summary,
      healthScoreDirect: analysis.healthScore,
      photoPath: savedPhotoPath,
    );
    await DiaryStore.instance.attachScanToToday(analysis.topConcern, analysis.healthScore);

    setState(() => _progress = 100);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _fullAnalysis = analysis;
      _phase = _ScanPhase.results;
    });
  }

  Future<String?> _persistScanPhoto(File source) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final scansDir = Directory('${dir.path}/scan_photos');
      if (!await scansDir.exists()) await scansDir.create(recursive: true);
      final filename = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final dest = await source.copy('${scansDir.path}/$filename');
      return dest.path;
    } catch (e) {
      debugPrint('Could not save scan photo: $e');
      return null;
    }
  }

  Future<FullSkinAnalysis> _runFullAnalysis(img.Image decoded) async {
    img.Image resized = decoded;
    if (decoded.width >= decoded.height && decoded.width > 1024) {
      resized = img.copyResize(decoded, width: 1024);
    } else if (decoded.height > decoded.width && decoded.height > 1024) {
      resized = img.copyResize(decoded, height: 1024);
    }
    final jpgBytes = img.encodeJpg(resized, quality: 85);
    return AiChatService.analyzeFace(
      imageBase64: base64Encode(jpgBytes),
      imageMimeType: 'image/jpeg',
    );
  }

  void _resetScan() {
    setState(() {
      _phase = _ScanPhase.upload;
      _selectedImage = null;
      _fullAnalysis = null;
      _progress = 0;
    });
  }

  Future<void> _pickChatImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;

    img.Image resized = decoded;
    if (decoded.width >= decoded.height && decoded.width > 768) {
      resized = img.copyResize(decoded, width: 768);
    } else if (decoded.height > decoded.width && decoded.height > 768) {
      resized = img.copyResize(decoded, height: 768);
    }
    final jpgBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 80));

    setState(() {
      _pendingImageBytes = jpgBytes;
      _pendingImageMime = 'image/jpeg';
    });
  }

  void _removePendingImage() {
    setState(() {
      _pendingImageBytes = null;
      _pendingImageMime = null;
    });
  }

  void _showChatCaptureGuide() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 110, height: 110, child: CustomPaint(painter: _CircleGuidePainter())),
              const SizedBox(height: 16),
              Text('Photograph the area', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 14),
              _guideTip('🎯', "Center the spot or area you're asking about"),
              _guideTip('💡', 'Good, even lighting helps the AI see it clearly'),
              _guideTip('📏', 'Get close enough that the area fills most of the frame'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); _showChatImageSourceSheet(); },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: AppColors.surface, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text("I'm Ready", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChatImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: Icon(Icons.camera_alt, color: AppColors.coral), title: const Text('Camera'), onTap: () { Navigator.pop(context); _pickChatImage(ImageSource.camera); }),
          ListTile(leading: Icon(Icons.photo_library, color: AppColors.coral), title: const Text('Gallery'), onTap: () { Navigator.pop(context); _pickChatImage(ImageSource.gallery); }),
        ]),
      ),
    );
  }

  void _showAddToRoutineDialog(_ChatMsg message) {
    final nameCtrl = TextEditingController();
    TimeOfDay pickedTime = const TimeOfDay(hour: 20, minute: 0);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add to Your Routine', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What should the reminder say?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Apply cream to dry patch on arm',
                  filled: true, fillColor: AppColors.coral.withOpacity(0.05),
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              Text('Remind me daily at:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: pickedTime);
                  if (t != null) setDialogState(() => pickedTime = t);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: Text(pickedTime.format(context), style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.coralDeep)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                await RoutineStore.instance.addCustomItem(name, pickedTime.hour, pickedTime.minute);
                if (mounted) setState(() => message.addedToRoutine = true);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: AppColors.surface),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendChat() async {
    final text = _chatCtrl.text.trim();
    final hasImage = _pendingImageBytes != null;
    if ((text.isEmpty && !hasImage) || _aiThinking) return;

    final allowed = await AiUsage.instance.tryConsume();
    if (!allowed) {
      setState(() => _messages.add(_ChatMsg('ai', "You've used all your AI conversations for today — come back tomorrow! 🌙")));
      return;
    }

    final messageText = text.isEmpty ? 'What do you think of this?' : text;
    final imageForSend = _pendingImageBytes;
    final imageMime = _pendingImageMime;

    setState(() {
      _messages.add(_ChatMsg('user', messageText, imageForSend));
      _aiThinking = true;
      _chatCtrl.clear();
      _pendingImageBytes = null;
      _pendingImageMime = null;
    });

    try {
      final result = await AiChatService.reply(
        userMessage: messageText,
        imageBase64: imageForSend != null ? base64Encode(imageForSend) : null,
        imageMimeType: imageMime,
        previousInteractionId: _previousInteractionId,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMsg('ai', result.text.isEmpty ? "I couldn't quite process that — try rephrasing?" : result.text));
        _previousInteractionId = result.interactionId ?? _previousInteractionId;
        _aiThinking = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      String fallback;
      if (msg.contains('Add your Gemini API key')) {
        fallback = "The AI assistant isn't fully set up yet — check that a real API key has been added.";
      } else if (msg.contains('SocketException') || msg.contains('Failed host lookup') || msg.contains('Network is unreachable')) {
        fallback = "Looks like you're offline — check your internet connection and try again.";
      } else if (msg.contains('429')) {
        fallback = "I'm getting a lot of questions right now — give me a moment and try again in a bit. 🌸";
      } else {
        fallback = "The AI assistant is having a little trouble right now — we'll get it sorted soon! Feel free to try again shortly. 🌸";
      }
      setState(() {
        _messages.add(_ChatMsg('ai', fallback));
        _aiThinking = false;
      });
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _chatCtrl.dispose();
    super.dispose();
  }

  String get _scanningCaption {
    if (_progress < 30) return 'Detecting skin tone…';
    if (_progress < 55) return 'Mapping skin zones…';
    if (_progress < 80) return 'Identifying concerns…';
    return 'Generating insights…';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          Text('AI Skin Analysis ✨', style: GoogleFonts.fraunces(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.textDark, letterSpacing: -0.6)),
          const SizedBox(height: 2),
          Text('Upload a selfie for personalised insights', style: TextStyle(fontSize: 13, color: AppColors.rose, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          _tabs(),
          const SizedBox(height: 14),
          if (_tab == 'scan') _aiDisclaimer(),
          if (_tab == 'scan') const SizedBox(height: 14),
          if (_tab == 'scan') ..._scanTab() else _chatTab(),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(child: _tabButton('scan', '📸  Face Scan')),
          Expanded(child: _tabButton('chat', '💬  Skin Assistant')),
        ],
      ),
    );
  }

  Widget _tabButton(String key, String label) {
    final active = _tab == key;
    return GestureDetector(
      onTap: () => setState(() {
        _tab = key;
        if (key == 'scan') _phase = _ScanPhase.upload;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: active ? LinearGradient(colors: [AppColors.coral, AppColors.coralDeep]) : null,
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: active ? AppColors.surface : AppColors.rose)),
      ),
    );
  }

  Widget _aiDisclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.smart_toy_outlined, size: 14, color: AppColors.coralDeep),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'AI-generated analysis — not a medical diagnosis. Consult a dermatologist for concerns.',
              style: TextStyle(fontSize: 10.5, color: AppColors.coralDeep, fontWeight: FontWeight.w600, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _scanTab() {
    switch (_phase) {
      case _ScanPhase.upload:
        return _uploadPhase();
      case _ScanPhase.scanning:
        return _scanningPhase();
      case _ScanPhase.results:
        return _resultsPhase();
    }
  }

  List<Widget> _uploadPhase() {
    return [
      GestureDetector(
        onTap: _showPreCaptureGuide,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: AppColors.coral.withOpacity(0.04),
            border: Border.all(color: const Color(0xFFF5C6CF), width: 2),
          ),
          child: Column(
            children: [
              const Text('🌸', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 12),
              Text('Upload Your Selfie', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 6),
              Text('Good lighting · Front-facing · No filter', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.rose, fontWeight: FontWeight.w500, height: 1.5)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 11),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.coral, AppColors.coralDeep]), borderRadius: BorderRadius.circular(999)),
                child: Text('Choose Photo', style: TextStyle(color: AppColors.surface, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8, crossAxisSpacing: 8,
        childAspectRatio: 1.1,
        children: const [
          ('💧', 'Hydration'), ('✨', 'Radiance'), ('🌿', 'Balance'),
          ('🔴', 'Redness'), ('🫧', 'Texture'), ('☀️', 'UV Care'),
        ].map((e) => _FeatureTile(icon: e.$1, label: e.$2)).toList(),
      ),
      const SizedBox(height: 20),
      _historySection(),
    ];
  }
  String _historyDateLabel(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} · $h:$m $ampm';
  }

  Widget _historySection() {
    return ValueListenableBuilder<List<ScanResult>>(
      valueListenable: ScanStore.instance.results,
      builder: (context, scans, _) {
        if (scans.isEmpty) return const SizedBox.shrink();
        final recent = scans.reversed.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Past Scans', style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text('Tap a scan to see its full analysis', style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            ...recent.map((r) {
              final hasPhoto = r.photoPath != null && File(r.photoPath!).existsSync();
              return GestureDetector(
                onTap: () => _showScanDetail(r),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: hasPhoto
                            ? Image.file(File(r.photoPath!), width: 52, height: 52, fit: BoxFit.cover)
                            : Container(
                                width: 52, height: 52,
                                color: AppColors.coral.withOpacity(0.12),
                                alignment: Alignment.center,
                                child: const Text('🌸', style: TextStyle(fontSize: 22)),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_historyDateLabel(r.date), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                            const SizedBox(height: 2),
                            Text(r.topLabel, style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${r.healthScore}', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.coral)),
                          Text('/ 100', style: TextStyle(fontSize: 9, color: AppColors.rose, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 18, color: AppColors.rose),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _showScanDetail(ScanResult r) {
    final entries = labels.map((l) => MapEntry(l, r.scores[l] ?? 0.0)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final hasPhoto = r.photoPath != null && File(r.photoPath!).existsSync();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.rose.withOpacity(0.4), borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('Scan Analysis', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textDark))),
                GestureDetector(
                  onTap: () => Navigator.pop(sheetContext),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.12), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Icon(Icons.close, size: 18, color: AppColors.coralDeep),
                  ),
                ),
              ],
            ),
            Text(_historyDateLabel(r.date), style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500)),
            const SizedBox(height: 14),
            if (hasPhoto) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(File(r.photoPath!), width: double.infinity, height: 220, fit: BoxFit.cover),
              ),
              const SizedBox(height: 14),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.coral.withOpacity(0.10), AppColors.coral.withOpacity(0.02)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.coral.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${r.healthScore}', style: GoogleFonts.fraunces(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.coral)),
                      Text(' / 100 Skin Health Score', style: TextStyle(fontSize: 12, color: AppColors.rose, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Top concern: ${r.topLabel}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.coralDeep)),
                  if (r.summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(r.summary, style: TextStyle(fontSize: 12.5, color: AppColors.textDark, fontWeight: FontWeight.w500, height: 1.5)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Skin Metrics', style: GoogleFonts.fraunces(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 12),
            ...entries.map((e) {
              final colorIdx = labels.indexOf(e.key);
              final color = _metricColors[colorIdx >= 0 ? colorIdx % _metricColors.length : 0];
              final reason = r.concernReasons[e.key] ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        Text('${(e.value * 100).round()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: e.value.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE8D7B8).withOpacity(0.4),
                        color: color,
                      ),
                    ),
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(reason, style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500, height: 1.4)),
                    ],
                  ],
                ),
              );
            }),
            if (r.zoneNotes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Zone Observations', style: GoogleFonts.fraunces(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 10),
              ...r.zoneNotes.entries.map((z) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8, height: 8,
                          margin: const EdgeInsets.only(top: 5, right: 10),
                          decoration: BoxDecoration(color: AppColors.purple, shape: BoxShape.circle),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(z.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                              Text(z.value, style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500, height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.coral,
                  side: BorderSide(color: AppColors.coral, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPreCaptureGuide() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 110, height: 140, child: CustomPaint(painter: _FaceGuidePainter())),
              const SizedBox(height: 16),
              Text('Get the best scan', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 14),
              _guideTip('💡', 'Find bright, even lighting — avoid backlight or heavy shadows'),
              _guideTip('🙂', 'Face the camera directly and fill the oval'),
              _guideTip('🚫', 'No filters, and makeup-free gives the most accurate read'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); _showSourceSheet(); },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: AppColors.surface, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text("I'm Ready", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guideTip(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: AppColors.textDark, fontWeight: FontWeight.w500, height: 1.4))),
        ],
      ),
    );
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: Icon(Icons.camera_alt, color: AppColors.coral), title: const Text('Camera'), onTap: () { Navigator.pop(context); _pickAndAnalyze(ImageSource.camera); }),
          ListTile(leading: Icon(Icons.photo_library, color: AppColors.coral), title: const Text('Gallery'), onTap: () { Navigator.pop(context); _pickAndAnalyze(ImageSource.gallery); }),
        ]),
      ),
    );
  }

  List<Widget> _scanningPhase() {
    return [
      const SizedBox(height: 8),
      Center(
        child: Container(
          width: 200, height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.coral.withOpacity(0.3), width: 3),
            boxShadow: [BoxShadow(color: AppColors.coral.withOpacity(0.08), blurRadius: 20, spreadRadius: 10)],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_selectedImage != null) Image.file(_selectedImage!, fit: BoxFit.cover),
              Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.coral.withOpacity(0.08), AppColors.coralDeep.withOpacity(0.12)]))),
              Align(
                alignment: Alignment(-1 + 2 * (_progress / 100), 0),
                child: Container(width: 3, color: AppColors.coral.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      Center(child: Text(_scanningCaption, style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textDark))),
      const SizedBox(height: 6),
      Center(child: Text('AI analysis in progress', style: TextStyle(fontSize: 13, color: AppColors.rose, fontWeight: FontWeight.w500))),
      const SizedBox(height: 20),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(value: _progress / 100, minHeight: 8, backgroundColor: const Color(0xFFE8D7B8).withOpacity(0.4), color: AppColors.coral),
      ),
      const SizedBox(height: 8),
      Center(child: Text('${_progress.round()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.coral))),
    ];
  }

  List<Widget> _resultsPhase() {
    final analysis = _fullAnalysis!;
    final entries = labels.map((l) => MapEntry(l, analysis.concernScores[l] ?? 0.0)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_selectedImage != null)
            ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.file(_selectedImage!, width: 68, height: 68, fit: BoxFit.cover)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Analysis Complete ✨', style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 3),
                Text.rich(TextSpan(
                  style: TextStyle(fontSize: 12, color: AppColors.rose, fontWeight: FontWeight.w500, height: 1.5),
                  children: [
                    const TextSpan(text: 'Top concern: '),
                    TextSpan(text: analysis.topConcern, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.coral)),
                  ],
                )),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.coral.withOpacity(0.10), AppColors.coral.withOpacity(0.02)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.coral.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${analysis.healthScore}', style: GoogleFonts.fraunces(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.coral)),
                Text(' / 100 Skin Health Score', style: TextStyle(fontSize: 12, color: AppColors.rose, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Text(analysis.summary, style: TextStyle(fontSize: 12.5, color: AppColors.textDark, fontWeight: FontWeight.w500, height: 1.5)),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Skin Metrics', style: GoogleFonts.fraunces(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 14),
            ...List.generate(entries.length, (i) {
              final label = entries[i].key;
              final value = entries[i].value;
              final colorIdx = labels.indexOf(label);
              final color = _metricColors[colorIdx >= 0 ? colorIdx % _metricColors.length : 0];
              final reason = analysis.concernReasons[label] ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        Text('${(value * 100).round()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(value: value.clamp(0.0, 1.0), minHeight: 8, backgroundColor: const Color(0xFFE8D7B8).withOpacity(0.4), color: color),
                    ),
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(reason, style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500, height: 1.4)),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      if (analysis.zoneNotes.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Zone Observations', style: GoogleFonts.fraunces(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text('Reasoned directly from your photo — no separate per-crop model involved.',
                  style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500, height: 1.4)),
              const SizedBox(height: 12),
              ...analysis.zoneNotes.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8, height: 8,
                          margin: const EdgeInsets.only(top: 5, right: 10),
                          decoration: BoxDecoration(color: AppColors.purple, shape: BoxShape.circle),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                              Text(e.value, style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500, height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: widget.onViewRoutine ?? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check the Routine tab below!'))),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral, foregroundColor: AppColors.surface, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text('🌿  Generate Personalized Care Plan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _resetScan,
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.coral, side: BorderSide(color: AppColors.coral, width: 1.5), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text('Scan Again', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ),
      ),
    ];
  }

  Widget _chatTab() {
    return Column(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: AiUsage.instance.remaining,
          builder: (context, remaining, _) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Center(
              child: Text('💬 $remaining AI conversation${remaining == 1 ? '' : 's'} remaining today',
                  style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        Container(
          constraints: const BoxConstraints(minHeight: 300, maxHeight: 380),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
          child: ListView(
            shrinkWrap: true,
            children: [
              ..._messages.asMap().entries.map((entry) {
                final msgIndex = entry.key;
                final m = entry.value;
                final isAi = m.role == 'ai';
                final showAddButton = isAi && msgIndex > 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isAi) Container(
                        width: 30, height: 30,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF5C6CF), Color(0xFFF28B8F)]), borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: const Text('🌸', style: TextStyle(fontSize: 14)),
                      ),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                          children: [
                            Container(
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.62),
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                              decoration: BoxDecoration(
                                color: isAi ? AppColors.surface : null,
                                gradient: isAi ? null : LinearGradient(colors: [AppColors.coral, AppColors.coralDeep]),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isAi ? 4 : 16), bottomRight: Radius.circular(isAi ? 16 : 4),
                                ),
                                border: isAi ? Border.all(color: const Color(0xFFE8D7B8).withOpacity(0.5)) : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (m.image != null) ...[
                                    Center(
                                      child: ClipOval(
                                        child: Image.memory(m.image!, width: 130, height: 130, fit: BoxFit.cover),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Text(m.text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.5, color: isAi ? AppColors.textDark : AppColors.surface)),
                                ],
                              ),
                            ),
                            if (showAddButton)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: GestureDetector(
                                  onTap: m.addedToRoutine ? null : () => _showAddToRoutineDialog(m),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: m.addedToRoutine ? AppColors.green.withOpacity(0.15) : AppColors.coral.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: m.addedToRoutine ? AppColors.green.withOpacity(0.4) : AppColors.coral.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      m.addedToRoutine ? '✓ Added to Routine' : '➕ Add to Routine',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: m.addedToRoutine ? const Color(0xFF4A8030) : AppColors.coralDeep),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (_aiThinking)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 30, height: 30,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF5C6CF), Color(0xFFF28B8F)]), borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: const Text('🌸', style: TextStyle(fontSize: 14)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(4), bottomRight: Radius.circular(16)),
                          border: Border.all(color: const Color(0xFFE8D7B8).withOpacity(0.5)),
                        ),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _quickPrompts.map((p) => Padding(
              padding: const EdgeInsets.only(right: 7),
              child: GestureDetector(
                onTap: () => setState(() => _chatCtrl.text = p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.15), borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.coral.withOpacity(0.3))),
                  alignment: Alignment.center,
                  child: Text(p, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFC05870))),
                ),
              ),
            )).toList(),
          ),
        ),
        if (_pendingImageBytes != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              ClipOval(
                child: Image.memory(_pendingImageBytes!, width: 44, height: 44, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('Photo attached', style: TextStyle(fontSize: 12, color: AppColors.rose, fontWeight: FontWeight.w600))),
              GestureDetector(
                onTap: _removePendingImage,
                child: Icon(Icons.close, size: 18, color: AppColors.rose),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            GestureDetector(
              onTap: _aiThinking ? null : _showChatCaptureGuide,
              child: Container(
                width: 46, height: 46,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: AppColors.coral.withOpacity(0.12), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(Icons.add_a_photo_outlined, size: 18, color: AppColors.coral),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _chatCtrl,
                enabled: !_aiThinking,
                onSubmitted: (_) => _sendChat(),
                decoration: InputDecoration(
                  hintText: 'Describe your skin concern…',
                  filled: true, fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: Color(0xFFF5C6CF))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: Color(0xFFF5C6CF))),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _aiThinking ? null : _sendChat,
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.coral, AppColors.coralDeep])),
                alignment: Alignment.center,
                child: Icon(Icons.send, size: 18, color: AppColors.surface),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CircleGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.coral
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width < size.height ? size.width : size.height) / 2 - 2;
    canvas.drawCircle(center, radius, paint);
    final dotPaint = Paint()..color = AppColors.coral.withOpacity(0.5);
    canvas.drawCircle(center, 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _CircleGuidePainter oldDelegate) => false;
}

class _FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.coral
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final rect = Rect.fromLTWH(size.width * 0.12, 0, size.width * 0.76, size.height);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _FaceGuidePainter oldDelegate) => false;
}

class _FeatureTile extends StatelessWidget {
  final String icon, label;
  const _FeatureTile({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        ],
      ),
    );
  }
}