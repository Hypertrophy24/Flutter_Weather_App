import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "dotenv");
  await Firebase.initializeApp(
    options: FirebaseOptions(
      appId: dotenv.env['FIREBASE_APP_ID']!,
      apiKey: dotenv.env['FIREBASE_API_KEY']!,
      projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
      authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN']!,
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
    ),
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Tab4(),
    );
  }
}

class Tab4 extends StatefulWidget {
  @override
  _Tab4State createState() => _Tab4State();
}

class _Tab4State extends State<Tab4> {
  final TextEditingController _locationController = TextEditingController();
  Map<String, dynamic>? _weatherData;
  String? _error;

  Future<void> fetchData() async {
    setState(() {
      _error = null;
      _weatherData = null;
    });

    final location = _locationController.text;
    final apiKey = dotenv.env['WEATHER_API'];
    final url = 'https://api.weatherstack.com/current?access_key=$apiKey&query=$location';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data != null && data['current'] != null) {
          setState(() {
            _weatherData = data;
            _error = null; // Reset error if data is successfully fetched
          });

          // Save weather data to Firestore
          await saveWeatherDataToFirestore(data, location);
        } else {
          setState(() {
            _error = 'Invalid weather data received';
          });
        }
      } else {
        setState(() {
          _error = 'Failed to fetch weather data: ${response.statusCode}';
        });
      }
    } catch (error) {
      setState(() {
        _error = 'Failed to fetch weather data: $error';
        _weatherData = null; // Reset weather data on error
      });
    }
  }

  Future<void> saveWeatherDataToFirestore(Map<String, dynamic> data, String location) async {
    try {
      await FirebaseFirestore.instance.collection('weatherData').add({
        'location': location,
        'weatherData': data,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      print('Failed to save weather data to Firestore: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Weather App'),
      ),
      body: Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Enter location',
              ),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: fetchData,
              child: Text('Get Weather'),
            ),
            SizedBox(height: 16.0),
            if (_error != null)
              Text(
                'Error: $_error',
                style: TextStyle(color: Colors.red),
              ),
            if (_weatherData != null && _weatherData!['current'] != null)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Weather Information',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Temperature: ${_weatherData!['current']!['temperature'] ?? 'N/A'}°C',
                      ),
                      Text(
                        'Weather: ${_weatherData!['current']!['weather_descriptions'][0] ?? 'N/A'}',
                      ),
                      Text(
                        'Feels Like: ${_weatherData!['current']!['feelslike'] ?? 'N/A'}°C',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }
}
