import 'dart:math' show sqrt;
import 'dart:typed_data';

import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/utils/json_converters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:vector_math/vector_math_64.dart' as vecmath;

// Type definitions to enforce a consistent use of the API
typedef ARHitResultHandler = void Function(List<ARHitTestResult> hits);

/// Manages the session configuration, parameters and events of an [ARView]
class ARSessionManager {
  /// Platform channel used for communication from and to [ARSessionManager]
  late MethodChannel _channel;

  MethodChannel get channel => _channel;

  /// Debugging status flag. If true, all platform calls are printed. Defaults to false.
  final bool debug;

  /// Context of the [ARView] widget that this manager is attributed to
  final BuildContext buildContext;

  /// Determines the types of planes ARCore and ARKit should show
  final PlaneDetectionConfig planeDetectionConfig;

  /// Receives hit results from user taps with tracked planes or feature points
  late ARHitResultHandler onPlaneOrPointTap;

  ARSessionManager(int id, this.buildContext, this.planeDetectionConfig,
      {this.debug = false}) {
    _channel = MethodChannel('arsession_$id');
    _channel.setMethodCallHandler(_platformCallHandler);
    if (debug) {
      print("ARSessionManager initialized");
    }
  }

  /// Returns the camera pose in Matrix4 format with respect to the world coordinate system of the [ARView]
  Future<Matrix4?> getCameraPose() async {
    try {
      final serializedCameraPose =
          await _channel.invokeMethod<List<dynamic>>('getCameraPose', {});
      return MatrixConverter().fromJson(serializedCameraPose!);
    } catch (e) {
      print('Error caught: ' + e.toString());
      return null;
    }
  }

  /// Returns the given anchor pose in Matrix4 format with respect to the world coordinate system of the [ARView]
  Future<Matrix4?> getPose(ARAnchor anchor) async {
    try {
      if (anchor.name.isEmpty) {
        throw Exception("Anchor can not be resolved. Anchor name is empty.");
      }
      final serializedCameraPose =
          await _channel.invokeMethod<List<dynamic>>('getAnchorPose', {
        "anchorId": anchor.name,
      });
      return MatrixConverter().fromJson(serializedCameraPose!);
    } catch (e) {
      print('Error caught: ' + e.toString());
      return null;
    }
  }

  /// Returns the distance in meters between @anchor1 and @anchor2.
  Future<double?> getDistanceBetweenAnchors(
      ARAnchor anchor1, ARAnchor anchor2) async {
    var anchor1Pose = await getPose(anchor1);
    var anchor2Pose = await getPose(anchor2);
    var anchor1Translation = anchor1Pose?.getTranslation();
    var anchor2Translation = anchor2Pose?.getTranslation();
    if (anchor1Translation != null && anchor2Translation != null) {
      return getDistanceBetweenVectors(anchor1Translation, anchor2Translation);
    } else {
      return null;
    }
  }

  /// Returns the distance in meters between @anchor and device's camera.
  Future<double?> getDistanceFromAnchor(ARAnchor anchor) async {
    Matrix4? cameraPose = await getCameraPose();
    Matrix4? anchorPose = await getPose(anchor);
    Vector3? cameraTranslation = cameraPose?.getTranslation();
    Vector3? anchorTranslation = anchorPose?.getTranslation();
    if (anchorTranslation != null && cameraTranslation != null) {
      return getDistanceBetweenVectors(anchorTranslation, cameraTranslation);
    } else {
      return null;
    }
  }

  /// Returns the distance in meters between @vector1 and @vector2.
  double getDistanceBetweenVectors(Vector3 vector1, Vector3 vector2) {
    num dx = vector1.x - vector2.x;
    num dy = vector1.y - vector2.y;
    num dz = vector1.z - vector2.z;
    double distance = sqrt(dx * dx + dy * dy + dz * dz);
    return distance;
  }

  Future<void> _platformCallHandler(MethodCall call) {
    if (debug) {
      print('_platformCallHandler call ${call.method} ${call.arguments}');
    }
    try {
      switch (call.method) {
        case 'onError':
          onError(call.arguments[0]);
          print(call.arguments);

          break;
        case 'onPlaneOrPointTap':
          final rawHitTestResults = call.arguments as List<dynamic>;
          final serializedHitTestResults = rawHitTestResults
              .map((hitTestResult) => Map<String, dynamic>.from(hitTestResult))
              .toList();
          final hitTestResults = serializedHitTestResults.map((e) {
            return ARHitTestResult.fromJson(e);
          }).toList();
          onPlaneOrPointTap(hitTestResults);

          break;
        case 'dispose':
          _channel.invokeMethod<void>("dispose");
          break;
        default:
          if (debug) {
            print('Unimplemented method ${call.method} ');
          }
      }
    } catch (e) {
      print('Error caught: ' + e.toString());
    }
    return Future.value();
  }

  /// Function to initialize the platform-specific AR view. Can be used to initially set or update session settings.
  /// [customPlaneTexturePath] refers to flutter assets from the app that is calling this function, NOT to assets within this plugin. Make sure
  /// the assets are correctly registered in the pubspec.yaml of the parent app (e.g. the ./example app in this plugin's repo)
  onInitialize({
    bool showAnimatedGuide = true,
    bool showFeaturePoints = false,
    bool showPlanes = true,
    String? customPlaneTexturePath,
    bool showWorldOrigin = false,
    bool handleTaps = true,
    bool handlePans = false, // nodes are not draggable by default
    bool handleRotation = false, // nodes can not be rotated by default
  }) {
    _channel.invokeMethod<void>('init', {
      'showAnimatedGuide': showAnimatedGuide,
      'showFeaturePoints': showFeaturePoints,
      'planeDetectionConfig': planeDetectionConfig.index,
      'showPlanes': showPlanes,
      'customPlaneTexturePath': customPlaneTexturePath,
      'showWorldOrigin': showWorldOrigin,
      'handleTaps': handleTaps,
      'handlePans': handlePans,
      'handleRotation': handleRotation,
    });
  }

  /// Displays the [errorMessage] in a snackbar of the parent widget
  onError(String errorMessage) {
    ScaffoldMessenger.of(buildContext).showSnackBar(SnackBar(
        content: Text(errorMessage),
        action: SnackBarAction(
            label: 'HIDE',
            onPressed:
                ScaffoldMessenger.of(buildContext).hideCurrentSnackBar)));
  }

  /// Dispose the AR view on the platforms to pause the scenes and disconnect the platform handlers.
  /// You should call this before removing the AR view to prevent out of memory erros
  dispose() async {
    try {
      await _channel.invokeMethod<void>("dispose");
    } catch (e) {
      print(e);
    }
  }

  /// Returns a future ImageProvider that contains a screenshot of the current AR Scene
  Future<ImageProvider> snapshot() async {
    final result = await _channel.invokeMethod<Uint8List>('snapshot');
    return MemoryImage(result!);
  }

  int _logoIndex = -1;

  // TODO : transform this as to return a quaternion instead of a vector4
  Future<vecmath.Vector4> getCameraOrientation() async {
    vecmath.Vector4 cameraOrientation = vecmath.Vector4.zero();
    var data = await channel.invokeMethod<Float32List>('getCameraOrientation');

    cameraOrientation.x = data?.elementAt(0) ?? 0;
    cameraOrientation.y = data?.elementAt(1) ?? 0;
    cameraOrientation.z = data?.elementAt(2) ?? 0;
    cameraOrientation.w = data?.elementAt(3) ?? 1;

    return cameraOrientation;
  }

  Future<String> startRecording(String path) async {
    String filePath =
        await channel.invokeMethod<String>('startRecording', {'path': path}) ??
            'error';
    return filePath;
  }

  Future<void> stopRecording() async {
    await channel.invokeMethod<void>('stopRecording');
  }

  Future<int> getRecordLength(String path) async {
    int duration =
        await channel.invokeMethod<int>('getRecordLength', {'path': path}) ??
            -1;
    return duration;
  }

  Future<bool> enableLogoTracking() async {
    _logoIndex = await channel.invokeMethod<int>('enableLogoTracking') ?? -1;

    print('logo index : ' + _logoIndex.toString());

    return true;
  }

  Future<vecmath.Vector4> getQuaternionFromLogo() async {
    vecmath.Vector4 calibrationQuaternion = vecmath.Vector4.zero();
    var data = await channel.invokeMethod<Float32List>(
        'getQuaternionFromLogo', {'index': _logoIndex});

    calibrationQuaternion.x = data?.elementAt(0) ?? 0;
    calibrationQuaternion.y = data?.elementAt(1) ?? 0;
    calibrationQuaternion.z = data?.elementAt(2) ?? 0;
    calibrationQuaternion.w = data?.elementAt(3) ?? 1;

    return calibrationQuaternion;
  }

  Future<vecmath.Vector3> getTranslationFromLogo() async {
    vecmath.Vector3 translationVector = vecmath.Vector3.zero();
    var data = await channel.invokeMethod<Float32List>(
        'getTranslationFromLogo', {'index': _logoIndex});

    translationVector.x = data?.elementAt(0) ?? 0;
    translationVector.y = data?.elementAt(1) ?? 0;
    translationVector.z = data?.elementAt(2) ?? 0;

    return translationVector;
  }

  Future<bool> isLogoTracked() async {
    if (_logoIndex == -1) return false;

    var data = await channel
        .invokeMethod<bool>('isLogoTracked', {'index': _logoIndex});

    bool result = data ?? false;

    return result;
  }

  Future<String> getVIOTrackingStatus() async {
    var data = await channel.invokeMethod<String>('getTrackingStatus');

    String result = data ?? "";

    return result;
  }

  Future<String> getVIOTrackingError() async {
    var data = await channel.invokeMethod<String>('getTrackingError');

    String result = data ?? "";

    return result;
  }
}
