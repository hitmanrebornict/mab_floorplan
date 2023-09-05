import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'package:vibration/vibration.dart';


final FlutterTts flutterTts = FlutterTts();

Future<void> _speak(String text, {VoidCallback? onComplete}) async {
  await flutterTts.setLanguage('en-US');
  await flutterTts.setPitch(1.0);
  await flutterTts.setSpeechRate(0.5);

  flutterTts.setCompletionHandler(() {
    if (onComplete != null) {
      onComplete();
    }
  });

  await flutterTts.speak(text);
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(FloorPlanApp());
}

// Firebase setup and function
final FirebaseFirestore firestore = FirebaseFirestore.instance;
final CollectionReference profiles = firestore.collection('profiles');

// Future<void> createProfile(String profileName, int numberOfFloors) async {
//   return profiles
//       .add({
//     'name': profileName,
//     'numberOfFloors': numberOfFloors
//   })
//       .then((value) => print("Profile Added"))
//       .catchError((error) => print("Failed to add profile: $error"));
// }

class FloorPlanApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Floorplan App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WelcomePage(),
    );
  }
}

class WelcomePage extends StatefulWidget {
  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class CreateProfilePage extends StatefulWidget {
  @override
  _CreateProfilePageState createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final TextEditingController _profileNameController = TextEditingController();
  final TextEditingController _numberOfFloorsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _profileNameController,
              decoration: InputDecoration(labelText: 'Profile Name'),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _numberOfFloorsController,
              decoration: InputDecoration(labelText: 'Number of Floors'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createProfile,
              child: Text('Create'),
            ),
          ],
        ),
      ),
    );

  }
  void _createProfile() async {
    String profileName = _profileNameController.text.trim();
    int numberOfFloors = int.parse(_numberOfFloorsController.text);

    // Ensure the profileName isn't empty
    if (profileName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please enter a profile name.'),
      ));
      return;
    }

    try {
      numberOfFloors = int.parse(_numberOfFloorsController.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please enter a valid number for floors.'),
      ));
      return;
    }

    try {
      // Using Firestore
      await firestore.collection("profiles").add({
        'profileName': profileName,
        'numberOfFloors': numberOfFloors,
        'timestamp': FieldValue.serverTimestamp(),
      });

    } catch (error) {
      print("Error adding document: $error");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('An error occurred. Please try again.'),
      ));
    }
  }
}

class EditMapPage extends StatefulWidget {
  final String profileName;
  final int numberOfFloors;


  EditMapPage({required this.profileName, required this.numberOfFloors});

  @override
  _EditMapPageState createState() => _EditMapPageState();

}

class Circle {
  Offset position;
  final String id;
  bool? selected;
  double size; // New property for size
  String? name;
  String? description;
  DateTime? lastTriggered;



  Circle(this.position, this.id,{this.size = 30.0, this.selected = false});

  Map<String, dynamic> toJson() {
    return {
      'position': {
        'dx': position.dx,
        'dy': position.dy,
      },
      'id': id,
      'selected': selected,
      'size': size,
      'name': name,
      'description': description,
    };

  }

  static Circle fromJson(Map<String, dynamic> json) {
    return Circle(
      Offset(json['position']['dx'], json['position']['dy']),
      json['id'],
      size: json['size'],
      // Add other fields as needed
    )
      ..name = json['name']
      ..description = json['description']
      ..selected = json['selected'];
  }

}

class _EditMapPageState extends State<EditMapPage> {
  List<String> floorOptions = [];
  String? selectedFloor;
  Image? uploadedImage;
  bool hasImage = false;


  final GlobalKey imageKey = GlobalKey();

  List<Circle> circles = [];

  double _scaleFactor = 1.0;
  static const double MIN_SIZE = 10.0;  // Minimum circle size
  static const double MAX_SIZE = 100.0;  // Maximum circle size
  static const double SCALE_MULTIPLIER = 0.05;  // Adjust this value to control the scaling effect

  @override
  void initState() {
    super.initState();
    _generateFloorOptions(widget.numberOfFloors);
    _checkAndDownloadImage();
    _loadCirclesFromFirebase();
  }

  Future<void> _saveCirclesToFirebase() async {
    final circlesJson = circles.map((circle) => circle.toJson()).toList();
    final circlesString = jsonEncode(circlesJson);

    final mapId = '${widget.profileName}_${selectedFloor}';

    final ref = FirebaseFirestore.instance.collection('maps').doc(mapId);

    await ref.set({'circles': circlesString});
  }



  Future<void> _loadCirclesFromFirebase() async {
    final mapId = '${widget.profileName}_${selectedFloor}';
    final ref = FirebaseFirestore.instance.collection('maps').doc(mapId);

    final doc = await ref.get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final circlesString = data['circles'];
      final circlesJson = jsonDecode(circlesString) as List;
      final loadedCircles = circlesJson.map((circleJson) => Circle.fromJson(circleJson)).toList();

      setState(() {
        circles = loadedCircles;
      });
    }
  }


  _generateFloorOptions(int floors) {
    floorOptions.clear();

      for (int i = 1; i <= floors; i++) {
        floorOptions.add('Floor $i');

    }
    // Initially select the first floor
    selectedFloor = floorOptions[0];
  }

  Future<void> _uploadImage() async {
    final imagePicker = ImagePicker();
    final image = await imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final imageName = '${widget.profileName}_${selectedFloor}_map.png';
    final imageFile = File(image.path);
    final ref = FirebaseStorage.instance.ref().child('maps').child(imageName);

    try {
      await ref.putFile(imageFile);
      setState(() {
        hasImage = true;
        uploadedImage = Image.file(imageFile);
      });
    } catch (e) {
      print('Error uploading image: $e');
    }
  }

  Future<void> _checkAndDownloadImage() async {
    final imageName = '${widget.profileName}_${selectedFloor}_map.png';
    final ref = FirebaseStorage.instance.ref().child('maps').child(imageName);

    // Checking if the image exists
    try {
      final result = await ref.getDownloadURL();

      setState(() {
        hasImage = true;
        uploadedImage = Image.network(result.toString()); // Using the image from Firebase Storage
      });
    } catch (e) {
      print('Error fetching image: $e');
      setState(() {
        hasImage = false;
      });
    }

    _loadCirclesFromFirebase();
  }

  Future<void> _showCircleInfoDialog(Circle circle) async {
    TextEditingController nameController = TextEditingController(text: circle.name);
    TextEditingController descriptionController = TextEditingController(text: circle.description);

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap the button to close the dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Circle Information'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Name',
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Description',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Save'),
              onPressed: () {
                setState(() {
                  circle.name = nameController.text.trim();
                  circle.description = descriptionController.text.trim();
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showCircleOptions(Circle circle) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.drag_handle),
                title: Text('Move'),
                onTap: () {
                  Navigator.pop(context);
                  // Set circle to moving state, this will allow user to drag the circle
                  setState(() {
                    circles.forEach((c) => c.selected = false);
                    circle.selected = true;
                  });
                },
              ),
              ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _showCircleInfoDialog(circle) ; // Use your existing method to show the prompt
                },
              ),
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete'),
                onTap: () async {
                  Navigator.pop(context);
                  // Delete circle from the UI
                  setState(() {
                    circles.remove(circle);
                  });
                  // Delete circle from Firebase
                  // await _deleteCircleFromFirebase(circle);
                },
              ),
            ],
          );
        });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit ${widget.profileName}')),
      body: GestureDetector(
        onScaleUpdate: (ScaleUpdateDetails details) {
          setState(() {
            // Find which circle is selected
            final selectedCircle = circles.firstWhere(
                    (element) => element.selected == true, orElse: () => Circle(Offset.zero, 'none'));

            // Update the size of the selected circle using the scale factor
            if (selectedCircle.id != 'none') {
              double scaleChange = 1 + (details.scale - 1) * SCALE_MULTIPLIER;
              double newSize = selectedCircle.size * scaleChange;

              // Apply constraints
              if (newSize < MIN_SIZE) {
                newSize = MIN_SIZE;
              } else if (newSize > MAX_SIZE) {
                newSize = MAX_SIZE;
              }

              selectedCircle.size = newSize;
            }
          });
        },
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(widget.profileName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(  // Wrap the dropdown and the button in a Row widget
                    children: [
                      Expanded(  // Make the dropdown take up all available horizontal space
                        child: DropdownButton<String>(
                          value: selectedFloor,
                          items: floorOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              selectedFloor = newValue;
                            });
                            _checkAndDownloadImage();
                          },
                        ),
                      ),
                      SizedBox(width: 10),  // A little spacing between the dropdown and the button
                      ElevatedButton(
                        onPressed: _uploadImage,
                        child: Text('Upload Image'),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: hasImage && uploadedImage != null
                      ? Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    key: imageKey,
                    width: MediaQuery.of(context).size.width,  // Use the full width
                    height: MediaQuery.of(context).size.height / 2,  // Use half the available height
                    child: Image(
                      image: uploadedImage!.image,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),
                  )
                      : Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height / 2,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        "Please upload a map.",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: ElevatedButton(
                onPressed: () {
                  final RenderBox renderBox = imageKey.currentContext!.findRenderObject() as RenderBox;
                  final position = renderBox.localToGlobal(Offset.zero);

                  setState(() {
                    circles.add(Circle(position, DateTime.now().toIso8601String()));
                  });
                },
                child: Text('Add Circle'),
              ),
            ),
            Positioned(
              right: 10,  // 10 pixels from the right
              bottom: 10, // 10 pixels from the bottom
              child: ElevatedButton(
                onPressed: () async {
                  await _saveCirclesToFirebase();
                  Navigator.pop(context);
                },
                child: Text('Save & Exit'),
              ),
            ),
            ...circles.map((circle) {
              return Positioned(
                left: circle.position.dx,
                top: circle.position.dy,
                child: GestureDetector(
                  onTap: () async {
                    _showCircleOptions(circle);
                  },
                  onPanUpdate: (details) {
                    if (circle.selected == true) {
                      setState(() {
                        circle.position = Offset(
                          circle.position.dx + details.delta.dx,
                          circle.position.dy + details.delta.dy,
                        );
                      });
                    }
                  },
                  child: Container(
                    width: circle.size,
                    height: circle.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: circle.selected == true
                          ? Colors.green
                          : Colors.blue,
                    ),
                  ),
                ),

              );
            }).toList(),
          ],
        ),

      ),
    );
  }
}



class EditProfilePage extends StatefulWidget {
  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchProfiles() async {
    QuerySnapshot snapshot = await _firestore.collection('profiles').get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Existing Profile')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchProfiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final profiles = snapshot.data;

            return ListView.builder(
              itemCount: profiles?.length ?? 0,
              itemBuilder: (context, index) {
                final profile = profiles?[index];
                return ListTile(
                  title: Text(profile?['profileName']),
                  subtitle: Text('Number of floors: ${profile?['numberOfFloors']}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditMapPage(
                            profileName: profile?['profileName'],
                            numberOfFloors: profiles?[index]['numberOfFloors'],
                          ),
                        ),
                      );
                    }
                );
              },
            );
          }
        },
      ),
    );
  }
}

class ChooseProfilePage extends StatefulWidget {
  @override
  _ChooseProfilePageState createState() => _ChooseProfilePageState();
}

class _ChooseProfilePageState extends State<ChooseProfilePage> {
  final _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> fetchProfiles() async {
    QuerySnapshot snapshot = await _firestore.collection('profiles').get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Existing Profile')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchProfiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final profiles = snapshot.data;

            return ListView.builder(
              itemCount: profiles?.length ?? 0,
              itemBuilder: (context, index) {
                final profile = profiles?[index];
                return ListTile(
                    title: Text(profile?['profileName']),
                    subtitle: Text('Number of floors: ${profile?['numberOfFloors']}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserMainPage(
                            profileName: profile?['profileName'],
                            numberOfFloors: profiles?[index]['numberOfFloors'],
                          ),
                        ),
                      );
                    }
                );
              },
            );
          }
        },
      ),
    );
  }
}

class UserMainPage extends StatefulWidget {
  final String profileName;
  final int numberOfFloors;

  UserMainPage({required this.profileName, required this.numberOfFloors});

  @override
  _UserMainPageState createState() => _UserMainPageState();
}

class _UserMainPageState extends State<UserMainPage> {
  List<String> floorOptions = [];
  String? selectedFloor;
  Image? uploadedImage;
  bool hasImage = false;
  bool isNavigationMode = true;  // true for Navigation Mode, false for Guide Mode

  Map<String, DateTime> lastTriggeredTime = {}; //Used to check the triggered circle time
  Map<String, DateTime> lastAudioEndTime = {}; // To check the last audio (for vibration)

  List<Circle> circles = [];

  @override
  void initState() {
    super.initState();
    _generateFloorOptions(widget.numberOfFloors);
    _checkAndDownloadImage();
    _loadCirclesFromFirebase();
  }

  Future<void> _announceNumberOfCircles() async {
    final FlutterTts flutterTts = FlutterTts();
    String textToAnnounce = "There are ${circles.length} labels on this floor.";
    await flutterTts.speak(textToAnnounce);
  }

  Future<void> _loadCirclesFromFirebase() async {
    final mapId = '${widget.profileName}_${selectedFloor}';
    final ref = FirebaseFirestore.instance.collection('maps').doc(mapId);

    final doc = await ref.get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final circlesString = data['circles'];
      final circlesJson = jsonDecode(circlesString) as List;
      final loadedCircles =
      circlesJson.map((circleJson) => Circle.fromJson(circleJson)).toList();

      setState(() {
        circles = loadedCircles;
      });

      _announceNumberOfCircles(); // Announce the number of circles
    }
  }

  _generateFloorOptions(int floors) {
    floorOptions.clear();

    for (int i = 1; i <= floors; i++) {
      floorOptions.add('Floor $i');
    }
    // Initially select the first floor
    selectedFloor = floorOptions[0];
  }

  Future<void> _checkAndDownloadImage() async {
    final imageName = '${widget.profileName}_${selectedFloor}_map.png';
    final ref = FirebaseStorage.instance.ref().child('maps').child(imageName);

    // Checking if the image exists
    try {
      final result = await ref.getDownloadURL();

      setState(() {
        hasImage = true;
        uploadedImage = Image.network(result.toString()); // Using the image from Firebase Storage
      });
    } catch (e) {
      print('Error fetching image: $e');
      setState(() {
        hasImage = false;
      });
    }

    _loadCirclesFromFirebase();
  }

  void _handleTouch(Offset touchPosition) {
    bool didVibrate = false;

    if(isNavigationMode){
      for (var circle in circles) {
        // Check if the circle's audio has ended recently
        DateTime? lastAudioEnd = lastAudioEndTime[circle.name];
        if (lastAudioEnd != null) {
          DateTime now = DateTime.now();
          Duration timeSinceLastAudioEnd = now.difference(lastAudioEnd);

          // If the duration since the last audio end is less than 5 seconds, do not vibrate
          if (timeSinceLastAudioEnd.inSeconds < 10) {
            continue;  // Skip to the next circle
          }
        }

        double distance = (circle.position - touchPosition).distance;
        double effectiveSize = circle.size;

        // Conditionally extend the size for small circles
        if (circle.size < 15) {
          effectiveSize = circle.size + 5.0;  // Increase the size by 5 units for easier touching
        }

        if (distance < effectiveSize) {
          // Inside the effective circle area
          _readOutCircleInfo(circle);
        }

        if (distance < circle.size) {
          // Inside the circle
          _readOutCircleInfo(circle); // Function to read out the circle's name and description
        } else if (distance < circle.size + 50) {
          // Approaching the circle but not inside it
          if (!didVibrate) {
            int duration = (1000 / (distance / circle.size)).toInt();

            // Ensure the vibration duration is within an acceptable range
            if (duration > 400) duration = 400;
            if (duration < 50) duration = 50;

            Vibration.vibrate(duration: duration, intensities: [1, 255]);
            didVibrate = true;
          }
        }
      }
    } else {

    }

  }

  Future<void> _readOutCircleInfo(Circle circle) async {
    final FlutterTts flutterTts = FlutterTts();

    // Stopping the vibration if it's still happening
    Vibration.cancel();

    // Check if the circle has been triggered recently
    DateTime? lastTime = lastTriggeredTime[circle.name];
    if (lastTime != null) {
      DateTime now = DateTime.now();
      Duration timeSinceLastTrigger = now.difference(lastTime);

      // If the duration since the last trigger is less than 10 seconds, do not trigger again
      if (timeSinceLastTrigger.inSeconds < 10) {
        return;
      }
    }

    // Update the last triggered time for this circle
    if (circle.name != null) {
      lastTriggeredTime[circle.name!] = DateTime.now();
    } else {
      // Handle the null case. Perhaps log an error or throw an exception.
    }

    String textToRead = "This is ${circle.name}. ${circle.description}";
    await flutterTts.speak(textToRead);

    // Update the last audio end time for this circle
    if (circle.name != null) {
      lastAudioEndTime[circle.name!] = DateTime.now();
    }

  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('View ${widget.profileName}')),
      body: GestureDetector(
        onPanUpdate: (details) {
          _handleTouch(details.localPosition);
        },
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(widget.profileName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      DropdownButton<String>(
                        value: selectedFloor,
                        items: floorOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            selectedFloor = newValue;
                          });
                          _checkAndDownloadImage();
                          _announceNumberOfCircles();
                        },
                      ),
                      Row(
                        children: [
                          Text(isNavigationMode ? 'Nav Mode' : 'Guide Mode'),
                          Switch(
                            value: isNavigationMode,
                            onChanged: (bool value) {
                              setState(() {
                                isNavigationMode = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: hasImage && uploadedImage != null
                      ? Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height / 2,
                    child: Image(
                      image: uploadedImage!.image,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),
                  )
                      : Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height / 2,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        "Please upload a map.",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ...circles.map((circle) {
              return Positioned(
                left: circle.position.dx,
                top: circle.position.dy,
                child: Container(
                  width: circle.size,
                  height: circle.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: circle.selected == true ? Colors.green : Colors.blue,
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class _WelcomePageState extends State<WelcomePage> {
  List<Offset> _buttonPositions = [];
  List<Room> _rooms = [];
  double _circleSize = 30.0;

  @override
  void initState() {
    super.initState();
    // _loadData();
  }

  // void _updateData(List<Offset> buttonPositions, double circleSize, List<Room> rooms) {
  //   setState(() {
  //     _buttonPositions = buttonPositions;
  //     _circleSize = circleSize;
  //     _rooms = rooms;
  //   });
  // }

  // void _loadData() async {
  //   SharedPreferences _prefs = await SharedPreferences.getInstance();
  //   List<String>? roomNames = _prefs.getStringList('roomNames');
  //   List<String>? roomDescriptions = _prefs.getStringList('roomDescriptions');
  //   List<String>? buttonPositions = _prefs.getStringList('buttonPositions');
  //   double? circleSize = _prefs.getDouble('circleSize');
  //
  //   if (roomNames != null && roomDescriptions != null && buttonPositions != null && circleSize != null) {
  //     setState(() {
  //       _rooms.clear();
  //       _buttonPositions.clear();
  //       _circleSize = circleSize;
  //
  //       for (int i = 0; i < roomNames.length && i < roomDescriptions.length; i++) {
  //         _rooms.add(Room(roomName: roomNames[i], roomDescription: roomDescriptions[i]));
  //       }
  //       for (String positionString in buttonPositions) {
  //         List<String> parts = positionString.split(',');
  //         double x = double.tryParse(parts[0]) ?? 0.0;
  //         double y = double.tryParse(parts[1]) ?? 0.0;
  //         _buttonPositions.add(Offset(x, y));
  //       }
  //     }); // Close setState here
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Welcome'),
        ),
        body: Center(
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
        ElevatedButton(
        onPressed: () {
      Navigator.push(
          context,
        MaterialPageRoute(builder: (context) => ChooseProfilePage()),
      );
        },
          child: Text('User'),
        ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AdminPage()),
              );
            },
            child: Text('Admin'),
          ),
        ],
        ),
        ),
    );
  }
}

class UserPage extends StatelessWidget {
  final List<Offset> buttonPositions;
  final double circleSize;
  final List<Room> rooms;

  UserPage({
    required this.buttonPositions,
    required this.circleSize,
    required this.rooms,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User'),
      ),
      body: LabelsMap(
        buttonPositions: buttonPositions,
        circleSize: circleSize,
        rooms: rooms,
      ),
    );
  }
}

class AdminPage extends StatefulWidget {
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreateProfilePage()),
                );
              },
              child: Text('Create New Profile'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditProfilePage()),
                );
              },
              child: Text('Edit Existing Profile'),
            ),
          ],
        ),
      ),
    );
  }
}

// class AdminPage extends StatefulWidget {
//   final Function(List<Offset>, double, List<Room>) onUpdate;
//
//   AdminPage({required this.onUpdate});
//
//   @override
//   _AdminPageState createState() => _AdminPageState();
// }

// class _AdminPageState extends State<AdminPage> {
//   List<Offset> _buttonPositions = [];
//   List<Room> _rooms = []; // Add a list to store room information //store information in circle
//   double _circleSize = 30.0; // Add a field to store the size of the circle
//
//   late SharedPreferences _prefs;
//
//   // Future<void> clearSharedPreferences() async {
//   //   _prefs = await SharedPreferences.getInstance();
//   //   _prefs.clear();
//   //   print("Done");
//   // }
//
//   Future<void> _initPrefs() async {
//     _prefs = await SharedPreferences.getInstance();
//     _loadData();
//
//
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     // clearSharedPreferences();
//     _initPrefs().then((_) {
//       _saveData();
//
//     });
//
//   }
//
//   void _saveData() async {
//
//     print('Saving Data');
//
//     _prefs = await SharedPreferences.getInstance();
//
//     // await _initPrefs();
//
//     List<String> roomNames = [];
//     List<String> roomDescriptions = [];
//     List<String> buttonPositions = [];
//
//
//
//     // Store room information and button positions in separate lists
//     for (Room room in _rooms) {
//       roomNames.add(room.roomName);
//       roomDescriptions.add(room.roomDescription);
//     }
//     for (Offset position in _buttonPositions) {
//       buttonPositions.add('${position.dx},${position.dy}');
//     }
//
//     // Store data in shared preferences
//     _prefs.setStringList('roomNames', roomNames);
//     _prefs.setStringList('roomDescriptions', roomDescriptions);
//     _prefs.setStringList('buttonPositions', buttonPositions);
//     _prefs.setDouble('circleSize', _circleSize);
//     widget.onUpdate(_buttonPositions, _circleSize, _rooms);
//   }
//
//   void _loadData() {
//
//     List<String>? roomNames = _prefs.getStringList('roomNames');
//     List<String>? roomDescriptions = _prefs.getStringList('roomDescriptions');
//     List<String>? buttonPositions = _prefs.getStringList('buttonPositions');
//     double? circleSize = _prefs.getDouble('circleSize');
//
//     if (roomNames != null && roomDescriptions != null && buttonPositions != null && circleSize != null) {
//       setState(() {
//         _rooms.clear();
//         _buttonPositions.clear();
//         _circleSize = circleSize;
//
//         for (int i = 0; i < roomNames.length && i < roomDescriptions.length; i++) {
//           _rooms.add(Room(roomName: roomNames[i], roomDescription: roomDescriptions[i]));
//         }
//         for (String positionString in buttonPositions) {
//           List<String> parts = positionString.split(',');
//           double x = double.tryParse(parts[0]) ?? 0.0;
//           double y = double.tryParse(parts[1]) ?? 0.0;
//           _buttonPositions.add(Offset(x, y));
//           print("hi");
//         }
//       }); // Close setState here
//     }
//   }
//
//   // Function to update the circle size
//   void _updateCircleSize(double newSize) {
//     setState(() {
//       _circleSize = newSize;
//       // _buttonPositions.clear(); //clear all the button
//       // _rooms.clear();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Admin'),
//       ),
//       body: Stack(
//         children: [
//           Center(
//             child: Image.asset(
//               'assets/images/MAB.png',
//               fit: BoxFit.contain,
//             ),
//           ),
//           Positioned(
//             left: 0,
//             right: 0,
//             bottom: 20,
//             child: Center(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   ElevatedButton(
//                     onPressed: () {
//                       setState(() {
//                         _buttonPositions.add(Offset.zero);
//                         _rooms.add(Room(roomName: '', roomDescription: '')); // Initialize new room
//                       });
//                     },
//                     child: Text('Label'),
//                   ),
//                   Slider(
//                     min: 10,
//                     max: 100,
//                     divisions: 20,
//                     value: _circleSize,
//                     onChanged: (double newValue) {
//                       _updateCircleSize(newValue);
//                     },
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       _saveData();
//                     },
//                     child: Text('Save'),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           ..._buttonPositions
//               .asMap()
//               .entries
//               .map(
//                 (entry) =>
//                     Positioned(
//                       left: entry.value.dx,
//                       top: entry.value.dy,
//                       child: Listener(
//                         onPointerMove: (PointerMoveEvent event) {
//                           setState(() {
//                             _buttonPositions[entry.key] += event.delta;
//                           });
//                         },
//                         child: ClipOval(
//                           child: ElevatedButton(
//                             onPressed: () async {
//                               Room? updatedRoom = await _showRoomDialog(context, _rooms[entry.key]);
//                               if (updatedRoom != null) {
//                                 setState(() {
//                                   _rooms[entry.key] = updatedRoom;
//                                 });
//                               }
//                             },
//                             child: Container(),
//                             style: ElevatedButton.styleFrom(
//                               primary: Colors.blue,
//                               padding: EdgeInsets.zero,
//                               minimumSize: Size(_circleSize, _circleSize),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//           ),
//         ],
//       ),
//     );
//   }
// }

//description for the circle
class Room {
  String roomName;
  String roomDescription;

  Room({required this.roomName, required this.roomDescription});
}

// show a custom dialog with two text fields
Future<Room?> _showRoomDialog(BuildContext context, Room room) async {
  TextEditingController roomNameController = TextEditingController(text: room.roomName);
  TextEditingController roomDescriptionController = TextEditingController(text: room.roomDescription);

  String roomName = '';
  String roomDescription = '';

  return showDialog<Room>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Enter Room Details'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              TextField(
                controller: roomNameController,
                decoration: InputDecoration(labelText: 'Room Name'),
              ),
              TextField(
                controller: roomDescriptionController,
                decoration: InputDecoration(labelText: 'Room Description'),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop(null);
            },
          ),
          TextButton(
            child: Text('Save'),
            onPressed: () {
              Navigator.of(context).pop(Room(
                roomName: roomNameController.text,
                roomDescription: roomDescriptionController.text,
              ));
            },
          ),

        ],
      );
    },
  );
}

// receives the button positions, circle size, and rooms information as arguments
class LabelsMap extends StatelessWidget {
  final List<Offset> buttonPositions;
  final double circleSize;
  final List<Room> rooms;

  LabelsMap({
    required this.buttonPositions,
    required this.circleSize,
    required this.rooms,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Image.asset(
            'assets/images/MAB.png',
            fit: BoxFit.contain,
          ),
        ),
        ...buttonPositions
            .asMap()
            .entries
            .map(
              (entry) => Positioned(
            left: entry.value.dx,
            top: entry.value.dy,
            child: ClipOval(
              child: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text(rooms[entry.key].roomName),
                        content: Text(rooms[entry.key].roomDescription),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text('Close'),
                          ),
                        ],
                      );
                    },
                  );
                  _speak('${rooms[entry.key].roomName}. ${rooms[entry.key].roomDescription}', onComplete: () {
                    Navigator.pop(context);
                  });
                },
                child: Container(),
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue,
                  padding: EdgeInsets.zero,
                  minimumSize: Size(circleSize, circleSize),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}



