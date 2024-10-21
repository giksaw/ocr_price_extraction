import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class OCRScreen extends StatefulWidget {
  @override
  _OCRScreenState createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> {
  File? _image;
  String? _imageName;
  Map<String, String> _extractedPrices = {};

  final Color _primaryColor = Colors.blue;
  final Color _accentColor = Colors.orange;

  Future<void> _pickImage({required ImageSource source}) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _imageName = source == ImageSource.gallery
            ? path.basename(pickedFile.path)
            : 'Captured_Image.jpg';
      });
      _performOCR();
    }
  }

  Future<void> _performOCR() async {
    if (_image == null) return;

    final inputImage = InputImage.fromFile(_image!);
    final textRecognizer = GoogleMlKit.vision.textRecognizer();
    final RecognizedText recognizedText =
        await textRecognizer.processImage(inputImage);

    String text = recognizedText.text;
    setState(() {
      _extractedPrices = _extractPricesWithLabels(text);
    });

    await textRecognizer.close();
  }

  Map<String, String> _extractPricesWithLabels(String text) {
    final RegExp priceRegExp = RegExp(r'(\₹|\$)?\d+\.\d{2}');
    final Map<String, String> prices = {};

    final List<String> lines = text.split('\n');

    for (String line in lines) {
      final matches = priceRegExp.allMatches(line);

      for (var match in matches) {
        String price = match.group(0)!;

        if (line.toLowerCase().contains("mrp")) {
          prices["MRP"] = price;
        } else if (line.toLowerCase().contains("sale") ||
            line.toLowerCase().contains("discount")) {
          prices["Sale Price"] = price;
        } else {
          prices["Other Price"] = price;
        }
      }
    }

    return prices;
  }

  Future<void> _saveToFile() async {
    if (_imageName == null || _extractedPrices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No data to save.")),
      );
      return;
    }

    try {
      // Get the external storage directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception("Unable to access external storage directory");
      }

      final file = File('${directory.path}/extracted_prices.txt');

      print("Attempting to save file  ${file.path}");

      // Create the new content to be added
      String newContent = '$_imageName: ${_extractedPrices.toString()}\n';

      // Write or append to the file
      await file.writeAsString(newContent, mode: FileMode.append);

      print("File saved successfully");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Saved successfully to ${file.path}")),
      );
    } catch (e) {
      print("Error saving to file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving to file: $e")),
      );
    }
  }

  Future<void> _readFileContents() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception("Unable to access external storage directory");
      }

      final file = File('${directory.path}/extracted_prices.txt');
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("File does not exist.")),
        );
        return;
      }

      String contents = await file.readAsString();
      _showFileContents(contents);
    } catch (e) {
      print("Error reading file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error reading file: $e")),
      );
    }
  }

  void _showFileContents(String contents) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Extracted Prices"),
          content: SingleChildScrollView(
            child: Text(contents),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Price Extractor', style: TextStyle(color: Colors.white)),
        backgroundColor: _primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageSection(),
            SizedBox(height: 24),
            _buildActionButtons(),
            SizedBox(height: 24),
            _buildExtractedPricesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_image!, height: 200, fit: BoxFit.cover),
                  )
                : Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.image, size: 80, color: Colors.grey[400]),
                  ),
            SizedBox(height: 16),
            Text(
              _imageName ?? 'No Image Selected',
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              icon: Icons.photo_library,
              label: 'Pick Image',
              onPressed: () => _pickImage(source: ImageSource.gallery),
            ),
            _buildActionButton(
              icon: Icons.camera_alt,
              label: _image == null ? 'Take Photo' : 'Retake Photo',
              onPressed: () => _pickImage(source: ImageSource.camera),
            ),
          ],
        ),
        SizedBox(height: 16),
        _buildActionButton(
          icon: Icons.save,
          label: 'Save Extracted Prices',
          onPressed: _saveToFile,
          fullWidth: true,
        ),
        SizedBox(height: 16),
        _buildActionButton(
          icon: Icons.list,
          label: 'View Extracted Prices',
          onPressed: _readFileContents,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool fullWidth = false,
  }) {
    return SizedBox(
      width: fullWidth ? double.infinity : 150,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: TextStyle(color: Colors.white)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildExtractedPricesSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Detected Prices:",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor),
            ),
            SizedBox(height: 16),
            ..._extractedPrices.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${entry.key}:",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        entry.value,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _accentColor),
                      ),
                    ],
                  ),
                )),
            if (_extractedPrices.isEmpty)
              Text(
                "No prices detected yet.",
                style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}
