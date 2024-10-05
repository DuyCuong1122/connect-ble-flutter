import 'package:connect_ble/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

class ConnectionPage extends GetView<BLEController> {
  const ConnectionPage({super.key, required this.device});
  final ScanResult device;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(device.advertisementData.advName),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            controller.scannedDevices.clear();
            await device.device.disconnect();
            Get.back();
          },
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Center(
                child: Column(
                  children: [
                    const Text('Ghi dữ liệu'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller.writeDataController,
                      decoration: const InputDecoration(
                        hintText: 'Nhập dữ liệu',
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () async {
                        await controller.sendData();
                        controller.storageDataSend
                            .add(controller.writeDataController.text);
                        controller.writeDataController.clear();
                      },
                      child: const Text('Gửi'),
                    ),
                    const SizedBox(height: 10),
                    const Text('Dữ liệu đã gửi'),
                    const SizedBox(height: 10),
                    Obx(() => Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          width: MediaQuery.of(context).size.width,
                          child: SingleChildScrollView(
                            child: Column(
                              children: controller.storageDataSend
                                  .map((e) => Text(e))
                                  .toList(),
                            ),
                          ),
                        )),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        controller.storageDataSend.clear();
                      },
                      child: const Text('Xóa dữ liệu đã gửi'),
                    )
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  children: [
                    const Text('Đọc dữ liệu'),
                    const SizedBox(height: 10),
                    Obx(() => Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          width: MediaQuery.of(context).size.width,
                          child: SingleChildScrollView(
                            child: Text(controller.storageDataReceive.value),
                          ),
                        )),
                    const SizedBox(height: 10),
                    ElevatedButton(
                        onPressed: () {
                          controller.storageDataReceive.value = '';
                        },
                        child: const Text('Xóa dữ liệu đã nhận'))
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
