import 'package:flutter/material.dart';

class AudioServiceScreen extends StatelessWidget {
  const AudioServiceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Service')),
      body: const Center(child: Text('Welcome to the Audio Service')),
    );
  }
}
