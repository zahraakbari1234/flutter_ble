import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  final FlutterBluePlus flutterBlue = FlutterBluePlus.instance ;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: MainPage(
      flutterBlue: flutterBlue

    ));
  }
}

class MainPage extends StatefulWidget {
  final FlutterBluePlus flutterBlue ;

  const MainPage({required this.flutterBlue});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {

  List<BluetoothDevice> devices = [] ;
  BluetoothDevice? selectedDevice ;

  @override
  void initState() {
    super.initState();
    scanDevices();
  }

  void scanDevices() async {
    // Start scanning
    widget.flutterBlue.startScan(timeout: Duration(seconds: 4));

// Listen to scan results
    var subscription = widget.flutterBlue.scanResults.listen((results) {
      // do something with scan results
      for (ScanResult r in results) {
        print('${r.device.name} found! rssi: ${r.rssi}');
      }
    });

// Stop scanning
    widget.flutterBlue.stopScan();


    // widget.flutterBlue.scanResults.listen((results) {
    //   for (ScanResult result in results){
    //     if(!devices.contains(result.device)){
    //       setState(() {
    //         devices.add(result.device);
    //       });
    //     }
    //   }
    // });
    //
    // widget.flutterBlue.startScan();
    // await Future.delayed(Duration(seconds: 10));
    // widget.flutterBlue.stopScan();
    //
    // print(devices);

  }


  Widget build(BuildContext context) {
    return const Placeholder();
  }
}


