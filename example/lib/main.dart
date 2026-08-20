import 'dart:ui';

import 'package:blob_flutter/blob_flutter.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const ParticleBlobExampleApp());
}

/// Root application widget for the 3D Particle Blob demonstration.
class ParticleBlobExampleApp extends StatelessWidget {
  const ParticleBlobExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlobFlutter 3D Control Center',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF060911),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ListView(
          children: [
             for(int i = 1 ; i< 5 ; i++)
              Container(
            height: 200,
            color: Colors.black,
            ),
            SizedBox(
              height: 600,
              child: BlobFlutter(
                controller:BlobController(
                  
                ) ,
                  particleCount: 1000,
                  radius: 200,
                  pointSize: 1.5,
                  colorAnimationSpeed: 0,


                  noiseType: BlobNoiseType.simplex,
                  waveIntensity: 2,
                  enableHover: true,
                  gradient: const LinearGradient(
                    colors: [Colors.cyanAccent, Colors.purpleAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                
              ),
            ),
          for(int i = 1 ; i< 10 ; i++)
           Container(
            height: 200,
            color: Colors.black,
            )
          ],
        ),
      ),
    );
  }
}
