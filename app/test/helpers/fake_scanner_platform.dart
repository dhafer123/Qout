import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// A camera-less mobile_scanner backend: tests push barcodes, choose whether
/// starting fails, and see what the app asked of the camera.
class FakeScannerPlatform extends MobileScannerPlatform {
  /// Thrown by [start] while set (e.g. permission denied).
  MobileScannerException? startError;

  /// Torch state reported when the camera starts.
  TorchState initialTorch = TorchState.off;

  int startCalls = 0;
  int stopCalls = 0;
  int toggleTorchCalls = 0;
  StartOptions? lastStartOptions;

  final _barcodes = StreamController<BarcodeCapture?>.broadcast();
  final _torch = StreamController<TorchState>.broadcast();
  TorchState _torchState = TorchState.off;

  static const cameraKey = Key('fake-camera');

  /// One camera frame containing [barcodes].
  void emit(List<Barcode> barcodes) =>
      _barcodes.add(BarcodeCapture(barcodes: barcodes));

  /// One frame with a single barcode.
  void emitCode(String raw, [BarcodeFormat format = BarcodeFormat.ean13]) =>
      emit([Barcode(rawValue: raw, format: format)]);

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream => _torch.stream;

  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    startCalls++;
    lastStartOptions = startOptions;
    if (startError case final error?) throw error;
    _torchState = initialTorch;
    return MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: _torchState,
      size: const Size(720, 1280),
      numberOfCameras: 1,
    );
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> toggleTorch() async {
    toggleTorchCalls++;
    _torchState = _torchState == TorchState.on ? TorchState.off : TorchState.on;
    _torch.add(_torchState);
  }

  @override
  Widget buildCameraView() =>
      const ColoredBox(key: cameraKey, color: Colors.black);
}

/// Installs a fresh [FakeScannerPlatform] for one test, restored after it.
FakeScannerPlatform installFakeScanner() {
  final previous = MobileScannerPlatform.instance;
  final fake = FakeScannerPlatform();
  MobileScannerPlatform.instance = fake;
  addTearDown(() {
    MobileScannerPlatform.instance = previous;
    MobileScannerController.resetPlatformSessionOwner();
  });
  return fake;
}

/// [MobileScannerException] for [code].
MobileScannerException scannerError(MobileScannerErrorCode code) =>
    MobileScannerException(errorCode: code);
