import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_button.dart';
import '../../core/widgets/espoti_logo.dart';
import '../../core/widgets/espoti_text_field.dart';
import '../../core/services/analytics_service.dart';
import '../../core/analytics/meeting_creation_tracker.dart';
import '../../core/services/meeting_repository.dart';
import '../../core/widgets/sync_status_banner.dart';
import '../../models/meeting_record.dart';
import '../../models/transit_mode.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'recommendation/meeting_schedule.dart';
import 'transit_mode_selector.dart';
import '../../models/contact.dart';
import 'budget_recommendation_service.dart';
import 'contacts_picker_sheet.dart';

//Esto lo pongo para tener un mapa real :D
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

/// "Create a meeting" screen (1). Arrive from the "+" button
/// on the bottom nav. When you press Schedule, the meeting is saved
/// (offline-first, see MeetingRepository) and it goes to step 2 (vote).
///
/// Edit mode: open it with `arguments: {'meetingId': id}`; Save updates the
/// same Firestore document and returns to the previous screen.
class CreateMeetingPage extends StatefulWidget {
  const CreateMeetingPage({super.key});

  @override
  State<CreateMeetingPage> createState() => _CreateMeetingPageState();
}

class _CreateMeetingPageState extends State<CreateMeetingPage> {
  final _activityController = TextEditingController(text: 'Eat');
  final _dayController = TextEditingController();
  final _timeController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _budgetController = TextEditingController();
  //El ? es porque puede quedar vacía
  LatLng? _selectedLocation;

  // Sprint 2: invitees from Google Contacts + per-participant max budgets.
  List<GoogleContact> _invitees = const [];
  final Map<String, int> _inviteeBudgets = {};

  // Sprint 2: funnel analytics.
  bool _advanced = false;

  // Sprint 3: persistence + business question type 4.
  TransitMode? _transitMode;
  String? _transitError;
  String? _activityError;
  String? _whenError;
  bool _saving = false;
  bool _loadingExisting = false;
  bool _didReadArgs = false;
  MeetingRecord? _record; // saved meeting (new one after first Schedule)
  bool _isEditMode = false;

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
      _budgetController.text = record.budgetPerPerson?.toString() ?? '';
      _transitMode = record.transitMode;
      if (record.pointLat != null && record.pointLng != null) {
        _selectedLocation = LatLng(record.pointLat!, record.pointLng!);
      }
      _invitees = [
        for (final name in record.inviteeNames)
          GoogleContact(id: 'name:$name', name: name, email: ''),
      ];
    });
    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se encontró la reunión en este dispositivo.')));
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

    AnalyticsService()
      ..meetingPlanningStarted()
      ..stepViewed(MeetingPlanningStep.details);
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

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final initialDate = _selectedDate != null && !_selectedDate!.isBefore(tomorrow)
        ? _selectedDate!
        : tomorrow;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: tomorrow,
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
    if (!_advanced) {
      AnalyticsService().stepAbandoned(
        MeetingPlanningStep.details,
        extra: {'has_location': _selectedLocation != null ? 1 : 0},
      );
    }
    _activityController.dispose();
    _dayController.dispose();
    _timeController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  int? _parseBudget(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  Future<void> _pickContacts() async {
    final selected =
        await showContactsPicker(context, initiallySelected: _invitees);
    if (selected == null || !mounted) return;
    setState(() {
      _invitees = selected;
      _inviteeBudgets.removeWhere((id, _) => !selected.any((c) => c.id == id));
    });
  }

  Future<void> _editInviteeBudget(GoogleContact contact) async {
    final controller = TextEditingController(
        text: _inviteeBudgets[contact.id]?.toString() ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(contact.displayName),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: AppStrings.maxBudgetLabel,
            hintText: AppStrings.maxBudgetHint,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text(AppStrings.save)),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    final budget = _parseBudget(result);
    setState(() {
      budget == null
          ? _inviteeBudgets.remove(contact.id)
          : _inviteeBudgets[contact.id] = budget;
    });
  }

  bool _validate() {
    final scheduled =
        parseMeetingDateTime(_dayController.text, _timeController.text);
    setState(() {
      _activityError = _activityController.text.trim().isEmpty
          ? 'Tell us what you will do'
          : null;
      _whenError = scheduled == null
          ? 'Use a day like "Sunday", "today" or "tomorrow" and a time like "2:00 pm"'
          : null;
      _transitError =
          _transitMode == null ? 'Choose how the group will get there' : null;
    });
    return _activityError == null && _whenError == null && _transitError == null;
  }

  /// Saves locally first and queues the Firestore write (works offline).
  /// A second Schedule (after coming back from step 2) edits the same
  /// meeting instead of creating a duplicate.
  Future<MeetingRecord?> _saveMeeting(int? budget) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Inicia sesión para crear reuniones.')));
      return null;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final scheduledAt =
        parseMeetingDateTime(_dayController.text, _timeController.text);
    final names = _invitees.map((c) => c.displayName).toList();
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
            budgetPerPerson: budget,
            inviteeNames: names,
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
            budgetPerPerson: budget,
            clearBudget: budget == null,
            inviteeNames: names,
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
          content: Text('No se pudo guardar la reunión: $e'),
          backgroundColor: Colors.red.shade700,
        ));
      }
      return null;
    }
  }

  Future<void> _handleSchedule() async {
    if (_saving || !_validate()) return;
    // Everyone's maximum budget -> one compatible budget per person.
    final budget = BudgetRecommendationService.compatibleBudget([
      _parseBudget(_budgetController.text),
      ..._inviteeBudgets.values,
    ]);

    setState(() => _saving = true);
    final saved = await _saveMeeting(budget);
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
      extra: {
        'invitees': _invitees.length,
        'has_budget': budget != null ? 1 : 0,
      },
    );
    await Navigator.pushNamed(
      context,
      AppRoutes.voteMeeting,
      arguments: {
        'activity': _activityController.text,
        'day': _dayController.text,
        'time': _timeController.text,
        'location': _selectedLocation,
        'budget': budget,
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
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  EspotiLogo(height: AppDimensions.logoSizeSmall),
                  Icon(Icons.menu, color: AppColors.primaryBrown),
                ],
              ),
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
                budgets: _inviteeBudgets,
                onAdd: _pickContacts,
                onEditBudget: _editInviteeBudget,
              ),
              const SizedBox(height: AppDimensions.paddingL),
              EspotiTextField(
                label: AppStrings.whatWillWeDo,
                controller: _activityController,
                maxLength: 50,
                showCounter: true,
                letterSpacing: 0.3,
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
                hintText: 'Selecciona la fecha',
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
                hintText: 'Selecciona la hora',
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
              EspotiTextField(
                label: AppStrings.maxBudgetLabel,
                controller: _budgetController,
                keyboardType: TextInputType.number,
                hintText: AppStrings.maxBudgetHint,
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
                  // Search is not implemented yet: hint instead of a dead button.
                  const Tooltip(
                    message: 'Tap the map to choose the meeting point',
                    child: Icon(Icons.touch_app,
                        color: Color.fromARGB(255, 143, 64, 11)),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingS),
              if (!_loadingExisting)
              _LocationMapPreview(
                initialPosition: _selectedLocation,
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
                  label: _isEditMode ? AppStrings.save : AppStrings.schedule,
                  variant: EspotiButtonVariant.secondary,
                  width: 160,
                  isLoading: _saving,
                  onPressed: _selectedLocation == null || _loadingExisting
                      ? null
                      : _handleSchedule,
                ),
              ),
              if (_selectedLocation == null)
                const Padding(
                  padding: EdgeInsets.only(top: AppDimensions.paddingS),
                  child: Center(
                    child: Text(
                      'Tap the map to choose the meeting point',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
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
  final List<GoogleContact> invitees;
  final Map<String, int> budgets;
  final VoidCallback onAdd;
  final void Function(GoogleContact) onEditBudget;

  const _WhoWillGoRow({
    required this.invitees,
    required this.budgets,
    required this.onAdd,
    required this.onEditBudget,
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
          ActionChip(
            avatar: CircleAvatar(
              backgroundColor: AppColors.mauve30,
              backgroundImage:
                  c.photoUrl.isNotEmpty ? NetworkImage(c.photoUrl) : null,
              child: c.photoUrl.isEmpty
                  ? const Icon(Icons.person,
                      size: 14, color: AppColors.primaryBrown)
                  : null,
            ),
            label: Text(
              budgets[c.id] == null
                  ? c.displayName
                  : '${c.displayName} · \$${BudgetRecommendationService.formatCop(budgets[c.id]!)}',
            ),
            backgroundColor: AppColors.orange50,
            side: BorderSide.none,
            onPressed: () => onEditBudget(c),
          ),
        GestureDetector(
          onTap: onAdd,
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
  final LatLng? initialPosition;

  const _LocationMapPreview({
    this.onLocationSelected,
    this.initialPosition,
  });

  @override
  State<_LocationMapPreview> createState() {
    return _LocationMapPreviewState();
  }
}

class _LocationMapPreviewState extends State<_LocationMapPreview> {
  LatLng? _selectedPosition;
  LatLng _mapCenter = const LatLng(4.6097, -74.0817);
  bool _isLoading = true;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPosition;
    if (initial != null) {
      // Edit mode: show the saved meeting point instead of the GPS position.
      _selectedPosition = initial;
      _mapCenter = initial;
      _isLoading = false;
    } else {
      _getCurrentGPSLocation();
    }
  }

  @override
  void setState(VoidCallback fn) {
    // GPS can answer after the user left the screen.
    if (mounted) super.setState(fn);
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
        _mapCenter = latLng;
        _isLoading = false;
      });
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
        child:
            CircularProgressIndicator(color: Color.fromARGB(255, 202, 106, 50)),
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
            if (_selectedPosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPosition!,
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
