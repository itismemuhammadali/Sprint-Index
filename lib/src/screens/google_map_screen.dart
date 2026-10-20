import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sports_chat_app/src/screens/create_club_screen.dart';
import 'package:sports_chat_app/src/screens/club_profile_screen.dart';
import 'package:sports_chat_app/src/screens/location_picker_screen.dart';
import 'package:sports_chat_app/src/services/platform_service.dart';
import 'package:sports_chat_app/src/services/remote_config_service.dart';
import 'dart:math';

class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({super.key});

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  GoogleMapController? _mapController;
  double _searchRadius = 5.0;
  String _selectedSport = 'All';

  LatLng _currentLocation = const LatLng(24.8607, 67.0011);
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  bool _isLoadingLocation = false;
  bool _mapsInitialized = false;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _remoteConfig = RemoteConfigService();
  List<Map<String, dynamic>> _adminClubs = [];
  bool _isLoadingClubs = false;
  List<Map<String, dynamic>> _clubsInRadius = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    if (!_remoteConfig.isInitialized) {
      try {
        await _remoteConfig.initialize();
      } catch (e) {
        debugPrint('Error initializing Remote Config: $e');
        _showErrorDialog('Configuration Error', 'Failed to load app configuration.');
        return;
      }
    }

    final apiKey = _remoteConfig.googleMapsApiKey;
    debugPrint('Maps API Key loaded: ${apiKey.isNotEmpty ? "${apiKey.substring(0, 10)}..." : "Empty"}');

    if (apiKey.isEmpty) {
      _showErrorDialog('Maps Configuration Error', 'Google Maps API key is not configured.');
      return;
    }

    try {
      await PlatformService.setMapsApiKey(apiKey);
      setState(() {
        _mapsInitialized = true;
      });
    } catch (e) {
      debugPrint('Error setting Maps API key: $e');
      _showErrorDialog('Maps Error', 'Failed to initialize maps.');
      return;
    }

    _getCurrentLocation();
  }

  void _showErrorDialog(String title, String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    if (!mounted) return;
    _mapController = controller;

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _mapController != null) {
        _updateSearchCircle();
        _loadClubMarkers();
      }
    });
  }

  void _updateSearchCircle() {
    if (!mounted) return;

    try {
      setState(() {
        _circles.clear();
        _circles.add(
          Circle(
            circleId: const CircleId('search_radius'),
            center: _currentLocation,
            radius: _searchRadius * 1000,
            fillColor: const Color(0xFFFF8C00).withValues(alpha: 0.1),
            strokeColor: const Color(0xFFFF8C00),
            strokeWidth: 2,
          ),
        );
      });

      if (_mapController != null) {
        double zoomLevel = 15.0 - (_searchRadius / 5.0);
        zoomLevel = zoomLevel.clamp(10.0, 18.0);

        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _currentLocation,
              zoom: zoomLevel,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating search circle: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are denied'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = newLocation;
        _isLoadingLocation = false;
      });

      _updateSearchCircle();
      await _loadClubMarkers();

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _currentLocation,
              zoom: 15.0,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAdminClubs() async {
    setState(() => _isLoadingClubs = true);
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final snapshot = await _firestore
          .collection('clubs')
          .where('adminId', isEqualTo: currentUserId)
          .get();

      final clubs = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'clubName': data['clubName'] ?? 'Unnamed Club',
          'location': data['location'] ?? '',
          'latitude': data['latitude'] as double?,
          'longitude': data['longitude'] as double?,
          ...data,
        };
      }).toList();

      setState(() {
        _adminClubs = clubs;
        _isLoadingClubs = false;
      });
    } catch (e) {
      setState(() => _isLoadingClubs = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading clubs: $e')),
        );
      }
    }
  }

  Future<void> _loadClubMarkers() async {
    try {
      final snapshot = await _firestore.collection('clubs').get();

      _markers.clear();
      _clubsInRadius = [];

      _markers.add(
        Marker(
          markerId: const MarkerId('my_location'),
          position: _currentLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final latitude = data['latitude'] as double?;
        final longitude = data['longitude'] as double?;
        final sport = data['sport'] as String?;
        final clubName = data['clubName'] as String?;

        if (latitude == null || longitude == null) continue;

        if (_selectedSport != 'All' && sport != null && sport != _selectedSport) {
          continue;
        }

        final distance = _calculateDistance(
          _currentLocation.latitude,
          _currentLocation.longitude,
          latitude,
          longitude,
        );

        if (distance > _searchRadius) continue;

        _clubsInRadius.add({
          'id': doc.id,
          'clubName': clubName ?? 'Unnamed Club',
          'sport': sport ?? 'No sport',
          'location': data['location'] ?? '',
          'latitude': latitude,
          'longitude': longitude,
          'memberCount': (data['memberIds'] as List?)?.length ?? 0,
          'distance': distance,
        });

        _markers.add(
          Marker(
            markerId: MarkerId('club_${doc.id}'),
            position: LatLng(latitude, longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            onTap: () => _showClubDetails(doc.id),
          ),
        );
      }

      _clubsInRadius.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading clubs: $e')),
        );
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) *
            cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p)) /
            2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> _showClubDetails(String clubId) async {
    try {
      final clubDoc = await _firestore.collection('clubs').doc(clubId).get();
      if (!clubDoc.exists) return;

      final club = clubDoc.data()!;
      final clubName = club['clubName'] ?? 'Unnamed Club';

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClubProfileScreen(
            clubId: clubId,
            clubName: clubName,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading club: $e')),
        );
      }
    }
  }

  Future<void> _selectClubLocation(Map<String, dynamic> club) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLatitude: club['latitude'],
          initialLongitude: club['longitude'],
        ),
      ),
    );

    if (result != null && mounted) {
      try {
        await _firestore.collection('clubs').doc(club['id']).update({
          'location': result['locationName'],
          'latitude': result['latitude'],
          'longitude': result['longitude'],
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        await _loadAdminClubs();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating location: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showClubsModal() async {
    await _loadAdminClubs();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Clubs',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a club to edit its location',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoadingClubs
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF8C00),
                      ),
                    )
                  : _adminClubs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.groups,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No clubs yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _adminClubs.length,
                          itemBuilder: (context, index) {
                            final club = _adminClubs[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  _selectClubLocation(club);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              club['clubName'],
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.edit_location,
                                            color: Color(0xFFFF8C00),
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if ((club['location'] ?? '').isNotEmpty)
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on,
                                              size: 14,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                club['location'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        )
                                        else
                                          Text(
                                            'No location set',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[400],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateClubScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8C00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Create Your Own Club',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_mapsInitialized)
            SizedBox.expand(
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(24.8607, 67.0011),
                  zoom: 11.0,
                ),
                markers: _markers,
                circles: _circles,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
              ),
            )
          else
            Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF8C00),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Search Radius: ${_searchRadius.toInt()} km',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                setState(() {
                                  if (_searchRadius > 1) {
                                    _searchRadius--;
                                  }
                                });
                                _updateSearchCircle();
                                _loadClubMarkers();
                              },
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: const Color(0xFFFF8C00),
                                inactiveTrackColor: Colors.grey[300],
                                thumbColor: const Color(0xFFFF8C00),
                                overlayColor:
                                    const Color(0xFFFF8C00).withValues(alpha: 0.2),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: _searchRadius,
                                min: 1,
                                max: 50,
                                onChanged: (value) {
                                  setState(() {
                                    _searchRadius = value;
                                  });
                                  _updateSearchCircle();
                                  _loadClubMarkers();
                                },
                              ),
                            ),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                setState(() {
                                  if (_searchRadius < 50) {
                                    _searchRadius++;
                                  }
                                });
                                _updateSearchCircle();
                                _loadClubMarkers();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.sports_soccer,
                                  color: Color(0xFF2196F3),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButton<String>(
                                  value: _selectedSport,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                                  items: [
                                    'All',
                                    'Football',
                                    'Basketball',
                                    'Tennis',
                                    'Cricket',
                                    'Rugby',
                                    'Athletics/Track & Field',
                                  ].map((sport) {
                                    return DropdownMenuItem(
                                      value: sport,
                                      child: Text(
                                        sport,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedSport = value!;
                                    });
                                    _loadClubMarkers();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8C00),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showClubsModal,
                              borderRadius: BorderRadius.circular(12),
                              child: const Center(
                                child: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
              backgroundColor: Colors.white,
              child: _isLoadingLocation
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF2196F3),
                      ),
                    )
                  : const Icon(
                      Icons.my_location,
                      color: Color(0xFF2196F3),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
