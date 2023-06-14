library scrunch;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Improvements that can be made include:
/// - Enabling the desired image size output in MB to be determined or assigned
/// by the person using an instance of the class to implement its methods

/// This class utilizes the [flutter_image_compress] and [flutter_isolate] packages
/// to compress an image in a separate isolate if the size of the image exceeds
/// the desired size.
///
/// NOTE: When an instance of this class which calls the [compress]
/// method is used, it is equally important to call the [dispose] method in
/// the [dispose] method of that class, or if used in a try-catch block, be called
/// in the finally-block to terminate the isolate, which could still be running in
/// the background. Though the [compress] automatically calls the [dispose]
/// when it has completed its given task, but it is still advisable to call the
/// [dispose] method in the off-chance that the isolate could still be running

class Scrunch {
  FlutterIsolate? _isolate;
  late ReceivePort _receivePort;

  /// This method will return a List of image files which has been compressed
  /// using a Isolate
  ///
  /// NOTE: This method has a "target" parameter of type "int" which is an
  /// optional parameter that defaults to "5" (i.e. 5 megabytes). This is the
  /// size limit set for each of the image files
  Future<List<File>?> compress(List<File?> files, [int targetSize = 5]) async {
    final filesToCompress = _extractOnlyImageFiles(files);

    if (filesToCompress.isEmpty) {
      return null; // None of the files passed in are image files
    }

    final compressFileSizeLimit = (1024 * 1024) * targetSize;

    _receivePort = ReceivePort();

    _isolate = await FlutterIsolate.spawn(
      _imageCompressHandler,
      _receivePort.sendPort,
    );

    SendPort sendPort = await _receivePort.first;

    ReceivePort answerPort = ReceivePort();

    /// Converting the passed files to List of String to sent to the isolate
    /// method responsible for compressing the image
    List<String> filePaths = _convertFilesToStringPaths(files);

    sendPort.send([
      filePaths, // <- Sending the file path
      compressFileSizeLimit, // <- File compress size limit
      answerPort.sendPort,
    ]);

    /// Newly converted file paths received from the isolate
    List<String> newFilePaths = await answerPort.first;

    /// Converting the received file paths (as List of String) to a List
    /// of File to be return from the method
    List<File> result = _convertStringPathsToFiles(newFilePaths);

    /// Terminating the isolate - Work completed
    dispose();

    return result;
  }

  /// This method will handle the compressing of the image file
  @pragma('vm:entry-point')
  static Future<void> _imageCompressHandler(SendPort sendPort) async {
    /// Result to be return from method
    List<String> result = [];

    ReceivePort childReceivePort = ReceivePort();

    sendPort.send(childReceivePort.sendPort);

    final msg = await childReceivePort.first;

    /// Extracting the passed data
    List<String> filePaths = msg[0] as List<String>;
    int fileCompressSizeLimit = msg[1] as int;
    SendPort replyPort = msg[2] as SendPort;

    /// Get the list of files
    List<File> files = _convertStringPathsToFiles(filePaths);

    for (File file in files) {
      bool shouldCompress = await _shouldImageBeCompressed(
        file,
        fileCompressSizeLimit,
      );

      if (shouldCompress == false) {
        result.add(file.path);
      } else {
        int percentageToCompressWith = await _calculateCompressPercentage(
          file,
          fileCompressSizeLimit,
        );
        String originalPath = file.path;
        String compressPath = await _getCompressPath(file);

        Map<String, int> imageDimension = await _getImageDimension(file);

        int width = imageDimension["width"] as int;
        int height = imageDimension["height"] as int;

        try {
          XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
            originalPath,
            compressPath,
            quality: percentageToCompressWith,
            minWidth: width,
            minHeight: height,
          );

          if (compressedFile != null) {
            result.add(compressedFile.path);
          } else {
            result.add(file.path);
          }
        } on UnsupportedError catch (e) {
          debugPrint("_imageCompressHandler - UnsupportedError -- e -> $e");
          result.add(file.path);
        } catch (e) {
          debugPrint("_imageCompressHandler - catch -- e -> $e");
          result.add(file.path);
        }
      }
    }

    replyPort.send(result);
  }

  /// Determine if image should be compressed
  ///
  /// NOTE: This method uses the "fileSizeLimit" value to determine if the
  /// image should be compressed. If the image size is greater than the
  /// "fileSizeLimit", the method will return "true" and the image compressed
  static Future<bool> _shouldImageBeCompressed(
    File file,
    int fileSizeLimit,
  ) async {
    bool shouldBeCompressed = false;

    try {
      final imageSize = await _getImageSize(file);

      if (imageSize != null && imageSize > fileSizeLimit) {
        shouldBeCompressed = true;
      }

    } catch (e) {
      debugPrint("_shouldImageBeCompressed - error -- $e");
    }

    return shouldBeCompressed;
  }


  /// The method returns the image size of the passed in image file
  static Future<int?> _getImageSize(File file) async {
    if (file.existsSync() == false) {
      return null;
    }

    try {
      final pickedFileByte = await file.readAsBytes();
      return pickedFileByte.lengthInBytes;
    } catch (e) {
      return null;
    }
  }


  /// This method uses the picked file path and creates a new temporary path
  /// where the compressed image will be written to
  static Future<String> _getCompressPath(File file) async {
    final directory = await getApplicationDocumentsDirectory();
    String localPath = directory.path;

    String newImageName = DateTime.now().millisecondsSinceEpoch.toString();
    String extension = p.extension(file.path);

    File newFile = File('$localPath/$newImageName$extension');
    await file.copy(newFile.path);

    return newFile.path;
  }

  /// This method calculates the percentage the [FlutterImageCompress]
  /// package should use in compressing the image file
  static Future<int> _calculateCompressPercentage(
    File file,
    int targetSize,
  ) async {
    final imageSize = await _getImageSize(file);

    if (imageSize == null) {
      return 25; // If imageSize is null only compress by 25%
    }

    /// Percentage image will be compressed with
    double percentage = (targetSize / imageSize) * 100;

    return percentage.toInt();
  }

  /// This method takes in a List of String which are the image file paths
  /// and returns a List of File
  static List<File> _convertStringPathsToFiles(List<String> filePaths) {
    List<File> result = [];

    for (String path in filePaths) {
      result.add(File(path));
    }

    return result;
  }

  /// This method takes a List of File and returns a List of String which
  /// is the file paths string values
  static List<String> _convertFilesToStringPaths(List<File?> files) {
    List<String> result = [];

    for (File? file in files) {
      if (file != null) {
        result.add(file.path);
      }
    }

    return result;
  }

  static Future<Map<String, int>> _getImageDimension(File file) async {
    late Map<String, int> dimension;

    try {
      Uint8List bytes = await file.readAsBytes();

      var imageDimensions = await decodeImageFromList(bytes);

      int width = imageDimensions.width;
      int height = imageDimensions.height;

      dimension = {
        "width": width,
        "height": height,
      };
    } catch (e) {
      dimension = {
        "width": 1920,
        "height": 1080,
      };
    }

    return dimension;
  }

  /// This method uses the "mime" to check if the file path passed points to
  /// an image file
  static bool _isImage(String path) {
    final mimeType = lookupMimeType(path);

    if (mimeType != null) {
      return mimeType.startsWith('image/');
    }

    return false;
  }

  /// This method uses the [_isImage] method to extract and return the list of
  /// files passed in that are images
  ///
  /// NOTE: The method return an empty list if all the files passed in are not
  /// image files
  static List<File> _extractOnlyImageFiles(List<File?> files) {
    List<File> result = [];
    for (File? file in files) {
      if (file != null && _isImage(file.path)) {
        result.add(file);
      }
    }

    return result;
  }

  /// This method terminates the running isolate if it's still active
  void dispose() {
    if (_isolate != null) {
      _receivePort.close();
      _isolate!.kill();
      _isolate = null;
    }
  }
}
