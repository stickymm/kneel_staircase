import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart'; // For location services
import 'package:google_place/google_place.dart'; // For Google Places API

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iconnect Radius Mockup (coffee shop)',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyMapPage(),
    );
  }
}

class MyMapPage extends StatefulWidget {
  @override
  State<MyMapPage> createState() => MapPageState();
}

class MapPageState extends State<MyMapPage> {
  Completer<GoogleMapController> _controller = Completer();
  static const LatLng initialPosition = LatLng(38.8835, -77.1030); // Centered on Clarendon-Courthouse, Arlington
  Set<Circle> _circles = {};
  double _radius = 3218.69; // Default radius (2 miles in meters)
  Timer? _debounce;
  GooglePlace? googlePlace; // Google Places API instance
  List<AutocompletePrediction>? predictions; // Autocomplete predictions
  String selectedLocation = ''; // Selected location
  LatLng currentLocation = initialPosition; // Current location for the circle
  bool showDropdown = false; // Flag to control dropdown visibility

  @override
  void initState() {
    super.initState();
    googlePlace = GooglePlace('AIzaSyDotw4iRDMOOpXJbm0WkZbrknHo5YRmbQ8'); // Replace with your Google Places API key
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60.0), // Height of the app bar
        child: Container(
          color: Color.fromRGBO(126, 192, 112, 1), // Background color using RGB
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white), // Back arrow icon
                  onPressed: () {
                    // TODO: Implement navigation to the previous screen
                    // Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Food Assistance',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 48), // Add some space on the right
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          // New dialog box for changing location
          Container(
            height: 80, // Height of the dialog box
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        showDropdown = !showDropdown; // Toggle dropdown visibility
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Color.fromRGBO(126, 192, 112, 1)),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Center(
                        child: Text(
                          'Change location',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8), // Space between buttons
                ElevatedButton(
                  onPressed: _getCurrentLocation,
                  child: Text("Reset Map"),
                  style: ElevatedButton.styleFrom(
                    shape: StadiumBorder(),
                    backgroundColor: Color.fromRGBO(126, 192, 112, 1), // Background color
                    foregroundColor: Colors.white, // Text color
                  ),
                ),
              ],
            ),
          ),
          // Dropdown suggestions container
          if (showDropdown) ...[
            Container(
              height: 300, // Height for dropdown suggestions
              margin: EdgeInsets.symmetric(horizontal: 16.0), // Margin from edges
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text("Use my current location"),
                    leading: Icon(Icons.my_location),
                    onTap: () {
                      _getCurrentLocation();
                      setState(() {
                        showDropdown = false; // Hide dropdown after selection
                      });
                    },
                  ),
                  Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: predictions?.length ?? 0,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(predictions![index].description!),
                          onTap: () {
                            setState(() {
                              selectedLocation = predictions![index].description!;
                              // TODO: Update the map center to the selected location
                              showDropdown = false; // Hide dropdown after selection
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: initialPosition,
                zoom: 14.0,
              ),
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
                _addCircle(currentLocation);
              },
              onCameraIdle: () {
                _debounce?.cancel();
                _debounce = Timer(const Duration(seconds: 2), () {
                  _fetchCoffeeShops();
                });
              },
              circles: _circles,
            ),
          ),
          // New green bar for radius selection
          Container(
            height: 40, // Height of the new bar
            color: Color.fromRGBO(126, 192, 112, 1), // Background color
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'Radius:',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                _radiusButton("5 mi."),
                _radiusButton("10 mi."),
                _radiusButton("15 mi."),
                _radiusButton("20 mi."),
                _customRadiusButton(),
              ],
            ),
          ),
          Container(
            height: 200,
            color: Colors.white,
            child: FutureBuilder<List<CoffeeShop>>(
              future: _fetchCoffeeShops(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No coffee shops found.'));
                }

                final coffeeShops = snapshot.data!;
                return ListView.builder(
                  itemCount: coffeeShops.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(coffeeShops[index].name),
                      subtitle: Text(coffeeShops[index].address),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Function to get current location
  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Location services are not enabled
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location services are disabled.')),
        );
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
      _addCircle(currentLocation); // Update the circle on the map
    });
  }

  // Function to get place predictions
  Future<void> _getPlacePredictions(String input) async {
    if (input.isEmpty) {
      setState(() {
        predictions = null;
      });
      return;
    }

    final result = await googlePlace!.autocomplete.get(input);
    setState(() {
      predictions = result?.predictions; // Use null-aware operator
    });
  }

  // Function to create radius buttons
  Widget _radiusButton(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0), // Reduced margin
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            switch (label) {
              case "5 mi.":
                _radius = 8046.72; // 5 miles in meters
                break;
              case "10 mi.":
                _radius = 16093.44; // 10 miles in meters
                break;
              case "15 mi.":
                _radius = 24140.16; // 15 miles in meters
                break;
              case "20 mi.":
                _radius = 32176.88; // 20 miles in meters
                break;
            }
            _addCircle(currentLocation); // Update the circle on the map
          });
        },
        child: Text(label),
        style: ElevatedButton.styleFrom(
          shape: StadiumBorder(),
          backgroundColor: Colors.white, // Background color for the button
          foregroundColor: Color.fromRGBO(126, 192, 112, 1), // Text color for the button
          padding: EdgeInsets.symmetric(horizontal: 8), // Adjust padding for smaller buttons
        ),
      ),
    );
  }

  // Function to create custom radius button
  Widget _customRadiusButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0), // Reduced margin
      child: ElevatedButton(
        onPressed: () {
          _showCustomRadiusDialog();
        },
        child: Text("Custom"),
        style: ElevatedButton.styleFrom(
          shape: StadiumBorder(),
          backgroundColor: Colors.white, // Background color for the button
          foregroundColor: Color.fromRGBO(126, 192, 112, 1), // Text color for the button
          padding: EdgeInsets.symmetric(horizontal: 8), // Adjust padding for smaller buttons
        ),
      ),
    );
  }

  // Function to show custom radius dialog
  void _showCustomRadiusDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController radiusController = TextEditingController();
        return AlertDialog(
          title: Text("Enter custom radius"),
          content: TextField(
            controller: radiusController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: "Enter radius (0-100)"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                double? customRadius = double.tryParse(radiusController.text);
                if (customRadius != null && customRadius > 0 && customRadius <= 100) {
                  setState(() {
                    _radius = customRadius * 1609.34; // Convert miles to meters
                    _addCircle(currentLocation); // Update the circle on the map
                  });
                }
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text("Submit"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  void _addCircle(LatLng position) {
    _circles.clear(); // Clear existing circles before adding a new one
    _circles.add(
      Circle(
        circleId: CircleId('circle'),
        center: position,
        radius: _radius,
        fillColor: Colors.red.withOpacity(0.3),
        strokeColor: Colors.red,
        strokeWidth: 2,
      ),
    );
    setState(() {});
  }

  Future<List<CoffeeShop>> _fetchCoffeeShops() async {
    final GoogleMapController controller = await _controller.future;
    final LatLng center = currentLocation; // Get the center of the circle
    final String apiKey = 'AIzaSyDotw4iRDMOOpXJbm0WkZbrknHo5YRmbQ8'; // Replace with your API key
    final String url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${center.latitude},${center.longitude}&radius=$_radius&type=cafe&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      List<CoffeeShop> coffeeShops = [];
      for (var result in jsonResponse['results']) {
        coffeeShops.add(CoffeeShop(
          name: result['name'],
          address: result['vicinity'],
        ));
      }
      return coffeeShops;
    } else {
      throw Exception('Failed to load coffee shops');
    }
  }
}

class CoffeeShop {
  final String name;
  final String address;

  CoffeeShop({required this.name, required this.address});
}