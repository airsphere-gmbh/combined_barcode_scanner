import 'dart:async';
import 'dart:io';

import 'package:combined_barcode_scanner_zebra/src/zebra/scan_callback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_datawedge/flutter_datawedge.dart';

class ZebraDataWedgeController {
  ScannerCallBack? _scannerCallBack;

  set scannerCallBack(ScannerCallBack scannerCallBack) => _scannerCallBack =
      scannerCallBack; // ignore: avoid_setters_without_getters

  void setScannerCallBack(ScannerCallBack scannerCallBack) =>
      this.scannerCallBack =
          scannerCallBack; // ignore: use_setters_to_change_properties

  StreamSubscription<ScanResult>? _subscription;
  FlutterDataWedge _dataWedge = FlutterDataWedge();
  bool _dataWedgeInitialied = false;
  late List<dynamic> profiles;
  bool? _supported;
  int _tries = 0;
  ZebraDataWedgeController();

  Future<bool> get isControllerSupported async {
    if (_supported != null) return _supported!;

    if ((!kIsWeb && Platform.isAndroid)) {
      Future<bool> hasProfiles() async {
        if (!_dataWedgeInitialied) {
          await _dataWedge.initialize();
          await _dataWedge.createDefaultProfile(profileName: "Default");
          _dataWedge.requestProfiles();
        }
        final completer = Completer<bool>();
        final subscription = _dataWedge.onScannerEvent.listen((event) {
          if (event.command == DatawedgeApiTargets.getProfiles.value) {
            profiles = event.resultInfo!['profiles'] as List<dynamic>;
            completer.complete(profiles.isNotEmpty);
          }
        });
        return completer.future
            .whenComplete(() => subscription.cancel())
            .timeout(const Duration(seconds: 10), onTimeout: () async {
          if (_tries++ > 18) return false;
          return await hasProfiles();
        });
      }

      return _supported = await hasProfiles();
    }

    return false;
  }

  Future<bool> init(String profileName) async {
    if (!profiles.contains(profileName)) {
      await _dataWedge.createDefaultProfile(profileName: profileName);
    }
    return true;
  }

  Future<dynamic> get imei async => null;

  Future<void> startScanning() async {
    _subscription ??= _dataWedge.onScanResult
        .listen((data) => _scannerCallBack?.onDecoded(data));
  }

  Future<void> stopScanning() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<bool> triggerScan() async {
    final res = await _dataWedge.activateScanner(true);
    return res.isSuccess;
  }
}
