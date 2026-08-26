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
    return const Scaffold(
      body: Center(
        child: 
            SizedBox(
              // height: 600,
              child: BlobFlutter(
                // controller:BlobController(
                //   speed: 0,
                //   // particleCount: 
                // ) ,
                  particleCount: 10000,
                  radius: 200,
                  pointSize: 1.5,
                  speed: 1,                  
                  noiseType: BlobNoiseType.fractal,
                  waveIntensity: 5,
                  enableHover: true,
                  gradient: const LinearGradient(
                    colors: [Colors.cyanAccent, Colors.purpleAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                
              ),
            ),

          
        
      ),
    );
  }
}
