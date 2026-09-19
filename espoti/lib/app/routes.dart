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
import '../features/profile/edit_profile_page.dart';

class AppRoutes {
  AppRoutes._();

  static const String welcome = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String meetings = '/meetings';
  static const String createMeeting = '/create-meeting';
  static const String voteMeeting = '/vote-meeting';
  static const String winningPlace = '/winning-place';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';

  /// Single source of truth mapping route names to their pages.
  static Map<String, WidgetBuilder> get routes => {
        welcome: (context) => const WelcomePage(),
        login: (context) => const LoginPage(),
        register: (context) => const RegisterPage(),
        home: (context) => const HomePage(),
        meetings: (context) => const MeetingsPage(),
        createMeeting: (context) => const CreateMeetingPage(),
        voteMeeting: (context) => const VoteMeetingPage(),
        winningPlace: (context) => const WinningPlacePage(),
        profile: (context) => const ProfilePage(),
        editProfile: (context) => const EditProfilePage(),
      };
}
