import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:scrunch/scrunch.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ScrunchExamplePage(title: 'Scrunch Example Page'),
    );
  }
}

class ScrunchExamplePage extends StatefulWidget {
  const ScrunchExamplePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<ScrunchExamplePage> createState() => _ScrunchExamplePageState();
}

class _ScrunchExamplePageState extends State<ScrunchExamplePage> {
  final Scrunch _scrunch = Scrunch();

  /// This variable will hold the example file
  File? _exampleFile;

  /// This is the variable that'll hold the compressed file
  File? _compressedFile;

  /// This variable is used to indicate when the [_exampleFile] is being compressed
  /// and is used to change compress button text value from "Compress Image" to
  /// "Compressing..."
  bool _isCompressing = false;

  /// This method uses the "path_provider" package to create a file from the
  /// example asset image used for illustrating the compression process
  void getImageFileFromAssets() async {
    final byteData = await rootBundle.load('assets/example_image.jpg');

    final file =
        File('${(await getTemporaryDirectory()).path}/example_image.jpg');
    await file.writeAsBytes(byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    setState(() => _exampleFile = file);
  }

  @override
  void initState() {
    super.initState();

    getImageFileFromAssets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: _exampleFile == null
            ? const CircularProgressIndicator(
                strokeWidth: 2.0,
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      "Uncompressed Image",
                      style: Theme.of(context).textTheme.headline4,
                    ),
                    Image.asset("assets/example_image.jpg"),
                    _compressedFile == null
                        ? TextButton(
                            onPressed: !_isCompressing
                                ? () async {
                                    setState(() => _isCompressing = true);
                                    final result = await _scrunch
                                        .compressImage([
                                      _exampleFile!
                                    ], 8); // <- The minimum allow image size is set to 8 (i.e. 8 megabytes)

                                    if (result != null) {
                                      setState(
                                        () => _compressedFile = result[0],
                                      );
                                    }
                                  }
                                : null,
                            style: ButtonStyle(
                                backgroundColor:
                                    MaterialStateProperty.all<Color>(
                                        Colors.orangeAccent)),
                            child: Text(_isCompressing
                                ? "Compressing..."
                                : "Compress Image"),
                          )
                        : const SizedBox.shrink(),
                    _compressedFile != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                height: 24.0,
                              ),
                              Text(
                                "Compressed Image",
                                style: Theme.of(context).textTheme.headline4,
                              ),
                              Image.file(_compressedFile!),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
      ),
    );
  }
}
