import 'dart:developer';

import 'package:connect_ble/qr_code_scan.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'connection_page.dart';
import 'controller.dart';

class Homepage extends GetView<BLEController> {
  const Homepage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Test BLE"),
        centerTitle: true,
        actions: [
          TextButton(
              onPressed: () => Get.to(() => const ScanQrScreen()),
              child: const Text("Scan qr"))
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              return ListView.builder(
                itemCount: controller.scannedDevices.length,
                itemBuilder: (context, index) {
                  final deviceItem = controller.scannedDevices[index];
                  return ListTile(
                    title: Text(deviceItem.device.remoteId.toString()),
                    subtitle: Text(deviceItem.advertisementData.advName),
                    onTap: () async {
                      try {
                        await controller.connectToDevice(deviceItem.device);
                        Get.to(() => ConnectionPage(
                              device: deviceItem,
                            ));
                      } catch (e) {
                        log(e.toString());
                      }
                    },
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
