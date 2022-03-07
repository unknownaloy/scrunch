# Scrunch

A package that allows you to compress image files in a separate isolate with the option of
setting the desired size to trigger compression

## Features

* Uses flutter_isolate to compress image files in a separate isolate.
* Ability to set the image size from where compression should take place.

## Getting started

To use this package =>

Run this command:
```dart
flutter pub add scrunch
```
Or, add the following to your ***pubspec.yaml*** file:
```dart
dependencies:
    ...
    scrunch: LATEST_VERSION
```

## Usage

Import scrunch.dart
```dart
import 'package:scrunch/scrunch.dart';
```

Quick sample usage example

```dart
final Scrunch scrunch = Scrunch();

List<File> imageFilesToCompress = [image1, image2, image3];

Future<List<File>?> runCompression(List<File?> imageFiles) async {
  try {
    // The second argument passed into the function (5) is the size in megabytes that if the image
    // exceeds compression should take place
    final compressedFiles = await scrunch.compress(imageFiles, 5);
    return compressedFiles;
  } catch (e) {
    // Handle error
  } finally {
    scrunch.dispose();
  }
} 

final compressedImageFiles = await runCompression(imageFilesToCompress);
```

## Additional information

Pull requests are welcome. For major changes, please open an issue first to discuss what you would 
like to change.
