import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_top_bar.dart';
import '../../core/services/meeting_voting_service.dart';
import '../../models/contact.dart';
import '../../models/meeting_vote.dart';
import '../../models/meeting.dart';
import '../../core/analytics/analytics_tracker.dart';
import '../../core/services/analytics_service.dart';
import '../../core/widgets/attendee_avatars.dart';
import '../../core/services/meeting_repository.dart';
import '../../models/meeting_record.dart';
import 'meeting_candidates_database.dart';
import 'nearby_recommendations_service.dart';
import 'recommendation/meeting_schedule.dart';
import 'recommendation/recommendation_strategy.dart';
import 'recommendation/weather_service.dart';

/// Where the candidate places came from.
/// (Se quitaron los lugares "de ejemplo": sin servicio ni lugares guardados se
/// muestra un error, nunca lugares inventados por los que se pudiera votar.)
enum _PlacesSource { live, stored }

/// Cuántos lugares recomendados pasan a la votación de los invitados.
const _maxVoteCandidates = 5;

// Paso 2 del embudo de VV2. Aquí también se ve la conectividad eventual:
// lugares en vivo (LRU / Overpass) o, si falla, lugares guardados (SQLite /
// Hive).
/// "Create a meeting" (2): muestra los participantes que el usuario agregó y
/// los lugares más cercanos al punto elegido; el organizador vota por uno.
///
/// - Sin invitados: el voto del organizador define el lugar (scheduled).
/// - Con invitados: la reunión pasa a pending_votes con los candidatos
///   guardados, y queda así hasta que todos voten (ver MeetingVotingService).
class VoteMeetingPage extends StatefulWidget {
  const VoteMeetingPage({super.key});

  @override
  State<VoteMeetingPage> createState() => _VoteMeetingPageState();
}

class _VoteMeetingPageState extends State<VoteMeetingPage> {
  int _selectedIndex = 0;
  final _recommendationsService = NearbyRecommendationsService();
  final _reviewTracker = RecommendationReviewTracker();
  final _weatherService = WeatherService();
  WeatherForecast? _forecast;
  DateTime? _meetingMoment;
  String _meetingWhenLabel = 'that time';
  List<Meeting> _recommendations = const [];

  /// Lugares ordenados, alineados con [_recommendations] (mismo índice); se
  /// usan para guardar las coordenadas de los candidatos de la votación.
  List<PlaceCandidate> _rankedPlaces = const [];
  List<PlaceCandidate> _candidates = const [];

  /// Solo los contactos que el usuario agregó en el paso 1 (sin simulados).
  List<GoogleContact> _invitees = const [];
  _PlacesSource _placesSource = _PlacesSource.live;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  LatLng? _location;
  bool _isLoadingRecommendations = false;
  String? _recommendationsError;
  bool _didLoadRouteArguments = false;
  bool _advanced = false;
  String? _meetingId; // meeting saved in step 1 (Firestore id)
  bool _savingChoice = false;
  // Time spent on this step (logged when the user votes).
  final DateTime _horaEntrada = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Inicio del paso 2 (PLANNING_STEP_STARTED).
    AnalyticsService().stepViewed(MeetingPlanningStep.vote);
    // When the network comes back, a list that came from saved places (or
    // that failed) reloads by itself with live data.
    // Stream de connectivity_plus; la suscripción se cancela en dispose().
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      final location = _location;
      if (online &&
          location != null &&
          !_isLoadingRecommendations &&
          (_placesSource != _PlacesSource.live ||
              _recommendationsError != null)) {
        _loadRecommendations(location);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadRouteArguments) return;
    _didLoadRouteArguments = true;

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final args = routeArgs is Map ? routeArgs : const <dynamic, dynamic>{};
    final day = args['day'] as String? ?? '';
    final time = args['time'] as String? ?? '';
    _meetingMoment = parseMeetingDateTime(day, time);
    if (_meetingMoment != null) _meetingWhenLabel = '$day $time'.trim();
    _meetingId = args['meetingId'] as String?;
    final invitees = args['invitees'];
    if (invitees is List) _invitees = invitees.whereType<GoogleContact>().toList();
    final location = args['location'];
    if (location is LatLng) {
      _location = location;
      _loadRecommendations(location);
    }
  }

  @override
  void dispose() {
    if (!_advanced) {
      // Back to step 1 (still open): the attempt continues. Leaving through
      // the bottom navigation or the menu is recorded as abandonment in
      // _recordLeaving.
      AnalyticsService().stepLeftBackwards(MeetingPlanningStep.vote);
    }
    // Limpieza: se cancela el stream de conectividad y se cierran los clientes
    // http.
    _connectivitySubscription?.cancel();
    _recommendationsService.close();
    _weatherService.close();
    super.dispose();
  }

  /// Places saved on this device: the meeting's own list (SQLite) first, then
  /// the last places found in the zone (Hive). Empty when there are none.
  Future<List<PlaceCandidate>> _storedCandidates(LatLng location) async {
    final meetingId = _meetingId;
    if (meetingId != null) {
      final ofMeeting = await MeetingCandidatesDatabase.instance
          .candidatesOf(meetingId)
          .catchError((Object _) => const <PlaceCandidate>[]);
      if (ofMeeting.isNotEmpty) return ofMeeting;
    }
    final ofZone = await _recommendationsService
        .storedCandidates(location, radiusMeters: 2500)
        .catchError((Object _) => null);
    return ofZone?.places ?? const [];
  }

  /// Live places (LRU or Overpass); if that fails, the ones saved on this
  /// device. Throws when there is nothing real to show.
  Future<(List<PlaceCandidate>, _PlacesSource)> _loadCandidates(
      LatLng location) async {
    try {
      final candidates = await _recommendationsService.findCandidates(
        location,
        radiusMeters: 2500,
      );
      final meetingId = _meetingId;
      if (meetingId != null) {
        // The meeting's list, saved in the background for offline use.
        MeetingCandidatesDatabase.instance
            .saveCandidates(meetingId, candidates)
            .catchError((Object error) {
          debugPrint('Meeting candidates not stored: $error');
        });
      }
      return (candidates, _PlacesSource.live);
    } catch (_) {
      final stored = await _storedCandidates(location);
      if (stored.isNotEmpty) return (stored, _PlacesSource.stored);
      rethrow;
    }
  }

  /// Rain forecast for the meeting time; null if the service is unavailable.
  Future<WeatherForecast?> _loadForecast(LatLng location) async {
    try {
      return await _weatherService.forecastAt(
          location, _meetingMoment ?? DateTime.now());
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadRecommendations(LatLng location) async {
    setState(() {
      _isLoadingRecommendations = true;
      _recommendationsError = null;
    });
    try {
      // Independent loads run at the same time instead of one after another.
      // Concurrencia: el record de Futures con .wait pide lugares y clima en
      // paralelo. Son operaciones de red (E/S), no bloquean el hilo de la
      // interfaz.
      final ((candidates, source), forecast) = await (
        _loadCandidates(location),
        _loadForecast(location),
      ).wait;
      _reviewTracker.loaded([
        if (source == _PlacesSource.stored) 'stored_places',
        if (forecast == null) 'weather_unavailable',
      ], meetingId: _meetingId);
      if (!mounted) return;
      setState(() {
        _selectedIndex = 0;
        _forecast = forecast;
        _candidates = candidates;
        _placesSource = source;
        _isLoadingRecommendations = false;
      });
      _applyStrategy();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recommendationsError =
            'Could not load nearby places and there are no saved places for this area. Check your connection and try again.';
        _isLoadingRecommendations = false;
      });
    }
  }

  /// Solo queda la estrategia "más cercano al punto elegido" (se eliminó la
  /// estrategia "más justa"); si es probable que llueva, el decorador baja los
  /// lugares al aire libre.
  RecommendationStrategy get _strategy {
    final base = ClosestToPointStrategy(reference: _location!);
    final forecast = _forecast;
    if (forecast == null || !forecast.rainLikely) return base;
    return RainAwareStrategy(
      inner: base,
      rainProbability: forecast.rainProbability,
    );
  }

  /// Ranks the candidates and shows the top 10.
  void _applyStrategy() {
    final ranked = _strategy.rank(_candidates, const []).take(10).toList();
    setState(() {
      _rankedPlaces = [for (final r in ranked) r.place];
      _recommendations = [
        for (final place in ranked)
          Meeting(
            placeName: place.place.name,
            timeLabel: place.place.category,
            distanceLabel: place.explanation,
            rating: null,
            imageUrl: _mapThumbnailUrl(place.place.location),
          ),
      ];
      _selectedIndex = 0;
    });
    _reviewTracker.displayed(
        resultCount: _recommendations.length, meetingId: _meetingId);
  }

  /// Salir del paso 2 por la barra inferior o el menú cuenta como abandono
  /// del intento de planificación (no como "volver al paso 1").
  void _recordLeaving() {
    if (_advanced) return;
    AnalyticsService().stepAbandoned(
      MeetingPlanningStep.vote,
      reason: PlanningAbandonReason.navigation,
    );
  }

  void _handleNavTap(EspotiNavItem item) {
    if (item != EspotiNavItem.createMeeting) _recordLeaving();
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

  /// Lista de candidatos para la votación. Si la reunión ya tenía una votación
  /// abierta (el organizador volvió a este paso), se conserva esa lista para
  /// que los votos ya emitidos sigan apuntando al mismo lugar; solo se agrega
  /// el lugar elegido si no estaba.
  List<MeetingCandidate> _voteCandidates(
      MeetingRecord record, PlaceCandidate chosen) {
    MeetingCandidate toCandidate(PlaceCandidate p, int index) =>
        MeetingCandidate(
          key: 'c$index',
          name: p.name,
          category: p.category,
          lat: p.location.latitude,
          lng: p.location.longitude,
        );

    if (record.isVotingOpen && record.candidates.isNotEmpty) {
      final existing = record.candidates;
      if (existing.any((c) =>
          c.name == chosen.name &&
          c.lat == chosen.location.latitude &&
          c.lng == chosen.location.longitude)) {
        return existing;
      }
      return [...existing, toCandidate(chosen, existing.length)];
    }
    final top = _rankedPlaces.take(_maxVoteCandidates).toList();
    if (!top.contains(chosen)) top[top.length - 1] = chosen;
    return [for (var i = 0; i < top.length; i++) toCandidate(top[i], i)];
  }

  /// Guarda la elección del organizador.
  ///  - Sin invitados: lugar definido y estado scheduled (como antes).
  ///  - Con invitados: candidatos + estado pending_votes, y el voto del
  ///    organizador se registra como un voto más.
  /// Devuelve el estado de la votación (null si no hay votación).
  Future<VoteItem?> _saveChoice(PlaceCandidate chosen) async {
    final id = _meetingId;
    if (id == null) return null;
    final record = await MeetingRepository.instance.byId(id);
    if (record == null) return null;

    if (record.invitees.isEmpty) {
      await MeetingRepository.instance.save(record.copyWith(
        placeName: chosen.name,
        placeCategory: chosen.category,
        status: MeetingRecord.scheduled,
      ));
      return null;
    }

    final candidates = _voteCandidates(record, chosen);
    final saved = await MeetingRepository.instance.save(record.copyWith(
      candidates: candidates,
      status: MeetingRecord.pendingVotes,
    ));
    final mine = candidates.firstWhere(
      (c) =>
          c.name == chosen.name &&
          c.lat == chosen.location.latitude &&
          c.lng == chosen.location.longitude,
      orElse: () => candidates.firstWhere((c) => c.name == chosen.name),
    );
    return MeetingVotingService.instance.submitVote(saved, mine);
  }

  Future<void> _handleVote() async {
    if (_savingChoice) return;
    if (_recommendations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Load the recommendations and choose a place first.')));
      return;
    }
    // Aquí se completa todo el embudo de una vez: paso 2 completado, paso 3
    // visto y PLANNING_FLOW_COMPLETED. Por eso el paso 3 nunca registra
    // abandonos. Además ocurre antes de guardar la elección: si _saveChoice
    // falla, el intento ya quedó como completado.
    _advanced = true;
    AnalyticsService()
      ..stepCompleted(MeetingPlanningStep.vote, meetingId: _meetingId)
      ..stepViewed(MeetingPlanningStep.result)
      ..planningCompleted(meetingId: _meetingId);
    // CÁLCULO DE TIEMPO: Hora de salida al presionar el botón y diferencia en segundos enviada a AnalyticsService
    final horaSalida = DateTime.now();
    final diferenciaSegundos = horaSalida.difference(_horaEntrada).inSeconds;
    AnalyticsService().logStepTime(
      stepName: 'creacion_reunion_paso_2_votacion',
      durationSeconds: diferenciaSegundos,
    );

    final chosen = _recommendations[_selectedIndex];
    final chosenPlace = _rankedPlaces[_selectedIndex];
    _reviewTracker.selected(chosen.placeName, meetingId: _meetingId);

    setState(() => _savingChoice = true);
    // Only participants write votes; the outbox queues them while offline
    // and the sync service uploads them when the network returns.
    // Solo informa a la siguiente pantalla; la escritura usa el outbox igual
    // con o sin conexión.
    final offline = (await Connectivity().checkConnectivity())
        .every((r) => r == ConnectivityResult.none);
    VoteItem? voting;
    try {
      voting = await _saveChoice(chosenPlace);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not save the chosen place: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingChoice = false);
    }
    if (!mounted) return;

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final args = routeArgs is Map ? routeArgs : const <dynamic, dynamic>{};
    final votingOpen = voting != null && voting.meeting.isVotingOpen;
    Navigator.pushNamed(context, AppRoutes.winningPlace, arguments: {
      'meetingId': _meetingId,
      // Con votación abierta, el lugar aún no es el ganador: se muestra como
      // "tu voto" y la pantalla indica quién falta por votar.
      'placeName': votingOpen
          ? chosen.placeName
          : (voting?.meeting.placeName ?? chosen.placeName),
      'placeCategory': chosen.timeLabel,
      'placeDetail': chosen.distanceLabel,
      'day': args['day'],
      'time': args['time'],
      'transitMode': args['transitMode'],
      'offline': offline,
      'participantNames': _participantNames,
      'votingOpen': votingOpen,
      'votedCount': voting?.tally.votedCount,
      'requiredCount': voting?.tally.requiredCount,
      'missingNames': voting?.tally.missingNames,
    });
  }

  /// "You" más los nombres de los contactos agregados en el paso 1.
  List<String> get _participantNames =>
      ['You', for (final c in _invitees) c.displayName];

  void _viewRecommendation(int index) {
    setState(() => _selectedIndex = index);
    _reviewTracker.viewed(_recommendations[index].placeName);
  }

  @override
  Widget build(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final args = routeArgs is Map
        ? Map<String, dynamic>.from(routeArgs)
        : <String, dynamic>{};
    final activity = args['activity'] as String? ?? '';
    final day = args['day'] as String? ?? '';
    final time = args['time'] as String? ?? '';

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
              // Menú hamburguesa real (antes era un ícono sin acción). Antes
              // de navegar desde el menú se registra el abandono del paso 2.
              EspotiTopBar(onBeforeNavigate: _recordLeaving),
              const SizedBox(height: AppDimensions.paddingL),
              const Text(AppStrings.youWillMeet, style: _sectionTitleStyle),
              const SizedBox(height: AppDimensions.paddingM),
              if (activity.isNotEmpty || day.isNotEmpty || time.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  decoration: BoxDecoration(
                    color: AppColors.orange50,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (activity.isNotEmpty)
                        Text(
                          'Activity: $activity',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      if (day.isNotEmpty || time.isNotEmpty)
                        Text(
                          'When: ${day.isNotEmpty ? day : 'Not specified'} • ${time.isNotEmpty ? time : 'Not specified'}',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      if (_location != null)
                        Text(
                          'Meeting point: ${_location!.latitude.toStringAsFixed(4)}, ${_location!.longitude.toStringAsFixed(4)}',
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: AppDimensions.paddingM),
              // Participantes reales: el usuario y los contactos que agregó.
              AttendeeAvatars(count: _participantNames.length),
              const SizedBox(height: AppDimensions.paddingS),
              Text(
                _invitees.isEmpty
                    ? 'Only you. Add people in step 1 to let them vote too.'
                    : 'Participants: ${_participantNames.join(', ')}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              if (_invitees.isNotEmpty)
                const Text(
                  'Your vote is the first one. The place is decided when every participant has voted.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              const SizedBox(height: AppDimensions.paddingL),
              const Text(AppStrings.ourRecommendations,
                  style: _sectionTitleStyle),
              const SizedBox(height: AppDimensions.paddingM),
              if (_location != null) ...[
                const SizedBox(height: AppDimensions.paddingS),
                Text(
                  _strategy.description,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                _WeatherNote(forecast: _forecast, whenLabel: _meetingWhenLabel),
                if (_placesSource == _PlacesSource.stored)
                  const Text(
                    'The places service is unavailable: showing places saved on this device. They will refresh when you reconnect.',
                    style: TextStyle(fontSize: 12, color: AppColors.orange),
                  ),
                const SizedBox(height: AppDimensions.paddingM),
              ],
              if (_isLoadingRecommendations)
                const Center(child: CircularProgressIndicator())
              else if (_recommendationsError != null)
                _RecommendationsMessage(
                  message: _recommendationsError!,
                  onRetry: _location == null
                      ? null
                      : () => _loadRecommendations(_location!),
                )
              else if (_location == null)
                const _RecommendationsMessage(
                  message:
                      'Choose a point on the map to look for nearby places.',
                )
              else if (_recommendations.isEmpty)
                const _RecommendationsMessage(
                  message: 'We could not find named places in this area.',
                )
              else ...[
                for (int i = 0; i < _recommendations.length; i++) ...[
                  _RecommendationCard(
                    meeting: _recommendations[i],
                    selected: _selectedIndex == i,
                    onTap: () => _viewRecommendation(i),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                ],
              ],
              const Padding(
                padding: EdgeInsets.only(top: AppDimensions.paddingS),
                child: Text(
                  'Place data: © OpenStreetMap contributors',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingM),
              Center(
                child: SizedBox(
                  width: 160,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _savingChoice ? null : _handleVote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBrown,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusPill),
                      ),
                    ),
                    child: const Text(
                      AppStrings.vote,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
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

const _sectionTitleStyle = TextStyle(
  fontWeight: FontWeight.w700,
  fontSize: 16,
  color: AppColors.text,
);

/// Tells the user whether the weather changed the recommendations.
class _WeatherNote extends StatelessWidget {
  const _WeatherNote({required this.forecast, required this.whenLabel});

  final WeatherForecast? forecast;
  final String whenLabel;

  @override
  Widget build(BuildContext context) {
    final forecast = this.forecast;
    final (icon, message) = forecast == null
        ? (
            Icons.cloud_off_outlined,
            'Weather unavailable: the list was not adjusted for rain.'
          )
        : forecast.rainLikely
            ? (
                Icons.umbrella_outlined,
                'Rain likely (${forecast.rainProbability}%) for $whenLabel: outdoor places move down the list.'
              )
            : (
                Icons.wb_sunny_outlined,
                'Rain unlikely (${forecast.rainProbability}%) for $whenLabel.'
              );

    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.paddingXS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryBrown),
          const SizedBox(width: AppDimensions.paddingXS),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationsMessage extends StatelessWidget {
  const _RecommendationsMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingL),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (onRetry != null)
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

/// OpenStreetMap tile that contains [point]: a free picture of the place's
/// surroundings, cached on the device like OSM's tile usage policy asks.
String _mapThumbnailUrl(LatLng point, {int zoom = 16}) {
  final tiles = 1 << zoom;
  final latitude = point.latitude * math.pi / 180;
  final x = ((point.longitude + 180) / 360 * tiles).floor();
  final y = ((1 - math.log(math.tan(latitude) + 1 / math.cos(latitude)) / math.pi) /
          2 *
          tiles)
      .floor();
  return 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      color: AppColors.orange50,
      child: const Icon(Icons.image_outlined, color: AppColors.primaryBrown),
    );
  }
}

/// Recommendation card for a place to vote.
class _RecommendationCard extends StatelessWidget {
  final Meeting meeting;
  final bool selected;
  final VoidCallback onTap;

  const _RecommendationCard({
    required this.meeting,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // Antes la tarjeta tenía alto fijo de 80 px y el nombre/explicación
      // largos desbordaban ("overflowed by 22 pixels"). Ahora la altura
      // mínima es 80 y los textos se cortan con elipsis.
      child: Container(
        constraints: const BoxConstraints(minHeight: 80),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          border: Border.all(
            color: selected ? AppColors.orange : const Color(0xFFD9D9D9),
            width: selected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppDimensions.radiusM),
              ),
              child: meeting.imageUrl.isEmpty
                  ? const _ImagePlaceholder()
                  : CachedNetworkImage(
                      imageUrl: meeting.imageUrl,
                      httpHeaders: const {
                        'User-Agent': 'Espoti/0.1.0 (Flutter app)',
                      },
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const _ImagePlaceholder(),
                      errorWidget: (_, __, ___) => const _ImagePlaceholder(),
                    ),
            ),
            const SizedBox(width: AppDimensions.paddingM),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    meeting.placeName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.text,
                    ),
                  ),
                  // Sin estrellas: OpenStreetMap no da calificaciones (rating
                  // siempre era null y dejaba una fila vacía).
                  const SizedBox(height: AppDimensions.paddingXS),
                  Text(
                    meeting.distanceLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              ),
            ),
            // Un solo indicador de selección (el botón "ver" repetía la misma
            // acción que tocar la tarjeta y aportaba ancho extra).
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingS),
              child: Icon(
                selected ? Icons.check_circle : Icons.check_circle_outline,
                color: selected ? AppColors.orange : AppColors.textSecondary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
