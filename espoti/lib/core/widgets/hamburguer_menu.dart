import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class HamburguerMenu extends StatelessWidget {
  const HamburguerMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera: Avatar y nombre (Julian)
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: AppColors.accent2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Julian',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBrown,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.black12, thickness: 1),
              const SizedBox(height: 10),

              // Opciones del menú central
              Expanded(
                child: ListView(
                  children: [
                    _buildMenuItem('Recommendations', () {}),
                    _buildMenuItem('Ratings', () {}),
                    _buildMenuItem('Schedule', () {}),
                    _buildMenuItem("What's new?", () {}),
                    _buildMenuItem('Contact us', () {}),
                    _buildMenuItem('About us', () {}),
                    _buildMenuItem('Bug Report', () {}),
                  ],
                ),
              ),

              const Divider(color: Colors.black12, thickness: 1),
              const SizedBox(height: 10),

              // Opción de Settings fija al fondo como en el diseño
              _buildMenuItem('Settings', () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryBrown,
          ),
        ),
      ),
    );
  }
}