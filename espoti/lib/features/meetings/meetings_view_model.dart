import 'package:flutter/foundation.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../core/services/meeting_repository.dart';
import '../../core/services/meeting_voting_service.dart';
import '../../models/meeting.dart';
import '../../models/meeting_record.dart';

/// ViewModel (MVVM) of the user's meetings.
///
/// Owns the screen state (loading, stale data, error, selected tab) and talks
/// to [MeetingRepository]; the views ([MeetingsPage], the Home sections) only
/// observe it (Observer: ChangeNotifier + ListenableBuilder) and forward user
/// actions. It also observes [MeetingRepository.changes], so meetings saved,
/// synced or rejected by a conflict appear without manual refresh.
///
/// Reuniones mostradas = propias (MeetingRepository, organizerId == uid) +
/// reuniones a las que el usuario fue invitado (MeetingVotingService, por
/// correo). Así un invitado también las ve en Upcoming / Previous /
/// Canceled y en Home, no solo en la sección de votaciones.
class MeetingsViewModel extends ChangeNotifier {
  MeetingsViewModel({MeetingRepository? repository, DateTime Function()? clock})
      : _repository = repository ?? MeetingRepository.instance,
        _clock = clock ?? DateTime.now;

  final MeetingRepository _repository;
  final DateTime Function() _clock;

  /// Reuniones organizadas por el usuario.
  List<MeetingRecord> _own = const [];

  /// Reuniones a las que fue invitado (no se guardan en el repositorio
  /// propio porque su organizador es otra persona).
  List<MeetingRecord> _invited = const [];
  bool _loading = true;
  bool _stale = false;
  String? _error;
  MeetingStatus _selectedStatus = MeetingStatus.upcoming;
  bool _started = false;
  bool _disposed = false;

  bool get loading => _loading;

  /// Data came from the device because the server could not be reached.
  bool get stale => _stale;
  String? get error => _error;
  MeetingStatus get selectedStatus => _selectedStatus;

  /// Meetings of the selected tab.
  List<MeetingRecord> get visibleMeetings => byStatus(_selectedStatus);

  /// Propias + invitadas, sin repetir (si aparece en ambas, gana la propia),
  /// de la más reciente a la más antigua.
  List<MeetingRecord> get _meetings {
    final byId = {for (final m in _invited) m.id: m, for (final m in _own) m.id: m};
    final list = byId.values.toList()
      ..sort((a, b) {
        final at = a.scheduledAt?.millisecondsSinceEpoch ?? a.createdAtClient;
        final bt = b.scheduledAt?.millisecondsSinceEpoch ?? b.createdAtClient;
        return bt.compareTo(at);
      });
    return list;
  }

  List<MeetingRecord> byStatus(MeetingStatus status) {
    final now = _clock();
    return _meetings.where((m) => m.uiStatus(now) == status).toList();
  }

  /// El usuario no organiza esta reunión: fue invitado.
  bool isInvited(MeetingRecord meeting) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && meeting.organizerId != uid;
  }

  /// Upcoming meetings, the closest first (Home).
  List<MeetingRecord> get upcomingSoonestFirst {
    final list = byStatus(MeetingStatus.upcoming);
    list.sort((a, b) {
      final at = a.scheduledAt?.millisecondsSinceEpoch ?? a.createdAtClient;
      final bt = b.scheduledAt?.millisecondsSinceEpoch ?? b.createdAtClient;
      return at.compareTo(bt);
    });
    return list;
  }

  bool isPending(String meetingId) => _repository.isPending(meetingId);

  /// Starts observing the repository and loads. Safe to call more than once.
  void start() {
    if (_started) return;
    _started = true;
    _repository.changes.addListener(_onRepositoryChange);
    final voting = MeetingVotingService.instance;
    voting.overview.addListener(_onVotingChange);
    _invited = voting.overview.value.invited;
    load();
    // Trae las invitaciones del servidor (también cierra votaciones listas).
    voting.refresh();
  }

  void selectStatus(MeetingStatus status) {
    if (status == _selectedStatus) return;
    _selectedStatus = status;
    _notify();
  }

  Future<void> refresh() async {
    await Future.wait([
      load(force: true),
      MeetingVotingService.instance.refresh(),
    ]);
  }

  void _onVotingChange() {
    _invited = MeetingVotingService.instance.overview.value.invited;
    _notify();
  }

  Future<void> load({bool force = false}) async {
    try {
      final result = await _repository.myMeetings(forceRefresh: force);
      _own = result.meetings;
      _stale = result.stale;
      _error = null;
    } catch (e) {
      debugPrint('MeetingsViewModel load failed: $e');
      _error = 'Your meetings could not be loaded.';
    }
    _loading = false;
    _notify();
  }

  void _onRepositoryChange() => load();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_started) {
      _repository.changes.removeListener(_onRepositoryChange);
      MeetingVotingService.instance.overview.removeListener(_onVotingChange);
    }
    super.dispose();
  }
}
