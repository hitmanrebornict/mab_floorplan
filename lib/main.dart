import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
                child: Text('Add Label'),
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

  Set<String> visitedCircles = {}; // Track visited circles by their names.
  Circle? currentCircle; // The current circle the user is guided towards.

  int _pointersCount = 0; // to keep track of number of touch points
  Offset? _initialSwipePosition;
  Offset? _finalSwipePosition;

  bool hasReachedEntrance = false;
  String _currentSpokenText = "";

  @override
  void initState() {
    super.initState();
    _generateFloorOptions(widget.numberOfFloors);
    _checkAndDownloadImage();
    _loadCirclesFromFirebase();
  }

  Future<void> _announceNumberOfCircles() async {
    String textToAnnounce = "Please turn off TalkBack or VoiceOver during the navigation. You can turn them on once the navigation is end. There are ${circles.length} labels on this floor.";
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
        circles.clear();
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

  Future<void> _handleTouch(Offset touchPosition) async {
    bool didVibrate = false;
    Circle? currentCircle; // The current circle the user is guided towards.
    Set<String> visitedCircles = {}; // Track visited circles by their names.


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
        } else if (distance < circle.size + 30) {
          // Approaching the circle but not inside it
          if (!didVibrate) {
            int intensity = ((circle.size + 30- distance) / (circle.size + 30) * 255).toInt();
            intensity = intensity.clamp(1, 255);  // Ensuring that the intensity is between 1 and 255

            Vibration.vibrate(duration: 100, intensities: [intensity, intensity]);  // Using the calculated intensity
            didVibrate = true;
          }
        }
      }
    } else {

      for (var circle in circles) {
        // If the user hasn't reached the entrance, only respond to the entrance circle
        if (!hasReachedEntrance && circle.name != 'Entrance') {
          continue;
        }

        // If the circle has been visited, skip it
        if (visitedCircles.contains(circle.name)) {
          continue;
        }

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

        if (distance <= circle.size) {
          // Inside the circle

          _readOutCircleInfo(circle); // Function to read out the circle's name and description
        } else if (distance < circle.size + 30) {
          // Approaching the circle but not inside it
          if (!didVibrate) {
            int duration = (1000 / (distance / circle.size)).toInt();

            // Ensure the vibration duration is within an acceptable range
            // if (duration > 400) duration = 400;
            // if (duration < 50) duration = 50;

            Vibration.vibrate(duration: duration, intensities: [1, 255]);
            didVibrate = true;
          }
        }
        if (distance < effectiveSize) {
          // Inside the effective circle area
          await _readOutCircleInfo(circle);  // This is async to wait for completion
        }
      }
    }
  }

  Future<void> _readOutCircleInfo(Circle circle) async {
    flutterTts.awaitSpeakCompletion(true);


    print("Attempting to read out info for circle: ${circle.name}");
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

    setState(() {
      _currentSpokenText = textToRead;
    });
    await flutterTts.speak(textToRead);



    // Update the last audio end time for this circle
    if (circle.name != null) {
      lastAudioEndTime[circle.name!] = DateTime.now();
    }

    if(!isNavigationMode){
      Circle? nearest = findNearestCircle(circle.position, excluding: circle);
      if (circle.name == 'Entrance') {
        hasReachedEntrance = true;
      }

      if (visitedCircles.contains(circle.name)) {
        return;
      }

      if(nearest != null) {
        if (circle.name != null) {
          visitedCircles.add(circle.name!);
        }
        String combinedMessage = "The nearest room is ${nearest.name}.";
        print("The nearest room is ${nearest.name}.");
        print(visitedCircles);
        String direction = determineDirection(circle.position, nearest.position);
        if (direction != 'unknown') {
          combinedMessage += " Please move your finger $direction to get to ${nearest.name}.";
        }
        setState(() {
          _currentSpokenText = combinedMessage;
        });
        await flutterTts.speak(combinedMessage);
      }
      else{
        await flutterTts.speak("Guide mode has ended. You've visited all rooms.");
      }
    }
  }

  void startGuideMode() async {
    resetVisitedCircles();
    hasReachedEntrance = false;
    flutterTts.awaitSpeakCompletion(true);
    // A helper function to handle sequential speech.
    Future<void> sequentialSpeak(List<String> messages) async {
      if (messages.isEmpty) return;

      String currentMessage = messages.removeAt(0);
      await flutterTts.speak(currentMessage);

      // Set completion handler to speak the next message.
      flutterTts.setCompletionHandler(() {
        sequentialSpeak(messages);
      });
    }

    List<String> messagesToSpeak = ["Guide mode activated. Please follow the instructions."];

    // Locate the entrance circle based on its name
    Circle? entranceCircle = circles.firstWhere((c) => c.name == 'Entrance', orElse: null);

    // Start speaking the messages sequentially.
    await sequentialSpeak(messagesToSpeak);
  }

  Circle? findNearestCircle(Offset referencePoint, {Circle? excluding}) {
    Circle? nearestCircle;
    double nearestDistance = double.infinity;

    for (var circle in circles) {
      // Skip if the circle is the one being excluded
      if (excluding != null && circle.name == excluding.name) {
        continue;
      }

      // Exclude the entrance itself based on its name
      if (circle.name == 'Entrance') {
        continue;
      }

      // Exclude circles that have been visited
      if (visitedCircles.contains(circle.name)) {
        continue;
      }

      double distance = (circle.position - referencePoint).distance;

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestCircle = circle;
      }
    }

    // Add the nearest circle to the visited circles
    // if (nearestCircle != null) {
    //   visitedCircles.add(nearestCircle.name!);
    // }

    return nearestCircle;
  }

  String determineDirection(Offset from, Offset to) {
    double dx = to.dx - from.dx;
    double dy = to.dy - from.dy;

    if (dy < 0 && dx.abs() < dy.abs()) return 'top';
    if (dy > 0 && dx.abs() < dy.abs()) return 'bottom';
    if (dx < 0 && dy.abs() < dx.abs()) return 'left';
    if (dx > 0 && dy.abs() < dx.abs()) return 'right';

    // Diagonal directions
    if (dx > 0 && dy < 0) return 'top right';
    if (dx < 0 && dy < 0) return 'top left';
    if (dx > 0 && dy > 0) return 'bottom right';
    if (dx < 0 && dy > 0) return 'bottom left';

    return 'unknown';
  }

  void resetVisitedCircles() {
    visitedCircles.clear();
  }

  void _switchMode() {
    setState(() {  // Using setState to trigger a re-render with the updated mode
      isNavigationMode = !isNavigationMode; // Toggle the mode
      resetVisitedCircles();
      String mode = isNavigationMode ? "Navigation" : "Guide";
      flutterTts.speak("Switched to $mode mode."); // Inform the user about the mode change
    });
  }

  void _handleTwoFingerSwipe() {
    if (_initialSwipePosition != null && _finalSwipePosition != null) {
      if (_finalSwipePosition!.dx - _initialSwipePosition!.dx > 100) {
        // This is a right swipe
        _goToNextFloor();
      } else if (_initialSwipePosition!.dx - _finalSwipePosition!.dx > 100) {
        // This is a left swipe
        _goToPreviousFloor();
      }
    }
    _initialSwipePosition = null;
    _finalSwipePosition = null;
  }

  void _goToNextFloor() {
    if (floorOptions.indexOf(selectedFloor!) < floorOptions.length - 1) {
      setState(() {
        selectedFloor = floorOptions[floorOptions.indexOf(selectedFloor!) + 1];
        circles.clear();
      });
      _checkAndDownloadImage();
      _announceNumberOfCircles();
    } else {
      flutterTts.speak("You are on the top floor. No more floors above.");
    }
  }

  void _goToPreviousFloor() {
    if (floorOptions.indexOf(selectedFloor!) > 0) {
      setState(() {
        selectedFloor = floorOptions[floorOptions.indexOf(selectedFloor!) - 1];
        circles.clear();
      });
      _checkAndDownloadImage();
      _announceNumberOfCircles();
    } else {
      flutterTts.speak("You are on the ground floor. No more floors below.");
    }
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('View ${widget.profileName}')),
      body: Listener(
        onPointerDown: (details) {
          _pointersCount++;
          if (_pointersCount == 2) {
            _initialSwipePosition = details.position;
          }
        },
        onPointerUp: (details) {
          if (_pointersCount == 2) {
            _finalSwipePosition = details.position;
          }
           _pointersCount--;
          if (_initialSwipePosition != null && _finalSwipePosition != null) {
          _handleTwoFingerSwipe();
          }
        },
        child: GestureDetector(
          onDoubleTap: _switchMode,
          onPanUpdate: (details) {
          if (_pointersCount < 2) {
            _handleTouch(details.localPosition);
          }
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

                                // If we're switching to Guide Mode
                                if (!isNavigationMode) {
                                  startGuideMode();
                                }
                              });
                            },
                          ),
                        ],
                      )
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
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _currentSpokenText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
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
      )
    );
  }
}

class _WelcomePageState extends State<WelcomePage> {

  @override
  void initState() {
    super.initState();
  }


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
            SizedBox(height: 20), // Add a space between the buttons
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TutorialPage()),
                );
              },
              child: Text('Tutorial'),
            ),
          ],
        ),
      ),
    );
  }
}

class TutorialPage extends StatelessWidget {
  final List<String> tutorialItems = [
    'Map Customization',
    'Label',
    'Gesture',
    'Navigation mode',
    'Guide mode'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tutorial'),
      ),
      body: ListView.builder(
        itemCount: tutorialItems.length,
        itemBuilder: (BuildContext context, int index) {
          return ListTile(
            title: Text(tutorialItems[index]),
            onTap: () {
              // Handle item tap, for example:
              // Navigator.push(context, MaterialPageRoute(builder: (context) => SpecificTutorialPage(tutorialItems[index])));
              if (tutorialItems[index] == 'Gesture') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GestureTutorialPage()),
                );
              } else if (tutorialItems[index] == 'Map Customization') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MapCustomizationTutorialPage()),
                );
              } else if (tutorialItems[index] == 'Navigation mode') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NavModeTutorialPage()),
                );
              } else if (tutorialItems[index] == 'Guide mode') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GuideModeTutorialPage()),
                );
              } else if (tutorialItems[index] == 'Label') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LabelTutorialPage()),
                );
              }
            },
            trailing: Icon(Icons.arrow_forward_ios),
          );
        },
      ),
    );
  }
}

class MapCustomizationTutorialPage extends StatefulWidget {
  @override
  _MapCustomizationTutorialPageState createState() => _MapCustomizationTutorialPageState();
}

class _MapCustomizationTutorialPageState extends State<MapCustomizationTutorialPage> {
  List<String> tutorialSteps = [
    "1. Navigating to the Edit Map Page:\n\nWhen you want to edit a map, you'll start by navigating to the EditMapPage where the title of the page displays 'Edit (Profile Name)'.",
    "2. Selecting a Floor:\n\nAt the top of the screen, you'll see a dropdown menu. This menu lists all available floors. To select a floor to edit, tap on the dropdown menu, choose the desired floor (e.g., 'Floor 1', 'Floor 2'), and the selection will be updated. After selecting a floor, the app will automatically check and download an existing image of the map, if available.",
    "3. Uploading an Image for the Map:\n\nNext to the floor dropdown, you'll find an Upload Image button. Tapping on this button will allow you to choose an image from your device's gallery. Once an image is selected, it will be displayed on the screen inside a red-bordered container. Note: If you don't upload an image, you'll see a message prompting you to 'Please upload a map.'",
    "4. Adding Labels to the Map:\n\nAt the bottom left of the screen, there's an Add Label button. Tapping this button will add a blue label to the map image's top-left corner. You can tap on any existing label to access more options.",
    "5. Editing label Information:\n\nOnce a label is added, tap on it to open a modal with three options: Move: This allows you to drag the label around the map. Edit: Opens a dialog where you can set the label's 'Name' and 'Description'. Delete: This will remove the label from the map.",
    "6. Resizing the label:\n\nPinch in/out on a selected label (the green one) to resize it. The label will respect the minimum and maximum size limits while resizing.",
    "7. Saving the Edits:\n\nAfter making all the desired changes, tap on the Save & Exit button at the bottom right of the screen. This will save the labels' information to Firebase and return you to the previous screen."
  ];

  int currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Map Customization Tutorial")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tutorialSteps[currentStep].split(":")[0] + ":",
                      style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.0),
                    Text(tutorialSteps[currentStep].split(":").sublist(1).join(":").trim()),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: currentStep > 0
                      ? () {
                    setState(() {
                      currentStep--;
                    });
                  }
                      : null,
                  child: Text("Previous"),
                ),
                ElevatedButton(
                  onPressed: currentStep < tutorialSteps.length - 1
                      ? () {
                    setState(() {
                      currentStep++;
                    });
                  }
                      : null,
                  child: Text("Next"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GuideModeTutorialPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Guide Mode Tutorial'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            Text(
              "When you're using the app in 'guide mode', you'll need to pause your TalkBack or VoiceOver for a bit. But don't worry! The app will still talk to you and guide you as you explore the map.",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Text(
              "In guide mode, we've turned off all the labels except for one - the entrance. To find it, use your finger to explore around the screen until your phone vibrates - that means you're close! Keep moving your finger towards where the vibration is strongest, that's where the entrance label is. When you hover over this spot, the app will tell you all about it out loud.",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              "Once found, our guide takes over and leads you from label to label on our map - just like a real-life tour guide! It'll take you through each point of interest one by one until everything has been visited. After visiting all points of interest on our map, a voice prompt will let know that 'guide mode' has ended.",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              "If want to switch back into navigation mode, just double tap anywhere on the screen. If there are multiple floors or levels in this location, swipe left or right: swiping left takes down one floor while swiping right takes up one floor.",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Text(
              "When done exploring with guide mode, remember to turn TalkBack or VoiceOver back on so they can help navigate other parts of your phone again.",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class NavModeTutorialPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Navigation Mode Tutorial'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            Text(
              "When you're using the navigation mode, you'll need to pause your TalkBack or VoiceOver for a bit. But don't worry! The app will still talk to you and guide you as you explore the map.",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Text(
              "You can use your finger to feel around the screen, just like exploring a real map with your hands. If there's something important nearby on the map - we call these 'labels' - your phone will vibrate to let you know.",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              "Try moving your finger towards the vibration until it gets stronger - that means you've found a label! When you hover over this spot, the app will tell you all about it out loud. This way, by listening carefully, you can learn about what's around in that part of the map.",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              "If want to switch from exploring mode ('navigation mode') into guide mode, just double tap anywhere on the screen. If there are multiple floors or levels in this location, swipe left or right: swiping left takes you down one floor while swiping right takes up one floor.",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Text(
              "Once done exploring and learning about what's around on our app's map feature, remember to turn TalkBack or VoiceOver back on so they can help navigate other parts of your phone again.",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class LabelTutorialPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Labels on the Map'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            Text(
              "In the app, you'll come across different circles on the map. These circles are known as Labels. Each label serves as a beacon of information about specific locations or points of interest on the map. Here's what you need to know:",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Text(
              "Information within Labels:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "- Name: A short identifier or title for the location or point of interest.",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              "- Description: A more detailed explanation or information about that specific point.",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Text(
              "Interacting with Labels:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "- Vibration Feedback: As you get closer to a label, your device will start to vibrate. The intensity of the vibration will increase as you approach the center of the label.",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              "- Audio Information: When you hover over a label, the app will read out the information stored in it. You'll hear the name of the location or point of interest followed by its description. This audio guide ensures you understand the significance of the point you're currently at.",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class GestureTutorialPage extends StatelessWidget {
  final List<String> gestureItems = [
    'Double Tap',
    'Two Finger Swipe',  // Added this
    // Add more gestures here if needed
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gesture Tutorial'),
      ),
      body: ListView.builder(
        itemCount: gestureItems.length,
        itemBuilder: (BuildContext context, int index) {
          return ListTile(
            title: Text(gestureItems[index]),
            onTap: () {
              if (gestureItems[index] == 'Double Tap') {
                _showDoubleTapDialog(context);
              } else if (gestureItems[index] == 'Two Finger Swipe') {
                _showTwoFingerSwipeDialog(context);  // Added this
              }
              // Handle other gesture taps here
            },
            trailing: Icon(Icons.arrow_forward_ios),
          );
        },
      ),
    );
  }

  _showDoubleTapDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Double Tap'),
        content: Text(
            'Double tapping allows you to quickly switch between modes. When in guide mode, double tap to switch to navigation mode and vice versa.'
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Close'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          )
        ],
      ),
    );
  }

  _showTwoFingerSwipeDialog(BuildContext context) {  // New method
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Two Finger Swipe'),
        content: Text(
            'Use a two-finger swipe gesture to navigate between floors. Swipe right with two fingers to move to the next floor and swipe left to move to the previous floor.'
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Close'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          )
        ],
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





