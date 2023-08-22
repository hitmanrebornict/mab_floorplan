import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';




void main() {
  runApp(FloorPlanApp());
}


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

class _WelcomePageState extends State<WelcomePage> {
  List<Offset> _buttonPositions = [];
  List<Room> _rooms = [];
  double _circleSize = 30.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _updateData(List<Offset> buttonPositions, double circleSize, List<Room> rooms) {
    setState(() {
      _buttonPositions = buttonPositions;
      _circleSize = circleSize;
      _rooms = rooms;
    });
  }

  void _loadData() async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    List<String>? roomNames = _prefs.getStringList('roomNames');
    List<String>? roomDescriptions = _prefs.getStringList('roomDescriptions');
    List<String>? buttonPositions = _prefs.getStringList('buttonPositions');
    double? circleSize = _prefs.getDouble('circleSize');

    if (roomNames != null && roomDescriptions != null && buttonPositions != null && circleSize != null) {
      setState(() {
        _rooms.clear();
        _buttonPositions.clear();
        _circleSize = circleSize;

        for (int i = 0; i < roomNames.length && i < roomDescriptions.length; i++) {
          _rooms.add(Room(roomName: roomNames[i], roomDescription: roomDescriptions[i]));
        }
        for (String positionString in buttonPositions) {
          List<String> parts = positionString.split(',');
          double x = double.tryParse(parts[0]) ?? 0.0;
          double y = double.tryParse(parts[1]) ?? 0.0;
          _buttonPositions.add(Offset(x, y));
          print("hi");
        }
      }); // Close setState here
    }
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
          MaterialPageRoute(
              builder: (context) => UserPage(
                buttonPositions: _buttonPositions,
                circleSize: _circleSize,
                rooms: _rooms,
              ),
          ),
      );
        },
          child: Text('User'),
        ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AdminPage(onUpdate: _updateData)),
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
  final Function(List<Offset>, double, List<Room>) onUpdate;

  AdminPage({required this.onUpdate});

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<Offset> _buttonPositions = [];
  List<Room> _rooms = []; // Add a list to store room information //store information in circle
  double _circleSize = 30.0; // Add a field to store the size of the circle

  late SharedPreferences _prefs;

  // Future<void> clearSharedPreferences() async {
  //   _prefs = await SharedPreferences.getInstance();
  //   _prefs.clear();
  //   print("Done");
  // }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadData();


  }

  @override
  void initState() {
    super.initState();
    // clearSharedPreferences();
    _initPrefs().then((_) {
      _saveData();

    });

  }

  void _saveData() async {

    print('Saving Data');

    _prefs = await SharedPreferences.getInstance();

    // await _initPrefs();

    List<String> roomNames = [];
    List<String> roomDescriptions = [];
    List<String> buttonPositions = [];



    // Store room information and button positions in separate lists
    for (Room room in _rooms) {
      roomNames.add(room.roomName);
      roomDescriptions.add(room.roomDescription);
    }
    for (Offset position in _buttonPositions) {
      buttonPositions.add('${position.dx},${position.dy}');
    }

    // Store data in shared preferences
    _prefs.setStringList('roomNames', roomNames);
    _prefs.setStringList('roomDescriptions', roomDescriptions);
    _prefs.setStringList('buttonPositions', buttonPositions);
    _prefs.setDouble('circleSize', _circleSize);
    widget.onUpdate(_buttonPositions, _circleSize, _rooms);
  }

  void _loadData() {

    List<String>? roomNames = _prefs.getStringList('roomNames');
    List<String>? roomDescriptions = _prefs.getStringList('roomDescriptions');
    List<String>? buttonPositions = _prefs.getStringList('buttonPositions');
    double? circleSize = _prefs.getDouble('circleSize');

    if (roomNames != null && roomDescriptions != null && buttonPositions != null && circleSize != null) {
      setState(() {
        _rooms.clear();
        _buttonPositions.clear();
        _circleSize = circleSize;

        for (int i = 0; i < roomNames.length && i < roomDescriptions.length; i++) {
          _rooms.add(Room(roomName: roomNames[i], roomDescription: roomDescriptions[i]));
        }
        for (String positionString in buttonPositions) {
          List<String> parts = positionString.split(',');
          double x = double.tryParse(parts[0]) ?? 0.0;
          double y = double.tryParse(parts[1]) ?? 0.0;
          _buttonPositions.add(Offset(x, y));
          print("hi");
        }
      }); // Close setState here
    }
  }

  // Function to update the circle size
  void _updateCircleSize(double newSize) {
    setState(() {
      _circleSize = newSize;
      // _buttonPositions.clear(); //clear all the button
      // _rooms.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin'),
      ),
      body: Stack(
        children: [
          Center(
            child: Image.asset(
              'assets/images/MAB.png',
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _buttonPositions.add(Offset.zero);
                        _rooms.add(Room(roomName: '', roomDescription: '')); // Initialize new room
                      });
                    },
                    child: Text('Label'),
                  ),
                  Slider(
                    min: 10,
                    max: 100,
                    divisions: 20,
                    value: _circleSize,
                    onChanged: (double newValue) {
                      _updateCircleSize(newValue);
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _saveData();
                    },
                    child: Text('Save'),
                  ),
                ],
              ),
            ),
          ),
          ..._buttonPositions
              .asMap()
              .entries
              .map(
                (entry) =>
                    Positioned(
                      left: entry.value.dx,
                      top: entry.value.dy,
                      child: Listener(
                        onPointerMove: (PointerMoveEvent event) {
                          setState(() {
                            _buttonPositions[entry.key] += event.delta;
                          });
                        },
                        child: ClipOval(
                          child: ElevatedButton(
                            onPressed: () async {
                              Room? updatedRoom = await _showRoomDialog(context, _rooms[entry.key]);
                              if (updatedRoom != null) {
                                setState(() {
                                  _rooms[entry.key] = updatedRoom;
                                });
                              }
                            },
                            child: Container(),
                            style: ElevatedButton.styleFrom(
                              primary: Colors.blue,
                              padding: EdgeInsets.zero,
                              minimumSize: Size(_circleSize, _circleSize),
                            ),
                          ),
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

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