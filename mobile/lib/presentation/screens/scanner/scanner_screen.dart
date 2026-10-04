// lib/presentation/screens/scanner/scanner_screen.dart
// ----------------------------------------
// Real-time camera scanner with Google ML Kit OCR.
// Throttled to 2 FPS, with set code regex extraction, haptics,
// and manual code entry fallback.

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ocr_regex.dart';
import '../../../data/models/card_set_link_model.dart';
import '../../providers/card_search_provider.dart';
import 'scan_confirmation_sheet.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer();

  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  bool _isPaused = false;
  int _lastProcessTimestamp = 0;
  String? _detectedCodeStatus;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de cámara denegado')),
        );
      }
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _cameraController!.initialize();
    if (!mounted) return;

    setState(() {
      _isCameraInitialized = true;
    });

    _cameraController!.startImageStream(_processCameraImage);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle to 2 FPS (every 500ms)
    if (_isProcessingFrame || _isPaused || (now - _lastProcessTimestamp < AppConstants.ocrFrameIntervalMs)) {
      return;
    }

    _isProcessingFrame = true;
    _lastProcessTimestamp = now;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;

      final recognizedText = await _textRecognizer.processImage(inputImage);
      final candidates = OcrRegex.extractCandidates(recognizedText.text);

      if (candidates.isNotEmpty) {
        final bestCandidate = candidates.first;
        setState(() => _detectedCodeStatus = 'Detectado: $bestCandidate');

        // Look up card in repository
        final repo = ref.read(cardRepositoryProvider);
        final card = await repo.lookupBySetCode(bestCandidate);

        if (card != null && !_isPaused) {
          _isPaused = true;
          HapticFeedback.mediumImpact();

          if (mounted) {
            _showConfirmationSheet(card);
          }
        }
      }
    } catch (_) {
      // Ignore transient frame errors
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    if (_cameraController == null) return null;
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _showConfirmationSheet(CardSetLinkModel card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScanConfirmationSheet(
        cardInfo: card,
        onDismissed: () {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              setState(() {
                _isPaused = false;
                _detectedCodeStatus = null;
              });
            }
          });
        },
      ),
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isPaused = false;
          _detectedCodeStatus = null;
        });
      }
    });
  }

  void _showManualEntryDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Ingresar Código Manualmente', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: textController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Ej: LOB-001, MP21-EN001',
            prefixIcon: Icon(Icons.qr_code, color: AppTheme.primaryGold),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = textController.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                final repo = ref.read(cardRepositoryProvider);
                final card = await repo.lookupBySetCode(code);
                if (card != null && mounted) {
                  _showConfirmationSheet(card);
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No se encontró la carta con código $code'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryGold),
              SizedBox(height: 16),
              Text('Iniciando cámara...', style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          CameraPreview(_cameraController!),

          // Dark overlay with card cutout
          _buildViewfinderOverlay(),

          // Top Header & Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Escanear Carta',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard, color: AppTheme.primaryGold),
                    tooltip: 'Entrada manual',
                    onPressed: _showManualEntryDialog,
                  ),
                ],
              ),
            ),
          ),

          // Bottom instruction and detection badge
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                if (_detectedCodeStatus != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _detectedCodeStatus!,
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: const Text(
                    'Apunta al código de expansión\n(debajo de la ilustración, a la derecha)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewfinderOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * 0.85;
        final height = width * 1.45; // Yu-Gi-Oh! card ratio 59mm x 86mm ~ 1.45

        return Center(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primaryGold.withOpacity(0.8), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Highlight box in the bottom right where set code resides
                Positioned(
                  bottom: height * 0.38,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.goldLight, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                      color: AppTheme.primaryGold.withOpacity(0.1),
                    ),
                    child: const Text(
                      'CÓDIGO AQUÍ',
                      style: TextStyle(
                        color: AppTheme.primaryGold,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
