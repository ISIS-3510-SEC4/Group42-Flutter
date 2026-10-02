import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_button.dart';
import '../../core/widgets/espoti_logo.dart';
import '../../core/widgets/espoti_text_field.dart';

//Esto lo pongo para tener un mapa real :D
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

/// "Create a meeting" screen (1). Arrive from the "+" button
/// on the bottom nav. When you press Schedule, it goes to step 2 (vote).
class CreateMeetingPage extends StatefulWidget {
  const CreateMeetingPage({super.key});

  @override
  State<CreateMeetingPage> createState() => _CreateMeetingPageState();
}

class _CreateMeetingPageState extends State<CreateMeetingPage> {
  final _activityController = TextEditingController(text: 'Eat');
  final _dayController = TextEditingController(text: 'Sunday');
  final _timeController = TextEditingController(text: '2:00 pm');
  //El ? es porque puede quedar vacía
  LatLng? _selectedLocation;

  @override
  void dispose() {
    _activityController.dispose();
    _dayController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _handleNavTap(EspotiNavItem item) {
    switch (item) {
      case EspotiNavItem.home:
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        break;
      case EspotiNavItem.meetings:
        Navigator.pushReplacementNamed(context, AppRoutes.meetings);
        break;
      case EspotiNavItem.profile:
        Navigator.pushReplacementNamed(context, AppRoutes.profile);
        break;
      case EspotiNavItem.createMeeting:
        break;
      case EspotiNavItem.friends:
        break; // TODO:  Add Friends Screen here once it exists
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.paddingM),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  EspotiLogo(height: AppDimensions.logoSizeSmall),
                  Icon(Icons.menu, color: AppColors.primaryBrown),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingL),
              Text(
                AppStrings.createAMeeting,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimensions.paddingL),

              // Who will go?
              const Text(
                AppStrings.whoWillGo,
                style: TextStyle(fontSize: 15, color: AppColors.text),
              ),
              const SizedBox(height: AppDimensions.paddingS),
              const _WhoWillGoRow(),
              const SizedBox(height: AppDimensions.paddingL),

              EspotiTextField(
                label: AppStrings.whatWillWeDo,
                controller: _activityController,
              ),
              EspotiTextField(
                label: AppStrings.whatDay,
                controller: _dayController,
              ),
              EspotiTextField(
                label: AppStrings.whatTime,
                controller: _timeController,
              ),

              const SizedBox(height: AppDimensions.paddingS),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    AppStrings.selectYourLocation,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: open location picker when it exists (google_maps_flutter / flutter_map)
                    },
                    icon:
                        const Icon(Icons.search, color: AppColors.primaryBrown),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingS),
              _LocationMapPreview(
                onLocationSelected: (LatLng point) {
                  setState(() {
                    _selectedLocation = point;
                  });
                  debugPrint('Ubicación de reunión guardada: ${point.latitude}, ${point.longitude}');
                },
              ),
              const SizedBox(height: AppDimensions.paddingXL),

              Center(
                child: EspotiButton(
                  label: AppStrings.schedule,
                  variant: EspotiButtonVariant.secondary,
                  width: 160,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.voteMeeting,
                      arguments: {
                        'activity': _activityController.text,
                        'day': _dayController.text,
                        'time': _timeController.text,
                        'location': _selectedLocation,
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppDimensions.paddingXL),
            ],
          ),
        ),
      ),
      bottomNavigationBar: EspotiBottomNavigation(
        currentItem: EspotiNavItem.createMeeting,
        onItemSelected: _handleNavTap,
      ),
    );
  }
}

class _WhoWillGoRow extends StatelessWidget {
  const _WhoWillGoRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: AppDimensions.avatarSize + 8,
          height: AppDimensions.avatarSize + 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.mauve30,
          ),
          child: const Icon(Icons.person, color: AppColors.primaryBrown),
        ),
        const SizedBox(width: AppDimensions.paddingM),
        GestureDetector(
          onTap: () {
            // TODO: open friends selector when it exists.
          },
          child: const Icon(
            Icons.add_circle,
            color: AppColors.primaryBrown,
            size: 32,
          ),
        ),
      ],
    );
  }
}

class _LocationMapPreview extends StatefulWidget {
  final Function(LatLng point)? onLocationSelected;

  const _LocationMapPreview({
    this.onLocationSelected,
  });

  @override
  State<_LocationMapPreview> createState() {
    return _LocationMapPreviewState();
  }
}

class _LocationMapPreviewState extends State<_LocationMapPreview> {
  LatLng? _selectedPosition;
  bool _isLoading = true;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _getCurrentGPSLocation();
  }

  Future<void> _getCurrentGPSLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      LatLng latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedPosition = latLng;
        _isLoading = false;
      });

      if (widget.onLocationSelected != null) {
        widget.onLocationSelected!(latLng);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildMapContent(),
    );
  }

  Widget _buildMapContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
      );
    }

    if (_selectedPosition == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: () {
            _getCurrentGPSLocation();
          },
          icon: const Icon(Icons.my_location),
          label: const Text('Obtener ubicación actual'),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _selectedPosition!,
            initialZoom: 15.0,
            onTap: (tapPosition, point) {
              setState(() {
                _selectedPosition = point;
              });
              if (widget.onLocationSelected != null) {
                widget.onLocationSelected!(point);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.espoti',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _selectedPosition!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFFFF6B00),
                    size: 40,
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: FloatingActionButton.small(
            backgroundColor: const Color(0xFF3D2314),
            foregroundColor: Colors.white,
            onPressed: () async {
              await _getCurrentGPSLocation();
              if (_selectedPosition != null && mounted) {
                _mapController.move(_selectedPosition!, 15.0);
              }
            },
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}