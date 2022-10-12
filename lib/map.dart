import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(const MapPage());

class MapPage extends StatelessWidget {
  const MapPage({Key? key}) : super(key: key);
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
        body: MapPage2(title: '現在位置を表示'),
    );
  }
}

class MapPage2 extends StatefulWidget {
  const MapPage2({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  State<MapPage2> createState() => _MapPage2State();
}

class _MapPage2State extends State<MapPage2> {
  Completer<GoogleMapController> _controller = Completer();

  late LatLng _initialPosition;
  late bool _loading;

  @override
  void initState() {
    super.initState();
    _loading = true;
    _getUserLocation();
  }

  void _getUserLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _initialPosition = LatLng(position.latitude, position.longitude);
      _loading = false;
      print(position);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? CircularProgressIndicator()
          : SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 14.4746,
              ),
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
              // markers: _createMarker(),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapToolbarEnabled: false,
              buildingsEnabled: true,
              onTap: (LatLng latLang) {
                print('Clicked: $latLang');
              },
            ),
            //buildFloatingSearchBar(),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(widget.title),
      ),
    );
  }
}
