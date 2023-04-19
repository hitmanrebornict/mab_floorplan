import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter_tts/flutter_tts.dart';

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

class WelcomePage extends StatelessWidget {
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
                  MaterialPageRoute(builder: (context) => UserPage()),
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
  @override
  Widget build(BuildContext context) {
    return FloorPlanScreen();
  }
}

class AdminPage extends StatefulWidget {
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<Offset> _buttonPositions = [];
  List<Room> _rooms = []; // Add a list to store room information //store information in circle
  double _circleSize = 30.0; // Add a field to store the size of the circle

  // Function to update the circle size
  void _updateCircleSize(double newSize) {
    setState(() {
      _circleSize = newSize;
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
                    divisions: 10,
                    value: _circleSize,
                    onChanged: (double newValue) {
                      _updateCircleSize(newValue);
                    },
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
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _buttonPositions[entry.key] += details.delta;
                      });
                    },
                    child: ClipOval(
                      child: ElevatedButton(
                            onPressed: () async {Room? updatedRoom = await _showRoomDialog(context, _rooms[entry.key]);
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

class FloorPlanScreen extends StatefulWidget {
  @override
  _FloorPlanScreenState createState() => _FloorPlanScreenState();
}

class _FloorPlanScreenState extends State<FloorPlanScreen> {
  List<Label> roomLabels = [
    Label(position: Offset(100, 50), roomName: 'A', description: 'This is Room A.'),
    Label(position: Offset(200, 150), roomName: 'B', description: 'This is Room B.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Floorplan App'),
      ),
      body: Center(
        child: Stack(
          children: [
            Image.asset('assets/images/MAB.png'),
            ...roomLabels,
          ],
        ),
      ),
    );
  }
}

  Widget _buildRoomLabel(RoomLabel roomLabel) {
    return Positioned(
      left: roomLabel.x,
      top: roomLabel.y,
      child: Container(
        padding: EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Text(roomLabel.text),
      ),
    );
  }


class RoomLabel {
  final double x;
  final double y;
  final String text;

  RoomLabel({required this.x, required this.y, required this.text});
}

class RoomDetails extends StatelessWidget {
  final String roomName;
  final String description;

  const RoomDetails({required this.roomName, required this.description, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(roomName),
      content: Text(description),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }
}

void _showRoomDetails(BuildContext context, String roomName, String description) {

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return RoomDetails(roomName: roomName, description: description);
    },
  );

  _speak(description, onComplete: () {
    Navigator.of(context).pop();
  });
}

class Label extends StatefulWidget {
  final Offset position;
  final String roomName;
  final String description;

  Label({
    required this.position,
    required this.roomName,
    required this.description,
    Key? key,
  }) : super(key: key);

  @override
  _LabelState createState() => _LabelState();
}

class _LabelState extends State<Label> {
  bool _isHovered = false;

  void _onPointerDown(PointerDownEvent event) {
    if (!_isHovered) {
      setState(() {
        _isHovered = true;
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_isHovered) {
      setState(() {
        _isHovered = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isHovered) {
      _showRoomDetails(context, widget.roomName, widget.description);
      _speak(widget.description, onComplete: () {
        Navigator.of(context).pop();
      });
    }

    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        child: Container(
          width: 40,
          height: 20,
          padding: EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Center(
            child: Text(
              widget.roomName,
              style: TextStyle(fontSize: 12.0),
            ),
          ),
        ),
      ),
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