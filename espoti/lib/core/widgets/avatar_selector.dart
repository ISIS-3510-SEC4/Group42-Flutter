import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

class AvatarSelector extends StatelessWidget {
  final String currentAvatarUrl;
  final ValueChanged<String> onAvatarChanged;
  final double radius;

  const AvatarSelector({
    super.key,
    required this.currentAvatarUrl,
    required this.onAvatarChanged,
    this.radius = 48,
  });

  static const List<String> presetAvatars = [
    'https://i.pravatar.cc/200?img=13',
    'https://i.pravatar.cc/200?img=12',
    'https://i.pravatar.cc/200?img=32',
    'https://i.pravatar.cc/200?img=47',
    'https://i.pravatar.cc/200?img=68',
    'https://i.pravatar.cc/200?img=5',
    'https://i.pravatar.cc/200?img=8',
    'https://i.pravatar.cc/200?img=60',
  ];

  void _showAvatarPickerModal(BuildContext context) {
    final customUrlController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusL)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppDimensions.paddingL,
            right: AppDimensions.paddingL,
            top: AppDimensions.paddingL,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppDimensions.paddingL,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.accent2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingM),
                const Text(
                  'Elige tu foto de perfil',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingS),
                const Text(
                  'Selecciona uno de los avatares disponibles o ingresa el enlace de tu foto:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppDimensions.paddingM),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: presetAvatars.map((url) {
                    final isSelected = url == currentAvatarUrl;
                    return GestureDetector(
                      onTap: () {
                        onAvatarChanged(url);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.orange : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.mauve30,
                          backgroundImage: NetworkImage(url),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppDimensions.paddingL),
                TextField(
                  controller: customUrlController,
                  decoration: InputDecoration(
                    labelText: 'O pega la URL de una foto',
                    labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check, color: AppColors.orange),
                      onPressed: () {
                        final text = customUrlController.text.trim();
                        if (text.isNotEmpty) {
                          onAvatarChanged(text);
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingS),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAvatarPickerModal(context),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.mauve30,
            child: ClipOval(
              child: Image.network(
                currentAvatarUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.person,
                  size: radius,
                  color: AppColors.primaryBrown,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.orange,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt,
              size: 16,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}
