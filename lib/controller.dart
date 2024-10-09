import 'dart:async';
import 'dart:developer';

import 'package:connect_ble/connection_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

class BLEController extends GetxController {
  StreamSubscription? streamSubscription; // To manage the stream
  StreamSubscription? notificationSubscription; // To manage the stream
  final writeDataController = TextEditingController();
  final readDataController = TextEditingController();
  var scannedDevices = <ScanResult>[].obs;
  Rx<BluetoothCharacteristic?> readCharacteristic =
      Rx<BluetoothCharacteristic?>(null);
  Rx<BluetoothCharacteristic?> writeCharacteristic =
      Rx<BluetoothCharacteristic?>(null);
  bool isFoundreadCharacteristic = false;
  bool isFoundwriteCharacteristic = false;
  RxString remoteId = "".obs;

  RxString storageDataReceive = "".obs;
  RxList<String> storageDataSend = <String>[].obs;
  // Start scanning for BLE devices
  Future<void> scanDevice() async {
    log('Scanning for devices...');
    scannedDevices.clear();

    // Subscribe to scan results
    streamSubscription = FlutterBluePlus.onScanResults.listen(
      (results) async {
        if (results.isNotEmpty) {
          ScanResult r = results.last; // Get the last scanned device
          log('Found device: ${r.device.remoteId}: "${r.advertisementData.advName}"');
          scannedDevices.add(r); // Add the device to the list
          await connectToDevice(scannedDevices.first.device);
          Get.off(() => ConnectionPage(
                device: scannedDevices.first,
              ));
        }
      },
      onError: (e) => log('Scan error: $e'),
    );
    FlutterBluePlus.cancelWhenScanComplete(streamSubscription!);

    await FlutterBluePlus.adapterState
        .where((state) => state == BluetoothAdapterState.on)
        .first;

    await FlutterBluePlus.startScan(
      withRemoteIds: [remoteId.value],
    );

    // Wait until scanning stops
    await FlutterBluePlus.isScanning.where((val) => val == false).first;

    streamSubscription?.cancel();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      log('Connected to ${device.remoteId}');

      List<BluetoothService> services = await device.discoverServices();
      log('Services discovered: ${services.length}');

      for (BluetoothService service in services) {
        log('Service UUID: ${service.uuid}');

        for (BluetoothCharacteristic char in service.characteristics) {
          log('Characteristic UUID: ${char.uuid}, properties: ${char.properties}');

          // Sử dụng đặc tính có notify để nhận dữ liệu
          if (char.properties.notify && isFoundreadCharacteristic == false) {
            log('Found the notify characteristic');
            readCharacteristic = Rx<BluetoothCharacteristic>(char);
            // Kích hoạt chế độ notify
            enableNotifications();
            isFoundreadCharacteristic = true;
          }

          // Sử dụng đặc tính có write để gửi dữ liệu
          if (char.properties.write && isFoundwriteCharacteristic == false) {
            log('Found the write characteristic');
            writeCharacteristic = Rx<BluetoothCharacteristic>(char);
            isFoundwriteCharacteristic = true;
          }
          if (isFoundreadCharacteristic && isFoundwriteCharacteristic) {
            break;
          }
        }
        if (isFoundreadCharacteristic && isFoundwriteCharacteristic) {
          break;
        }
      }
    } catch (e) {
      log('Error connecting to device: $e');
    }
  }

  Future<void> enableNotifications() async {
    try {
      // Lắng nghe dữ liệu được gửi từ ESP32 qua notify
      notificationSubscription?.cancel();

      await readCharacteristic.value?.setNotifyValue(true); // Kích hoạt notify
      log('Notifications enabled.');

      // Lắng nghe dữ liệu được gửi từ ESP32 qua notify
      notificationSubscription =
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

  Future<void> disableNotifications() async {
    if (readCharacteristic.value != null) {
      await readCharacteristic.value!.setNotifyValue(false);
    }
  }

  Future<void> disconnectFromDevice(BluetoothDevice device) async {
    await disableNotifications();
    await device.disconnect();
    log('Disconnected from ${device.remoteId}');
  }

  void clearData() {
    storageDataReceive.value = "";
    isFoundreadCharacteristic = false;
    isFoundwriteCharacteristic = false;
    writeCharacteristic = Rx<BluetoothCharacteristic?>(null);
    readCharacteristic = Rx<BluetoothCharacteristic?>(null);
    storageDataSend.clear();
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
    notificationSubscription?.cancel();
    super.onClose();
  }
}
