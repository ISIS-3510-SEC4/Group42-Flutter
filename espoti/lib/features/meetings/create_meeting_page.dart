import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../app/routes.dart';
import '../../core/analytics/meeting_creation_tracker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/input_limits.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/meeting_repository.dart';
import '../../core/services/place_search_service.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_button.dart';
import '../../core/widgets/espoti_text_field.dart';
import '../../core/widgets/espoti_top_bar.dart';
import '../../core/widgets/sync_status_banner.dart';
import '../../models/contact.dart';
import '../../models/meeting_record.dart';
import '../../models/transit_mode.dart';
import 'contacts_picker_sheet.dart';
import 'recommendation/meeting_schedule.dart';
import 'transit_mode_selector.dart';

/// "Create a meeting" screen (1). Arrive from the "+" button
/// on the bottom nav. When you press Schedule, the meeting is saved
/// (offline-first, see MeetingRepository) and it goes to step 2 (vote).
///
/// Edit mode: open it with `arguments: {'meetingId': id}`; Save updates the
/// same Firestore document and returns to the previous screen.
///
/// El punto de encuentro se elige de tres formas: tocando el mapa, con
/// "Use my current location" (GPS del dispositivo) o escribiendo una
/// dirección y pulsando "Search" (PlaceSearchService: Photon/Nominatim con
/// respaldo local). El campo de presupuesto se eliminó.
class CreateMeetingPage extends StatefulWidget {
  const CreateMeetingPage({super.key});

  @override
  State<CreateMeetingPage> createState() => _CreateMeetingPageState();
}

class _CreateMeetingPageState extends State<CreateMeetingPage> {
  final _activityController = TextEditingController(text: 'Eat');
  final _dayController = TextEditingController();
  final _timeController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  //El ? es porque puede quedar vacía
  LatLng? _selectedLocation;

  /// El mapa lo controla esta pantalla para poder moverlo cuando el punto
  /// llega desde el GPS o desde la búsqueda de direcciones.
  final MapController _mapController = MapController();
  bool _mapReady = false;

  // Invitees from Google Contacts.
  List<GoogleContact> _invitees = const [];

  // Sprint 2: funnel analytics.
  bool _advanced = false;

  // Sprint 3: persistence + business question type 4.
  TransitMode? _transitMode;
  String? _transitError;
  String? _activityError;
  String? _whenError;
  String? _locationError;
  bool _saving = false;
  bool _loadingExisting = false;
  bool _didReadArgs = false;
  MeetingRecord? _record; // saved meeting (new one after first Schedule)
  bool _isEditMode = false;

  // Ubicación actual y búsqueda de dirección.
  bool _locating = false;
  bool _searching = false;
  String? _addressError;
  List<PlaceSuggestion> _searchResults = const [];
  String? _pointLabel; // de dónde salió el punto (texto para el usuario)

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadArgs) return;
    _didReadArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    final meetingId = args is Map ? args['meetingId'] as String? : null;
    if (meetingId != null) {
      _isEditMode = true;
      _loadingExisting = true;
      _loadForEdit(meetingId);
    } else {
      // Planning funnel (VV2): only creating a new meeting is an attempt.
      // Edit mode is excluded, so it is never counted as started/abandoned.
      AnalyticsService()
        ..meetingPlanningStarted()
        ..stepViewed(MeetingPlanningStep.details);
    }
  }

  Future<void> _loadForEdit(String meetingId) async {
    final record = await MeetingRepository.instance.byId(meetingId);
    if (!mounted) return;
    setState(() {
      _loadingExisting = false;
      if (record == null) return;
      _record = record;
      _activityController.text = record.activity;
      _dayController.text = record.dayLabel;
      _timeController.text = record.timeLabel;
      _transitMode = record.transitMode;
      if (record.pointLat != null && record.pointLng != null) {
        _selectedLocation = LatLng(record.pointLat!, record.pointLng!);
        _pointLabel = 'Saved meeting point';
      }
      // Keep the e-mails of the invitees (older meetings only have names).
      _invitees = record.invitees.isNotEmpty
          ? [
              for (final invitee in record.invitees)
                GoogleContact(
                  id: invitee.contactId ??
                      (invitee.normalizedEmail.isNotEmpty
                          ? invitee.normalizedEmail
                          : 'name:${invitee.name}'),
                  name: invitee.name,
                  email: invitee.email,
                ),
            ]
          : [
              for (final name in record.inviteeNames)
                GoogleContact(id: 'name:$name', name: name, email: ''),
            ];
    });
    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This meeting was not found on this device.')));
    }
  }

  @override
  void initState() {
    super.initState();
    // Default to tomorrow (the earliest allowed selectable day)
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _selectedDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _dayController.text = _formatDate(_selectedDate!);

    _selectedTime = const TimeOfDay(hour: 14, minute: 0);
    _timeController.text = _formatTime(_selectedTime!);
    // The planning attempt starts in didChangeDependencies, once we know
    // whether this is a new meeting or edit mode.
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatTime(TimeOfDay time) {
    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final min = time.minute.toString().padLeft(2, '0');
    final ampm = time.period == DayPeriod.am ? 'am' : 'pm';
    return '$hour12:$min $ampm';
  }

  /// Se puede elegir desde HOY (antes el primer día permitido era mañana y
  /// no se podían crear reuniones para el mismo día). Que la hora no haya
  /// pasado se comprueba al validar ([_scheduleError]).
  Future<void> _selectDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialDate = _selectedDate != null && !_selectedDate!.isBefore(today)
        ? _selectedDate!
        : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.orange,
              onPrimary: AppColors.white,
              surface: AppColors.background,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dayController.text = _formatDate(picked);
        _whenError = null;
      });
    }
  }

  Future<void> _selectTime() async {
    final initial = _selectedTime ?? const TimeOfDay(hour: 14, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.orange,
              onPrimary: AppColors.white,
              surface: AppColors.background,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _timeController.text = _formatTime(picked);
        _whenError = null;
      });
    }
  }

  @override
  void dispose() {
    if (!_isEditMode && !_advanced) {
      AnalyticsService().stepAbandoned(
        MeetingPlanningStep.details,
        extra: {'has_location': _selectedLocation != null ? 1 : 0},
      );
    }
    _activityController.dispose();
    _dayController.dispose();
    _timeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Fija el punto de encuentro y mueve el mapa hasta él. El mapa puede no
  /// estar dibujado todavía (cargando GPS): en ese caso se centrará en el
  /// punto al crearse, porque recibe [_selectedLocation].
  void _setMeetingPoint(LatLng point, String label) {
    setState(() {
      _selectedLocation = point;
      _pointLabel = label;
      _locationError = null;
    });
    if (_mapReady) {
      try {
        _mapController.move(point, 16);
      } catch (e) {
        debugPrint('Map not ready to move: $e');
      }
    }
  }

  /// "Use my current location": pide permiso de ubicación (solo si hace falta)
  /// y usa la posición GPS como punto de encuentro. Cada caso sin permiso o
  /// sin GPS muestra un mensaje en vez de fallar en silencio.
  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _locationError = 'Location services are off. Turn on GPS and try again.';
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _locationError =
            'Location permission is blocked. Enable it in the phone settings.';
        return;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        _locationError = 'Location permission was not granted.';
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      _setMeetingPoint(LatLng(position.latitude, position.longitude),
          'Your current location');
    } catch (e) {
      debugPrint('Current location failed: $e');
      _locationError = 'Could not get your current location. Try again.';
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// "Search": busca la dirección escrita y muestra los resultados para que
  /// el usuario elija uno. Valida longitud mínima y el límite de caracteres.
  Future<void> _searchAddress() async {
    final query = _addressController.text.trim();
    FocusScope.of(context).unfocus();
    final error = query.length < 3
        ? 'Type at least 3 characters to search'
        : InputLimits.tooLong(query, InputLimits.address, 'Address');
    if (error != null) {
      setState(() => _addressError = error);
      return;
    }
    setState(() {
      _searching = true;
      _addressError = null;
      _searchResults = const [];
    });
    try {
      final results = await PlaceSearchService()
          .searchPlaces(query, userLocation: _selectedLocation);
      if (!mounted) return;
      setState(() {
        _searchResults = results.take(5).toList();
        if (results.isEmpty) {
          _addressError = 'No places found for "$query". Try another address.';
        }
      });
    } catch (e) {
      debugPrint('Address search failed: $e');
      if (mounted) {
        setState(() => _addressError =
            'Search is not available right now. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _chooseSearchResult(PlaceSuggestion place) {
    PlaceSearchService()
        .recordPlaceSelection(place, query: _addressController.text.trim())
        .catchError((Object e) => debugPrint('Search not recorded: $e'));
    _addressController.text = place.title;
    setState(() => _searchResults = const []);
    _setMeetingPoint(place.point, place.toString());
  }

  /// Invitados: no se permite invitarse a uno mismo (contaría dos veces en
  /// la votación como organizador y como invitado).
  Future<void> _pickContacts() async {
    final selected =
        await showContactsPicker(context, initiallySelected: _invitees);
    if (selected == null || !mounted) return;
    final myEmail =
        FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase() ?? '';
    final withoutMe = selected
        .where((c) => myEmail.isEmpty || c.email.trim().toLowerCase() != myEmail)
        .toList();
    if (withoutMe.length != selected.length) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You are already part of the meeting as the organizer.')));
    }
    setState(() => _invitees = withoutMe);
  }

  void _removeInvitee(GoogleContact contact) =>
      setState(() => _invitees = [..._invitees]..remove(contact));

  /// Fecha y hora válidas y en el futuro. Una reunión para hoy es válida si
  /// la hora todavía no pasó. Al editar, si no se cambió la fecha/hora, se
  /// acepta aunque ya haya pasado (para poder corregir otros datos).
  String? _scheduleError(DateTime? scheduled) {
    if (scheduled == null) return 'Choose a valid day and time';
    final unchanged = _isEditMode && scheduled == _record?.scheduledAt;
    if (!unchanged && !scheduled.isAfter(DateTime.now())) {
      return 'That time has already passed. Choose a later time.';
    }
    return null;
  }

  bool _validate() {
    final scheduled =
        parseMeetingDateTime(_dayController.text, _timeController.text);
    final activity = _activityController.text.trim();
    setState(() {
      _activityError = activity.isEmpty
          ? 'Tell us what you will do'
          : InputLimits.tooLong(activity, InputLimits.activity, 'Activity');
      _whenError = _scheduleError(scheduled);
      _transitError =
          _transitMode == null ? 'Choose how the group will get there' : null;
      _locationError = _selectedLocation == null
          ? 'Choose the meeting point: tap the map, use your location or search an address'
          : null;
    });
    return _activityError == null &&
        _whenError == null &&
        _transitError == null &&
        _locationError == null;
  }

  /// Saves locally first and queues the Firestore write (works offline).
  /// A second Schedule (after coming back from step 2) edits the same
  /// meeting instead of creating a duplicate. Ya no se guarda presupuesto en
  /// reuniones nuevas; en las existentes se conserva el valor que tenían.
  Future<MeetingRecord?> _saveMeeting() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Log in to create meetings.')));
      return null;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final scheduledAt =
        parseMeetingDateTime(_dayController.text, _timeController.text);
    final names = _invitees.map((c) => c.displayName).toList();
    // Invitations are stored in the meeting (name, e-mail, status). They are
    // not sent: the app has no e-mail/notification backend.
    final invitees = [
      for (final c in _invitees)
        MeetingInvitee(
          name: c.name,
          email: c.email,
          contactId: c.id.startsWith('people/') ? c.id : null,
        ),
    ];
    final existing = _record;
    final draft = existing == null
        ? MeetingRecord(
            id: MeetingRepository.instance.newId(),
            organizerId: uid,
            activity: _activityController.text.trim(),
            dayLabel: _dayController.text.trim(),
            timeLabel: _timeController.text.trim(),
            scheduledAt: scheduledAt,
            transitMode: _transitMode,
            inviteeNames: names,
            invitees: invitees,
            pointLat: _selectedLocation?.latitude,
            pointLng: _selectedLocation?.longitude,
            createdAtClient: now,
            updatedAtClient: now,
          )
        : existing.copyWith(
            activity: _activityController.text.trim(),
            dayLabel: _dayController.text.trim(),
            timeLabel: _timeController.text.trim(),
            scheduledAt: scheduledAt,
            clearScheduledAt: scheduledAt == null,
            transitMode: _transitMode,
            inviteeNames: names,
            invitees: invitees,
            pointLat: _selectedLocation?.latitude,
            pointLng: _selectedLocation?.longitude,
          );
    try {
      final saved = await MeetingRepository.instance.save(draft);
      if (existing == null) {
        // Business question type 4: one event per new meeting.
        await MeetingCreationTracker().meetingCreated(saved);
      }
      _record = saved;
      return saved;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save the meeting: $e'),
          backgroundColor: Colors.red.shade700,
        ));
      }
      return null;
    }
  }

  Future<void> _handleSchedule() async {
    if (_saving || !_validate()) return;

    setState(() => _saving = true);
    final saved = await _saveMeeting();
    if (mounted) setState(() => _saving = false);
    if (saved == null || !mounted) return;

    if (_isEditMode) {
      _advanced = true; // editing is not an abandoned planning attempt
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meeting updated')));
      Navigator.pop(context, true);
      return;
    }

    _advanced = true;
    AnalyticsService().stepCompleted(
      MeetingPlanningStep.details,
      extra: {'invitees': _invitees.length},
      meetingId: saved.id,
    );
    await Navigator.pushNamed(
      context,
      AppRoutes.voteMeeting,
      arguments: {
        'activity': _activityController.text,
        'day': _dayController.text,
        'time': _timeController.text,
        'location': _selectedLocation,
        'invitees': _invitees,
        'meetingId': saved.id,
        'transitMode': saved.transitMode?.label,
      },
    );
    // Came back from the next step: this step is open again.
    _advanced = false;
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
        Navigator.pushReplacementNamed(context, AppRoutes.friends);
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
              // Menú hamburguesa real (antes era un ícono sin acción).
              const EspotiTopBar(),
              const SizedBox(height: AppDimensions.paddingS),
              const SyncStatusBanner(),
              const SizedBox(height: AppDimensions.paddingS),
              Text(
                _isEditMode ? 'Edit meeting' : AppStrings.createAMeeting,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_loadingExisting)
                const Padding(
                  padding: EdgeInsets.only(top: AppDimensions.paddingM),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: AppDimensions.paddingL),

              // Who will go?
              const Text(
                AppStrings.whoWillGo,
                style: TextStyle(fontSize: 15, color: AppColors.text),
              ),
              const SizedBox(height: AppDimensions.paddingS),
              _WhoWillGoRow(
                invitees: _invitees,
                onAdd: _pickContacts,
                onRemove: _removeInvitee,
              ),
              if (_invitees.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: AppDimensions.paddingS),
                  child: Text(
                    'Invitations are saved in the meeting with each contact\'s email. Espoti does not send emails or notifications: invitees see the meeting and vote when they open the app.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              // Los contactos con solo celular se guardan por nombre: sin
              // correo no se les puede reconocer en la app ni contar su voto.
              if (_invitees.any((c) => !c.hasEmail))
                const Padding(
                  padding: EdgeInsets.only(top: AppDimensions.paddingXS),
                  child: Text(
                    'Contacts without an email are added by name only: they cannot open the meeting in the app or vote.',
                    style: TextStyle(fontSize: 12, color: AppColors.orange),
                  ),
                ),
              const SizedBox(height: AppDimensions.paddingL),
              EspotiTextField(
                label: AppStrings.whatWillWeDo,
                controller: _activityController,
                maxLength: InputLimits.activity,
                showCounter: true,
                letterSpacing: 0.3,
                errorText: _activityError,
              ),
              EspotiTextField(
                label: AppStrings.whatDay,
                controller: _dayController,
                readOnly: true,
                onTap: _selectDate,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_month, color: AppColors.primaryBrown),
                  onPressed: _selectDate,
                ),
                hintText: 'Select the date',
                letterSpacing: 0.3,
              ),
              EspotiTextField(
                label: AppStrings.whatTime,
                controller: _timeController,
                readOnly: true,
                onTap: _selectTime,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.access_time, color: AppColors.primaryBrown),
                  onPressed: _selectTime,
                ),
                hintText: 'Select the time',
                letterSpacing: 0.3,
              ),
              if (_whenError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
                  child: Text(
                    _whenError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              TransitModeSelector(
                selected: _transitMode,
                errorText: _transitError,
                onChanged: (mode) => setState(() {
                  _transitMode = mode;
                  _transitError = null;
                }),
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
              // Opción 1: ubicación actual del dispositivo.
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: const Text('Use my current location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBrown,
                    side: const BorderSide(color: AppColors.primaryBrown),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingS),
              // Opción 2: buscar una dirección.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: EspotiTextField(
                      label: 'Address',
                      controller: _addressController,
                      hintText: 'E.g. Calle 26 #4-50, Bogotá',
                      maxLength: InputLimits.address,
                      errorText: _addressError,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchAddress(),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingS),
                  Padding(
                    // Alinea el botón con la caja de texto (bajo la etiqueta).
                    padding: const EdgeInsets.only(top: 28),
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _searching ? null : _searchAddress,
                        // El tema global da a los ElevatedButton un ancho
                        // mínimo infinito (Size.fromHeight). Dentro de un Row
                        // eso no se puede dibujar y rompía toda la pantalla
                        // ("RenderBox was not laid out"); aquí se fija un
                        // tamaño mínimo finito.
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBrown,
                          foregroundColor: AppColors.white,
                          minimumSize: const Size(88, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: _searching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.white))
                            : const Text('Search'),
                      ),
                    ),
                  ),
                ],
              ),
              for (final place in _searchResults)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined, color: AppColors.primaryBrown),
                  title: Text(place.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(place.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _chooseSearchResult(place),
                ),
              // Opción 3: tocar el mapa.
              const Text(
                'Or tap the map to choose the meeting point.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppDimensions.paddingS),
              if (!_loadingExisting)
                _LocationMapPreview(
                  mapController: _mapController,
                  selected: _selectedLocation,
                  onMapReady: () => _mapReady = true,
                  onLocationSelected: (point) =>
                      _setMeetingPoint(point, 'Point chosen on the map'),
                ),
              const SizedBox(height: AppDimensions.paddingS),
              Text(
                _selectedLocation == null
                    ? 'No meeting point selected yet.'
                    : 'Meeting point: ${_pointLabel ?? 'selected'} '
                        '(${_selectedLocation!.latitude.toStringAsFixed(5)}, '
                        '${_selectedLocation!.longitude.toStringAsFixed(5)})',
                style: TextStyle(
                  fontSize: 12,
                  color: _locationError != null ? Colors.red : AppColors.textSecondary,
                ),
              ),
              if (_locationError != null)
                Text(_locationError!,
                    style: const TextStyle(fontSize: 12, color: Colors.red)),
              const SizedBox(height: AppDimensions.paddingXL),

              Center(
                child: EspotiButton(
                  label: _isEditMode ? AppStrings.save : AppStrings.schedule,
                  variant: EspotiButtonVariant.secondary,
                  width: 160,
                  isLoading: _saving,
                  onPressed: _loadingExisting ? null : _handleSchedule,
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

/// Participantes agregados (sin presupuestos por persona). Cada invitado se
/// puede quitar con la "x" del chip.
class _WhoWillGoRow extends StatelessWidget {
  final List<GoogleContact> invitees;
  final VoidCallback onAdd;
  final void Function(GoogleContact) onRemove;

  const _WhoWillGoRow({
    required this.invitees,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppDimensions.paddingS,
      runSpacing: AppDimensions.paddingS,
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
        for (final c in invitees)
          InputChip(
            avatar: CircleAvatar(
              backgroundColor: AppColors.mauve30,
              backgroundImage:
                  c.photoUrl.isNotEmpty ? NetworkImage(c.photoUrl) : null,
              child: c.photoUrl.isEmpty
                  ? const Icon(Icons.person,
                      size: 14, color: AppColors.primaryBrown)
                  : null,
            ),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(c.displayName, overflow: TextOverflow.ellipsis),
            ),
            backgroundColor: AppColors.orange50,
            side: BorderSide.none,
            onDeleted: () => onRemove(c),
            deleteButtonTooltipMessage: 'Remove',
          ),
        Tooltip(
          message: AppStrings.inviteContacts,
          child: GestureDetector(
            onTap: onAdd,
            child: const Icon(
              Icons.add_circle,
              color: AppColors.primaryBrown,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }
}

/// Mapa para elegir el punto. Se centra en el punto ya elegido o, si no hay,
/// en la posición GPS (sin pedir permiso de nuevo si fue negado) o Bogotá.
class _LocationMapPreview extends StatefulWidget {
  final MapController mapController;
  final LatLng? selected;
  final ValueChanged<LatLng> onLocationSelected;
  final VoidCallback onMapReady;

  const _LocationMapPreview({
    required this.mapController,
    required this.selected,
    required this.onLocationSelected,
    required this.onMapReady,
  });

  @override
  State<_LocationMapPreview> createState() => _LocationMapPreviewState();
}

class _LocationMapPreviewState extends State<_LocationMapPreview> {
  LatLng _mapCenter = const LatLng(4.6097, -74.0817);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.selected;
    if (initial != null) {
      _mapCenter = initial;
      _isLoading = false;
    } else {
      _centerOnLastKnownPosition();
    }
  }

  @override
  void setState(VoidCallback fn) {
    // GPS can answer after the user left the screen.
    if (mounted) super.setState(fn);
  }

  /// Solo centra el mapa: no elige el punto (para eso está el botón
  /// "Use my current location"). No pide permiso, para no insistir.
  Future<void> _centerOnLastKnownPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) _mapCenter = LatLng(last.latitude, last.longitude);
      }
    } catch (_) {
      // Sin GPS: se queda el centro por defecto.
    }
    setState(() => _isLoading = false);
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
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Color.fromARGB(255, 202, 106, 50)),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: widget.mapController,
                  options: MapOptions(
                    initialCenter: widget.selected ?? _mapCenter,
                    initialZoom: 15.0,
                    onMapReady: widget.onMapReady,
                    onTap: (tapPosition, point) =>
                        widget.onLocationSelected(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.espoti',
                    ),
                    if (widget.selected != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: widget.selected!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Color.fromARGB(255, 121, 76, 44),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    color: Colors.white.withValues(alpha: 0.8),
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 9, color: Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
