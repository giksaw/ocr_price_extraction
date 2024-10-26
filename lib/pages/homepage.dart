import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img; 
import 'dart:typed_data';


class OCRScreen extends StatefulWidget {
  @override
  _OCRScreenState createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> {
  File? _image;
  String? _imageName;
  Map<String, String> _extractedPrices = {};
  final TextRecognizer _textRecognizer = TextRecognizer();
  List<String> _allPrices = [];
  int _rotationAngle = 0;

  final Color _primaryColor = Colors.blue;
  final Color _accentColor = Colors.orange;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickImage({required ImageSource source}) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _imageName = source == ImageSource.gallery
            ? path.basename(pickedFile.path)
            : 'Captured_Image.jpg';
        _extractedPrices.clear();
        _allPrices.clear();
        _rotationAngle = 0;  
      });
      _performOCR();
    }
  }

Future<void> _rotateImage() async {
  if (_image == null) return;

  try {
 
    Uint8List imageBytes = await _image!.readAsBytes(); 
    img.Image? originalImage = img.decodeImage(imageBytes);

    if (originalImage == null) {
      throw Exception('Failed to decode image');
    }

 
    img.Image rotatedImage = img.copyRotate(originalImage, angle: 90);

   
    final tempDir = await getTemporaryDirectory();
    final tempPath = path.join(tempDir.path, 'rotated_${DateTime.now().millisecondsSinceEpoch}.jpg');

   
    File rotatedFile = File(tempPath);
    await rotatedFile.writeAsBytes(img.encodeJpg(rotatedImage));

    setState(() {
      _image = rotatedFile;
      _rotationAngle = (_rotationAngle + 90) % 360;
      _extractedPrices.clear();
      _allPrices.clear();
    });

 
    _performOCR();

  } catch (e) {
    print('Error rotating image: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error rotating image: $e')),
    );
  }
}


  Future<void> _performOCR() async {
    if (_image == null) return;

    final inputImage = InputImage.fromFile(_image!);
    try {
      final RecognizedText recognizedText = 
          await _textRecognizer.processImage(inputImage);

      String text = recognizedText.text;
      _findAllPrices(text);
      
    
      if (_allPrices.length == 1) {
        setState(() {
          _extractedPrices = {"Price": _allPrices[0]};
        });
      } else if (_allPrices.isNotEmpty) {
        
        _showPriceSelectionDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No prices detected in the image')),
        );
      }
    } catch (e) {
      print('Error performing OCR: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error performing text recognition: $e')),
      );
    }
  }

  void _findAllPrices(String text) {
    final RegExp priceRegExp = RegExp(r'(\₹|\$)?\d+\.\d{2}');
    Set<String> uniquePrices = {};  

    final List<String> lines = text.split('\n');
    for (String line in lines) {
      final matches = priceRegExp.allMatches(line);
      for (var match in matches) {
        String price = match.group(0)!;
        uniquePrices.add(price);
      }
    }

    setState(() {
      _allPrices = uniquePrices.toList();
    });
  }

void _showPriceSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Multiple Prices Detected'),
          content: SizedBox(  
            width: MediaQuery.of(context).size.width * 0.9, 
            child: SingleChildScrollView(  
              child: Column(  
                mainAxisSize: MainAxisSize.min,
                children: _allPrices.asMap().entries.map((entry) {
                  int index = entry.key;
                  String price = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Price ${index + 1}: $price',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _extractedPrices = {"MRP": price};
                                  });
                                  Navigator.of(context).pop();
                                },
                                child: Text('Set as MRP'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _extractedPrices = {"Sale Price": price};
                                  });
                                  Navigator.of(context).pop();
                                },
                                child: Text('Set as Sale'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accentColor,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 24),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveToFile() async {
    if (_imageName == null || _extractedPrices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No data to save.")),
      );
      return;
    }

    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception("Unable to access external storage directory");
      }

      final file = File('${directory.path}/extracted_prices.txt');
      String newContent = '$_imageName: ${_extractedPrices.toString()}\n';
      await file.writeAsString(newContent, mode: FileMode.append);

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
            if (_allPrices.isNotEmpty && _extractedPrices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Found ${_allPrices.length} prices. Please select one.',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: 24),
            _buildActionButtons(),
            SizedBox(height: 24),
            _buildExtractedPricesSection(),
            if (_allPrices.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ElevatedButton(
                  onPressed: _showPriceSelectionDialog,
                  child: Text('Select Different Price'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
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
            Stack(
              alignment: Alignment.topRight,
              children: [
                _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _image!,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
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
                if (_image != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: _rotateImage,
                      child: Icon(Icons.rotate_right),
                      backgroundColor: _primaryColor,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              _imageName ?? 'No Image Selected',
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
            if (_image != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Rotation: ${_rotationAngle}°',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
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