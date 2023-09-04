
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';


class BluetoothDeviceListEntry extends StatelessWidget {
  final VoidCallback? onTap;
  final BluetoothDevice device;

  BluetoothDeviceListEntry({super.key, required this.onTap, required this.device});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: const Icon(Icons.devices),
      title: Text(device.name ?? "Unknown device"),
      subtitle: Text(device.address.toString()),
      trailing: MaterialButton(
        onPressed: onTap,
        color: Colors.blue,
        child: const Text('Connect'),
      ),
    );
  }
}
