import 'package:flutter/material.dart';
import '../features/welcome/welcome_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/home/home_page.dart';
import '../features/meetings/meetings_page.dart';
import '../features/profile/profile_page.dart';
import '../features/friends/friends_page.dart';
import '../features/meetings/meeting_detail_page.dart';

class AppRoutes {
  AppRoutes._();

  static const String welcome = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String meetings = '/meetings';
  static const String profile = '/profile';
  static const String createMeeting = '/create_meeting';
  static const String friends = '/friends';
  static const String meetingDetail = '/meeting_detail';
static const String createMeetingRecommendations = '/create-meeting-recommendations';
  /// Single source of truth mapping route names to their pages.
  static Map<String, WidgetBuilder> get routes => {
        welcome: (context) => const WelcomePage(),
        login: (context) => const LoginPage(),
        register: (context) => const RegisterPage(),
        home: (context) => const HomePage(),
        meetings: (context) => const MeetingsPage(),
        profile: (context) => const ProfilePage(),
        friends: (context) => const FriendsPage(),
        meetingDetail: (context) => const MeetingDetailPage(),
      };
}
