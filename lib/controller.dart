import 'dart:async';
import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

class BLEController extends GetxController {
  StreamSubscription? streamSubscription; // To manage the stream
  final writeDataController = TextEditingController();
  final readDataController = TextEditingController();
  var scannedDevices = <ScanResult>[].obs;
  Rx<BluetoothCharacteristic?> readCharacteristic =
      Rx<BluetoothCharacteristic?>(null);
  Rx<BluetoothCharacteristic?> writeCharacteristic =
      Rx<BluetoothCharacteristic?>(null);
  bool isFoundreadCharacteristic = false;
  bool isFoundwriteCharacteristic = false;
  Guid serviceUUID = Guid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
  Guid characteristicUUID =
      Guid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E"); // Characteristic UART
  Guid notifyCharacteristicUUID = Guid(
      "6e400003-b5a3-f393-e0a9-e50e24dcca9e"); // UUID của đặc tính có notify

  RxString storageDataReceive = "".obs;
  RxList<String> storageDataSend = <String>[].obs;
  // Start scanning for BLE devices
  Future<void> scanDevice() async {
    log('Scanning for devices...');

    scannedDevices.clear();

    // Subscribe to scan results
    streamSubscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (results.isNotEmpty) {
          ScanResult r = results.last; // Get the last scanned device
          log('Found device: ${r.device.remoteId}: "${r.advertisementData.advName}"');
          scannedDevices.add(r); // Add the device to the list
        }
      },
      onError: (e) => log('Scan error: $e'),
    );
    await FlutterBluePlus.adapterState
        .where((state) => state == BluetoothAdapterState.on)
        .first;

    await FlutterBluePlus.startScan(
      withServices: [Guid("180D")], // Optional: filter by service UUIDs
      withNames: ["UART Service"], // Optional: filter by specific device names
      timeout: const Duration(seconds: 15),
    );

    // Wait until scanning stops
    await FlutterBluePlus.isScanning.where((val) => val == false).first;
    streamSubscription?.cancel();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      log('Connecting to ${device.remoteId}');
      await device.connect();
      log('Connected to ${device.remoteId}');

      List<BluetoothService> services = await device.discoverServices();
      log('Services discovered: ${services.length}');

      for (BluetoothService service in services) {
        log('Service UUID: ${service.uuid}');

        if (service.uuid == serviceUUID) {
          log('Service with UUID found!');

          for (BluetoothCharacteristic char in service.characteristics) {
            log('Characteristic UUID: ${char.uuid}, properties: ${char.properties}');

            // Sử dụng đặc tính có notify để nhận dữ liệu
            if (char.uuid == notifyCharacteristicUUID &&
                char.properties.notify) {
              log('Found the notify characteristic');
              readCharacteristic = Rx<BluetoothCharacteristic>(char);
              // Kích hoạt chế độ notify
              enableNotifications();
              isFoundreadCharacteristic = true;
            }

            // Sử dụng đặc tính có write để gửi dữ liệu
            if (char.uuid == characteristicUUID && char.properties.write) {
              log('Found the write characteristic');
              writeCharacteristic = Rx<BluetoothCharacteristic>(char);
              isFoundwriteCharacteristic = true;
            }
            if (isFoundreadCharacteristic && isFoundwriteCharacteristic) {
              break;
            }
          }
        }
      }
    } catch (e) {
      log('Error connecting to device: $e');
    }
  }

  Future<void> enableNotifications() async {
    try {
      await readCharacteristic.value?.setNotifyValue(true); // Kích hoạt notify
      log('Notifications enabled.');

      // Lắng nghe dữ liệu được gửi từ ESP32 qua notify
      readCharacteristic.value?.onValueReceived.listen((data) {
        String receivedData = String.fromCharCodes(data);
        storageDataReceive.value += receivedData;
        log('Received data: $receivedData');
      }, onError: (error) {
        log('Error receiving data: $error');
      });
    } catch (e) {
      log('Failed to enable notifications: $e');
    }
  }

  // Send data to the connected device's characteristic
  Future<void> sendData() async {
    if (writeCharacteristic.value != null) {
      log('Sending data...');
      String data = writeDataController.text;
      List<int> bytesToSend = data.codeUnits; // Convert text to bytes
      try {
        await writeCharacteristic.value!
            .write(bytesToSend); // Write the bytes to the characteristic
        log('Data sent: $data');
      } catch (e) {
        log('Error sending data: $e');
      }
    } else {
      log('No characteristic available to send data.');
    }
  }

  @override
  void onClose() {
    streamSubscription
        ?.cancel(); // Cancel the stream when the controller is disposed
    super.onClose();
  }
}
