
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

// This flutter app demonstrates an usage of the flutter_reactive_ble flutter plugin
// This app works only with BLE devices which advertise with a Nordic UART Service (NUS) UUID
Uuid _UART_UUID = Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
Uuid _UART_RX   = Uuid.parse("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
Uuid _UART_TX   = Uuid.parse("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

void main() {
  if (Platform.isAndroid) {
    WidgetsFlutterBinding.ensureInitialized();
    [
      Permission.location,
      Permission.storage,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise // I added
    ].request().then((status) {
      print("Status:" + status.toString());
      runApp( MyApp());
    });
  } else {
    runApp( MyApp());
  }

  // runApp(MyApp());
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter_reactive_ble example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter_reactive_ble UART example',),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({ Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final flutterReactiveBle = FlutterReactiveBle();
  List<DiscoveredDevice> _foundBleUARTDevices = [];
  late StreamSubscription<DiscoveredDevice> _scanStream;
  late Stream<ConnectionStateUpdate> _currentConnectionStream;
  late StreamSubscription<ConnectionStateUpdate> _connection;
  late QualifiedCharacteristic _txCharacteristic;
  late QualifiedCharacteristic _rxCharacteristic;
  late Stream<List<int>> _receivedDataStream;
  late TextEditingController _dataToSendText;
  bool _scanning = false;
  bool _connected = false;
  String _logTexts = "";
  List<String> _receivedData = [];
  int _numberOfMessagesReceived = 0;

  void initState() {
    super.initState();
    _dataToSendText = TextEditingController();
  }

  void refreshScreen() {
    setState(() {});
  }

  void _sendData() async {
    await flutterReactiveBle.writeCharacteristicWithResponse(_rxCharacteristic, value: _dataToSendText.text.codeUnits);
  }

  void onNewReceivedData(List<int> data) {
    _numberOfMessagesReceived += 1;
    _receivedData.add( "$_numberOfMessagesReceived: ${String.fromCharCodes(data)}");
    if (_receivedData.length > 5) {
      _receivedData.removeAt(0);
    }
    refreshScreen();
  }

  void _disconnect() async {
    await _connection.cancel();
    _connected = false;
    refreshScreen();
  }

  void _stopScan() async {
    await _scanStream.cancel();
    _scanning = false;
    refreshScreen();
  }

  Future<void> showNoPermissionDialog() async => showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) => AlertDialog(
      title: const Text('No location permission '),
      content: SingleChildScrollView(
        child: ListBody(
          children: const <Widget>[
            Text('No location permission granted.'),
            Text('Location permission is required for BLE to function.'),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Acknowledge'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    ),
  );

  void _startScan() async {
    bool goForIt=false;
    PermissionStatus permission;

    goForIt=true;

    if (goForIt) { //TODO replace True with permission == PermissionStatus.granted is for IOS test
      _foundBleUARTDevices = [];
      _scanning = true;
      refreshScreen();
      _scanStream =
          flutterReactiveBle.scanForDevices(withServices: [_UART_UUID]).listen((
              device) {
            if (_foundBleUARTDevices.every((element) =>
            element.id != device.id)) {
              _foundBleUARTDevices.add(device);
              refreshScreen();
            }
          }, onError: (Object error) {
            _logTexts =
            "${_logTexts}ERROR while scanning:$error \n";
            refreshScreen();
          }
          );
    }
    else {
      await showNoPermissionDialog();
    }
  }

  void onConnectDevice(index) {
    _currentConnectionStream = flutterReactiveBle.connectToAdvertisingDevice(
      id:_foundBleUARTDevices[index].id,
      prescanDuration: const Duration(seconds: 1),
      withServices: [_UART_UUID, _UART_RX, _UART_TX],
    );
    _logTexts = "";
    refreshScreen();
    _connection = _currentConnectionStream.listen((event) {
      var id = event.deviceId.toString();
      switch(event.connectionState) {
        case DeviceConnectionState.connecting:
          {
            _logTexts = "${_logTexts}Connecting to $id\n";
            break;
          }
        case DeviceConnectionState.connected:
          {
            _connected = true;
            _logTexts = "${_logTexts}Connected to $id\n";
            _numberOfMessagesReceived = 0;
            _receivedData = [];
            _txCharacteristic = QualifiedCharacteristic(serviceId: _UART_UUID, characteristicId: _UART_TX, deviceId: event.deviceId);
            _receivedDataStream = flutterReactiveBle.subscribeToCharacteristic(_txCharacteristic);
            _receivedDataStream.listen((data) {
              onNewReceivedData(data);
            }, onError: (dynamic error) {
              _logTexts = "${_logTexts}Error:$error$id\n";
            });
            _rxCharacteristic = QualifiedCharacteristic(serviceId: _UART_UUID, characteristicId: _UART_RX, deviceId: event.deviceId);
            break;
          }
        case DeviceConnectionState.disconnecting:
          {
            _connected = false;
            _logTexts = "${_logTexts}Disconnecting from $id\n";
            break;
          }
        case DeviceConnectionState.disconnected:
          {
            _logTexts = "${_logTexts}Disconnected from $id\n";
            break;
          }
      }
      refreshScreen();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
    ),
    body: SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          const Text("BLE UART Devices found:"),
          Container(
              margin: const EdgeInsets.all(3.0),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.blue,
                      width:2
                  )
              ),
              height: 100,
              child: ListView.builder(
                  itemCount: _foundBleUARTDevices.length,
                  itemBuilder: (context, index) => Card(
                      child: ListTile(
                        dense: true,
                        enabled: !((!_connected && _scanning) || (!_scanning && _connected)),
                        trailing: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            (!_connected && _scanning) || (!_scanning && _connected)? (){}: onConnectDevice(index);
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            alignment: Alignment.center,
                            child: const Icon(Icons.add_link),
                          ),
                        ),
                        subtitle: Text(_foundBleUARTDevices[index].id),
                        title: Text("$index: ${_foundBleUARTDevices[index].name}"),
                      ))
              )
          ),
          const Text("Status messages:"),
          Container(
              margin: const EdgeInsets.all(3.0),
              width:1400,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.blue,
                      width:2
                  )
              ),
              height: 90,
              child: Scrollbar(

                  child: SingleChildScrollView(
                      child: Text(_logTexts)
                  )
              )
          ),
          const Text("Received data:"),
          Container(
              margin: const EdgeInsets.all(3.0),
              width:1400,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.blue,
                      width:2
                  )
              ),
              height: 90,
              child: Text(_receivedData.join("\n"))
          ),
          const Text("Send message:"),
          Container(
              margin: const EdgeInsets.all(3.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.blue,
                      width:2
                  )
              ),
              child: Row(
                  children: <Widget> [
                    Expanded(
                        child: TextField(
                          enabled: _connected,
                          controller: _dataToSendText,
                          decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Enter a string'
                          ),
                        )
                    ),
                    MaterialButton(
                        child: Icon(
                          Icons.send,
                          color:_connected ? Colors.blue : Colors.grey,
                        ),
                        onPressed: _connected ? _sendData: (){}
                    ),
                  ]
              ))
        ],
      ),
    ),
    persistentFooterButtons: [
      Container(
        height: 35,
        child: Column(
          children: [
            if (_scanning) const Text("Scanning: Scanning") else const Text("Scanning: Idle"),
            if (_connected) const Text("Connected") else const Text("disconnected."),
          ],
        ) ,
      ),
      MaterialButton(
        onPressed: !_scanning && !_connected ? _startScan : (){},
        child: Icon(
          Icons.play_arrow,
          color: !_scanning && !_connected ? Colors.blue: Colors.grey,
        ),
      ),
      MaterialButton(
          onPressed: _scanning ? _stopScan: (){},
          child: Icon(
            Icons.stop,
            color:_scanning ? Colors.blue: Colors.grey,
          )
      ),
      MaterialButton(
          onPressed: _connected ? _disconnect: (){},
          child: Icon(
            Icons.cancel,
            color:_connected ? Colors.blue:Colors.grey,
          )
      )
    ],
  );
}








// // Copyright 2017, Paul DeMarco.
// // All rights reserved. Use of this source code is governed by a
// // BSD-style license that can be found in the LICENSE file.
//
// import 'dart:async';
// import 'dart:io';
// import 'dart:math';
//
// import 'package:flutter/material.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// import 'widgets.dart';
//
// void main() {
//   if (Platform.isAndroid) {
//     WidgetsFlutterBinding.ensureInitialized();
//     [
//       Permission.location,
//       Permission.storage,
//       Permission.bluetooth,
//       Permission.bluetoothConnect,
//       Permission.bluetoothScan,
//       Permission.bluetoothAdvertise // I added
//     ].request().then((status) {
//       print("Status:" + status.toString());
//       runApp(const FlutterBlueApp());
//     });
//   } else {
//     runApp(const FlutterBlueApp());
//   }
// }
//
// class FlutterBlueApp extends StatelessWidget {
//   const FlutterBlueApp({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       color: Colors.lightBlue,
//       home: StreamBuilder<BluetoothState>(
//           stream: FlutterBluePlus.instance.state,
//           initialData: BluetoothState.unknown,
//           builder: (c, snapshot) {
//             final state = snapshot.data;
//             if (state == BluetoothState.on) {
//               return const FindDevicesScreen();
//             }
//             return BluetoothOffScreen(state: state);
//           }),
//     );
//   }
// }
//
// class BluetoothOffScreen extends StatelessWidget {
//   const BluetoothOffScreen({Key? key, this.state}) : super(key: key);
//
//   final BluetoothState? state;
//
//   @override
//   Widget build(BuildContext context) {
//     print(state); //I added
//     return Scaffold(
//       backgroundColor: Colors.lightBlue,
//       body: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: <Widget>[
//             const Icon(
//               Icons.bluetooth_disabled,
//               size: 200.0,
//               color: Colors.white54,
//             ),
//             Text(
//               'Bluetooth Adapter is ${state != null ? state.toString().substring(15) : 'not available'}.',
//               style: Theme.of(context)
//                   .primaryTextTheme
//                   .subtitle2
//                   ?.copyWith(color: Colors.white),
//             ),
//             ElevatedButton(
//               onPressed: Platform.isAndroid
//                   ? () => FlutterBluePlus.instance.turnOn()
//                   : null,
//               child: const Text('TURN ON'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class FindDevicesScreen extends StatelessWidget {
//   const FindDevicesScreen({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Find Devices'),
//         actions: [
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               primary: Colors.black,
//               onPrimary: Colors.white,
//             ),
//             onPressed: Platform.isAndroid
//                 ? () {
//                     FlutterBluePlus.instance.turnOff().then((value) =>
//                         print("$value++++++++++++++++++")); //I added it return false!!!!
//                   }
//                 : null,
//             child: const Text('TURN OFF'),
//           ),
//         ],
//       ),
//       body: RefreshIndicator(
//         onRefresh: () => FlutterBluePlus.instance
//             .startScan(timeout: const Duration(seconds: 4)),
//         child: SingleChildScrollView(
//           child: Column(
//             children: <Widget>[
//               StreamBuilder<List<BluetoothDevice>>(
//                 stream: Stream.periodic(const Duration(seconds: 2))
//                     .asyncMap((_) => FlutterBluePlus.instance.connectedDevices),
//                 initialData: const [],
//                 builder: (context, snapshot) => Column(
//                   children: snapshot.data!
//                       .map((device) => ListTile(
//                             title: Text(device.name),
//                             subtitle: Text(device.id.toString()),
//                             trailing: StreamBuilder<BluetoothDeviceState>(
//                               stream: device.state,
//                               initialData: BluetoothDeviceState.disconnected,
//                               builder: (context, snapshot) {
//                                 if (snapshot.data ==
//                                     BluetoothDeviceState.connected) {
//                                   return ElevatedButton(
//                                     child: const Text('OPEN'),
//                                     onPressed: () => Navigator.of(context).push(
//                                         MaterialPageRoute(
//                                             builder: (context) =>
//                                                 DeviceScreen(device: device))),
//                                   );
//                                 }
//                                 return Text(snapshot.data.toString());
//                               },
//                             ),
//                           ))
//                       .toList(),
//                 ),
//               ),
//               StreamBuilder<List<ScanResult>>(
//                 stream: FlutterBluePlus.instance.scanResults,
//                 initialData: const [],
//                 builder: (context, snapshot) => Column(
//                   children: snapshot.data!
//                       .map(
//                         (result) => ScanResultTile(
//                           result: result,
//                           onTap: () => Navigator.of(context)
//                               .push(MaterialPageRoute(builder: (context) {
//                             result.device.connect();
//                             return DeviceScreen(device: result.device);
//                           })),
//                         ),
//                       )
//                       .toList(),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//       floatingActionButton: StreamBuilder<bool>(
//         stream: FlutterBluePlus.instance.isScanning,
//         initialData: false,
//         builder: (c, snapshot) {
//           if (snapshot.data!) {
//             return FloatingActionButton(
//               child: const Icon(Icons.stop),
//               onPressed: () => FlutterBluePlus.instance.stopScan(),
//               backgroundColor: Colors.red,
//             );
//           } else {
//             return FloatingActionButton(
//                 child: const Icon(Icons.search),
//                 onPressed: () => FlutterBluePlus.instance
//                     .startScan(timeout: const Duration(seconds: 4)));
//           }
//         },
//       ),
//     );
//   }
// }
//
// class DeviceScreen extends StatelessWidget {
//   const DeviceScreen({Key? key, required this.device}) : super(key: key);
//
//   final BluetoothDevice device;
//
//   List<int> _getRandomBytes() {
//     // final math = Random();
//     return [
//       // math.nextInt(255),
//       // math.nextInt(255),
//       // math.nextInt(255),
//       // math.nextInt(255)
//       255,
//       08,
//       23,
//       5
//     ];
//   }
//
//   List<Widget> _buildServiceTiles(List<BluetoothService> services) {
//     return services
//         .map(
//           (s) => ServiceTile(
//             service: s,
//             characteristicTiles: s.characteristics
//                 .map(
//                   (c) => CharacteristicTile(
//                     characteristic: c,
//                     onReadPressed: () => c.read(),
//                     onWritePressed: () async {
//                       await c.write(_getRandomBytes(), withoutResponse: true);
//                       await c.read();
//                       print(c.read().toString() + "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%");
//                     },
//                     onNotificationPressed: () async {
//                       await c.setNotifyValue(!c.isNotifying);
//                       await c.read();
//                       print(c.read().toString() + "% 2 %2%%2%%2%%%2%%2%%2%%% 2 %%");
//                     },
//                     descriptorTiles: c.descriptors
//                         .map(
//                           (d) => DescriptorTile(
//                             descriptor: d,
//                             onReadPressed: () => d.read(),
//                             onWritePressed: () => d.write(_getRandomBytes()),
//                           ),
//                         )
//                         .toList(),
//                   ),
//                 )
//                 .toList(),
//           ),
//         )
//         .toList();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(device.name),
//         actions: <Widget>[
//           StreamBuilder<BluetoothDeviceState>(
//             stream: device.state,
//             initialData: BluetoothDeviceState.connecting,
//             builder: (c, snapshot) {
//               VoidCallback? onPressed;
//               String text;
//               switch (snapshot.data) {
//                 case BluetoothDeviceState.connected:
//                   onPressed = () => device.disconnect();
//                   text = 'DISCONNECT';
//                   break;
//                 case BluetoothDeviceState.disconnected:
//                   onPressed = () => device.connect();
//                   text = 'CONNECT';
//                   break;
//                 default:
//                   onPressed = null;
//                   text = snapshot.data.toString().substring(21).toUpperCase();
//                   break;
//               }
//               return TextButton(
//                   onPressed: onPressed,
//                   child: Text(
//                     text,
//                     style: Theme.of(context)
//                         .primaryTextTheme
//                         .button
//                         ?.copyWith(color: Colors.white),
//                   ));
//             },
//           )
//         ],
//       ),
//       body: SingleChildScrollView(
//         child: Column(
//           children: <Widget>[
//             StreamBuilder<BluetoothDeviceState>(
//               stream: device.state,
//               initialData: BluetoothDeviceState.connecting,
//               builder: (c, snapshot) => ListTile(
//                 leading: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     snapshot.data == BluetoothDeviceState.connected
//                         ? const Icon(Icons.bluetooth_connected)
//                         : const Icon(Icons.bluetooth_disabled),
//                     snapshot.data == BluetoothDeviceState.connected
//                         ? StreamBuilder<int>(
//                             stream: rssiStream(),
//                             builder: (context, snapshot) {
//                               return Text(
//                                   snapshot.hasData ? '${snapshot.data}dBm' : '',
//                                   style: Theme.of(context).textTheme.caption);
//                             })
//                         : Text('', style: Theme.of(context).textTheme.caption),
//                   ],
//                 ),
//                 title: Text(
//                     'Device is ${snapshot.data.toString().split('.')[1]}.'),
//                 subtitle: Text('${device.id}'),
//                 trailing: StreamBuilder<bool>(
//                   stream: device.isDiscoveringServices,
//                   initialData: false,
//                   builder: (c, snapshot) => IndexedStack(
//                     index: snapshot.data! ? 1 : 0,
//                     children: <Widget>[
//                       IconButton(
//                         icon: const Icon(Icons.refresh),
//                         onPressed: () => device.discoverServices(),
//                       ),
//                       const IconButton(
//                         icon: SizedBox(
//                           child: CircularProgressIndicator(
//                             valueColor: AlwaysStoppedAnimation(Colors.grey),
//                           ),
//                           width: 18.0,
//                           height: 18.0,
//                         ),
//                         onPressed: null,
//                       )
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//             StreamBuilder<int>(
//               stream: device.mtu,
//               initialData: 0,
//               builder: (c, snapshot) => ListTile(
//                 title: const Text('MTU Size'),
//                 subtitle: Text('${snapshot.data} bytes'),
//                 trailing: IconButton(
//                   icon: const Icon(Icons.edit),
//                   onPressed: () => device.requestMtu(223),
//                 ),
//               ),
//             ),
//             StreamBuilder<List<BluetoothService>>(
//               stream: device.services,
//               initialData: const [],
//               builder: (c, snapshot) {
//                 return Column(
//                   children: _buildServiceTiles(snapshot.data!),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Stream<int> rssiStream() async* {
//     var isConnected = true;
//     final subscription = device.state.listen((state) {
//       isConnected = state == BluetoothDeviceState.connected;
//     });
//     while (isConnected) {
//       yield await device.readRssi();
//       await Future.delayed(const Duration(seconds: 1));
//     }
//     subscription.cancel();
//     // Device disconnected, stopping RSSI stream
//   }
// }
//
//
//
