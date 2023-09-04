import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class TestPage extends StatefulWidget {


  @override
  State<TestPage> createState() => _TestPageState();
}

class _Message {
  int whom;
  String text;

  _Message(this.whom, this.text);
}

class _TestPageState extends State<TestPage> {
  static const clientID = 0;
  BluetoothConnection? connection;
  late bool _isSelected = false;

  List<_Message> messages = List<_Message>.empty(growable: true);
  String _messageBuffer = '';

  final TextEditingController textEditingController = TextEditingController();

  final ScrollController listScrollController = new ScrollController();

  bool  isConnected = true;


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
          title: (Text("test"))
      ),

      body: SafeArea(
          child: Container(
              margin: const EdgeInsets.only(top: 50),
              padding: const EdgeInsets.all(5),
              width: double.infinity,
              child: Center(
                  child: MaterialButton(
                    onPressed: isConnected
                        ? () {
                      setState(() {
                        _isSelected = !_isSelected;
                        _isSelected == true
                            ? _sendMessage('1')
                            : _sendMessage('0');
                        print(_isSelected);
                      });
                    }
                        : null,
                    color: _isSelected == true ? Colors.yellow : Colors.grey[500],
                    child: Text(_isSelected == true ? 'off' : 'on'),
                  )))),

    );
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      setState(() {
        messages.add(
          _Message(
            1,
            backspacesCounter > 0
                ? _messageBuffer.substring(
                0, _messageBuffer.length - backspacesCounter)
                : _messageBuffer + dataString.substring(0, index),
          ),
        );
        _messageBuffer = dataString.substring(index);
      });
    } else {
      _messageBuffer = (backspacesCounter > 0
          ? _messageBuffer.substring(
          0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString);
    }
  }

  void _sendMessage(String text) async {
    text = text.trim();
    textEditingController.clear();

    if (text.length > 0) {
      try {
        connection!.output.add(Uint8List.fromList(utf8.encode(text + "\r\n")));
        await connection!.output.allSent;

        setState(() {
          messages.add(_Message(clientID, text));
        });

        Future.delayed(const Duration(milliseconds: 333)).then((_) {
          listScrollController.animateTo(
              listScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 333),
              curve: Curves.easeOut);
        });
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }

//******************     send message    ******************
//   Method to send message,
// for turning the Bluetooth device on
//   void _sendOnMessageToBluetooth() async {
//     connection!.output.add(Uint8List.fromList(utf8.encode("1" + "\r\n")));
//     await connection!.output.allSent;
//     setState(() {
//       // device on
//     });
//   }
//
// // Method to send message,
// // for turning the Bluetooth device off
//   void _sendOffMessageToBluetooth() async {
//     connection!.output.add(Uint8List.fromList(utf8.encode("0" + "\r\n")));
//     await connection!.output.allSent;
//     setState(() {
//      // device off
//     });
//    }


}
