import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_button.dart';
import '../../core/widgets/espoti_logo.dart';
import '../../core/widgets/espoti_text_field.dart';

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/services/analytics_service.dart';
import '../../core/services/routing_service.dart';
import '../../core/services/place_search_service.dart';

//Esto lo pongo para tener un mapa real :D
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

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
  late DateTime _horaEntrada;

  @override
  void initState() {
    super.initState();
    // REGISTRO DE TIEMPO: Hora exacta de entrada a la pantalla
    _horaEntrada = DateTime.now();
  }

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
        break;
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
              const Text(
                AppStrings.selectYourLocation,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppDimensions.paddingS),
              _LocationMapPreview(
                onLocationSelected: (LatLng point) {
                  setState(() {
                    _selectedLocation = point;
                  });
                  debugPrint(
                      'Ubicación de reunión guardada: ${point.latitude}, ${point.longitude}');
                },
              ),
              const SizedBox(height: AppDimensions.paddingXL),

              Center(
                child: EspotiButton(
                  label: AppStrings.schedule,
                  variant: EspotiButtonVariant.secondary,
                  width: 160,
                  onPressed: _selectedLocation == null
                      ? null
                      : () {
                          // CÁLCULO DE TIEMPO: Hora de salida al presionar el botón y diferencia en segundos enviada a AnalyticsService
                          final horaSalida = DateTime.now();
                          final diferenciaSegundos = horaSalida.difference(_horaEntrada).inSeconds;
                          AnalyticsService().logStepTime(
                            stepName: 'creacion_reunion_paso_1_formulario',
                            durationSeconds: diferenciaSegundos,
                          );

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
          onTap: () {},
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
  LatLng? _userGpsPosition;
  LatLng _mapCenter = const LatLng(4.6097, -74.0817);
  bool _isLoading = true;
  bool _isLoadingRoute = false;
  List<LatLng> _routePoints = [];
  String? _suggestionText;
  double? _distanceKm;
  final MapController _mapController = MapController();

  final TextEditingController _searchController = TextEditingController();
  List<PlaceSuggestion> _suggestions = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _getCurrentGPSLocation();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() {
        _isSearching = true;
      });

      final results = await PlaceSearchService().searchPlaces(
        query,
        userLocation: _userGpsPosition ?? _mapCenter,
      );

      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    });
  }

  void _seleccionarLugar(PlaceSuggestion suggestion) {
    setState(() {
      _searchController.text = suggestion.title;
      _suggestions = [];
      _selectedPosition = suggestion.point;
    });

    FocusScope.of(context).unfocus();
    _mapController.move(suggestion.point, 15.5);

    if (widget.onLocationSelected != null) {
      widget.onLocationSelected!(suggestion.point);
    }
    _actualizarRutaYSugerencia(suggestion.point);
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
        _userGpsPosition = latLng;
        _mapCenter = latLng;
        _isLoading = false;
      });

      if (_selectedPosition != null) {
        _actualizarRutaYSugerencia(_selectedPosition!);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<LatLng>> getRoutePoints(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
      '?overview=full&geometries=geojson',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List coordinates = data['routes'][0]['geometry']['coordinates'];
      return coordinates.map((c) => LatLng(c[1], c[0])).toList();
    }
    return [];
  }

  // Algoritmo de sugerencia según la distancia recorrida
  String _obtenerSugerencia(double distanciaKm) {
    if (distanciaKm < 1.5) {
      return 'Sugerencia: Ir a pie (aprox. 15 min)';
    } else if (distanciaKm <= 8.0) {
      return 'Sugerencia: Transporte Público / Bicicleta (aprox. 25 min)';
    } else {
      return 'Sugerencia: Vehículo / Taxi (aprox. 35 min)';
    }
  }

  Future<void> _actualizarRutaYSugerencia(LatLng destination) async {
    final start = _userGpsPosition ?? _mapCenter;
    setState(() {
      _isLoadingRoute = true;
    });

    try {
      final distanciaMetros = Geolocator.distanceBetween(
        start.latitude,
        start.longitude,
        destination.latitude,
        destination.longitude,
      );
      final distanciaKm = distanciaMetros / 1000.0;
      final puntos = await getRoutePoints(start, destination);

      if (mounted) {
        setState(() {
          _routePoints = puntos.isNotEmpty ? puntos : [start, destination];
          _distanceKm = distanciaKm;
          _suggestionText = _obtenerSugerencia(distanciaKm);
          _isLoadingRoute = false;
        });
      }
    } catch (_) {
      if (mounted) {
        final distanciaMetros = Geolocator.distanceBetween(
          start.latitude,
          start.longitude,
          destination.latitude,
          destination.longitude,
        );
        final distanciaKm = distanciaMetros / 1000.0;
        setState(() {
          _routePoints = [start, destination];
          _distanceKm = distanciaKm;
          _suggestionText = _obtenerSugerencia(distanciaKm);
          _isLoadingRoute = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Buscador y autocompletado de lugares y direcciones
        Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Buscar lugar o dirección (ej. Centro Comercial)...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Color.fromARGB(255, 143, 64, 11),
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _suggestions = [];
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),

        // Indicador de búsqueda activa
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.only(bottom: 6.0),
            child: LinearProgressIndicator(
              color: Color(0xFFFF6B00),
              backgroundColor: AppColors.mauve30,
            ),
          ),

        // Lista de sugerencias desplegables
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFFFF6B00),
                    size: 22,
                  ),
                  title: Text(
                    suggestion.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.text,
                    ),
                  ),
                  subtitle: suggestion.subtitle.isNotEmpty
                      ? Text(
                          suggestion.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : null,
                  onTap: () {
                    _seleccionarLugar(suggestion);
                  },
                );
              },
            ),
          ),

        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildMapContent(),
        ),
        if (_isLoadingRoute)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF6B00),
                ),
              ),
            ),
          )
        else if (_suggestionText != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accent1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF6B00).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(
                  RoutingService.getSuggestionIcon(_distanceKm ?? 0.0),
                  color: AppColors.primaryBrown,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _suggestionText!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBrown,
                        ),
                      ),
                      if (_distanceKm != null)
                        Text(
                          'Distancia estimada: ${_distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMapContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.orange),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _mapCenter,
            initialZoom: 15.0,
            onTap: (tapPosition, point) {
              setState(() {
                _selectedPosition = point;
                _suggestions = [];
                _searchController.text = 'Ubicación seleccionada en mapa';
              });
              if (widget.onLocationSelected != null) {
                widget.onLocationSelected!(point);
              }
              _actualizarRutaYSugerencia(point);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.espoti',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _routePoints, // Lista de LatLng devuelta por OSRM
                  strokeWidth: 4.0,
                  color: const Color(0xFFFF6B00),
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                if (_userGpsPosition != null)
                  Marker(
                    point: _userGpsPosition!,
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBrown,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                if (_selectedPosition != null)
                  Marker(
                    point: _selectedPosition!,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.orange,
                      size: 40,
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            color: Colors.white.withValues(alpha: 0.8),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 9, color: Colors.black87),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: FloatingActionButton.small(
            backgroundColor: const Color(0xFF3D2314),
            foregroundColor: Colors.white,
            onPressed: () async {
              await _getCurrentGPSLocation();
              if (mounted) {
                _mapController.move(_mapCenter, 15.0);
              }
            },
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}
