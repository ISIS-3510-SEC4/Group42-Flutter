import 'package:flutter/material.dart';
import '../features/welcome/welcome_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/home/home_page.dart';
import '../features/meetings/meetings_page.dart';
import '../features/meetings/create_meeting_page.dart';
import '../features/meetings/vote_meeting_page.dart';
import '../features/meetings/winning_place_page.dart';
import '../features/profile/profile_page.dart';
import '../features/friends/friends_page.dart';
import '../features/meetings/meeting_detail_page.dart';
import '../features/profile/edit_profile_page.dart';
import '../features/analytics/bq5_analytics_page.dart';
import '../features/analytics/analytics_dashboard_page.dart';
import '../features/meetings/meeting_voting_page.dart';
import '../features/meetings/pending_votes_page.dart';
import '../features/motion/motion_sensor_page.dart';
import 'auth_guard.dart';

class AppRoutes {
  AppRoutes._();

  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';

  static const String home = '/home';
  static const String profile = '/profile';
  static const String meetings = '/meetings';
  static const String meetingDetail = '/meeting_detail';

  static const String createMeeting = '/create-meeting';
  static const String voteMeeting = '/vote-meeting';
  static const String winningPlace = '/winning-place';

  static const String friends = '/friends';
  static const String createMeetingRecommendations = '/create-meeting-recommendations';
  static const String editProfile = '/edit-profile';
  static const String bq5Analytics = '/analytics-bq5';
  /// Tablero único con las dos BQ (abandono y tipo 4).
  static const String analyticsDashboard = '/analytics-dashboard';
  // Rutas anteriores: ahora abren el mismo tablero único.
  static const String planningAbandonment = '/analytics-planning-abandonment';
  static const String meetingPeakWindows = '/analytics-meeting-peak-windows';
  static const String pendingVotes = '/pending-votes';
  static const String meetingVoting = '/meeting-voting';
  static const String motionSensor = '/motion-sensor';

  /// Routes reachable without a session. Every other route is wrapped in
  /// [AuthGuard] and redirects to [welcome] when there is no Firebase user.
  static const Set<String> publicRoutes = {welcome, login, register};

  static WidgetBuilder _guard(String name, WidgetBuilder builder) =>
      publicRoutes.contains(name)
          ? builder
          : (context) => AuthGuard(redirectRoute: welcome, child: builder(context));

  /// Asociar nombres de rutas con sus respectivas páginas
  static Map<String, WidgetBuilder> get routes => {
        for (final entry in _pages.entries)
          entry.key: _guard(entry.key, entry.value),
      };

  static Map<String, WidgetBuilder> get _pages => {
        welcome: (context) => const WelcomePage(),
        login: (context) => const LoginPage(),
        register: (context) => const RegisterPage(),
        home: (context) => const HomePage(),
        meetings: (context) => const MeetingsPage(),
        createMeeting: (context) => const CreateMeetingPage(),
        voteMeeting: (context) => const VoteMeetingPage(),
        winningPlace: (context) => const WinningPlacePage(),
        profile: (context) => const ProfilePage(),
        friends: (context) => const FriendsPage(),
        meetingDetail: (context) => const MeetingDetailPage(),
        editProfile: (context) => const EditProfilePage(),
        bq5Analytics: (context) => const Bq5AnalyticsPage(),
        analyticsDashboard: (context) => const AnalyticsDashboardPage(),
        planningAbandonment: (context) => const AnalyticsDashboardPage(),
        meetingPeakWindows: (context) => const AnalyticsDashboardPage(),
        pendingVotes: (context) => const PendingVotesPage(),
        meetingVoting: (context) => const MeetingVotingPage(),
        motionSensor: (context) => const MotionSensorPage(),
      };
}
