import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/services/activity_context_service.dart';
import '../../core/services/location_sharing_service.dart';
import '../../core/widgets/espoti_top_bar.dart';

/// Pantalla "Motion sensor": muestra en vivo la lectura del acelerómetro y el
/// estado que deduce [ActivityContextService] (en movimiento / quieto).
///
/// Mientras está abierta registra a la pantalla como "dueña" del sensor; al
/// salir lo libera (si el uso compartido de ubicación lo sigue usando, el
/// sensor continúa encendido para él). Si el dispositivo no tiene
/// acelerómetro (por ejemplo, web o algunos emuladores) se muestra ese estado;
/// no se simulan datos.
class MotionSensorPage extends StatefulWidget {
  const MotionSensorPage({super.key});

  @override
  State<MotionSensorPage> createState() => _MotionSensorPageState();
}

class _MotionSensorPageState extends State<MotionSensorPage> {
  static const Object _owner = 'motion_sensor_page';

  @override
  void initState() {
    super.initState();
    ActivityContextService().start(owner: _owner);
  }

  @override
  void dispose() {
    ActivityContextService().stop(owner: _owner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppDimensions.paddingL,
                  AppDimensions.paddingM, AppDimensions.paddingL, 0),
              child: EspotiTopBar(
                title: 'Motion sensor',
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.primaryBrown),
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppDimensions.paddingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MotionLiveCard(),
                    SizedBox(height: AppDimensions.paddingL),
                    _HowItWorks(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta en vivo: estado de movimiento + valores del sensor. Se usa en
/// esta pantalla y en el detalle de la reunión.
class MotionLiveCard extends StatelessWidget {
  /// En el detalle se muestra compacta (sin ejes x/y/z).
  final bool compact;
  const MotionLiveCard({super.key, this.compact = false});

  static (IconData, String, Color) describe(MotionState state) => switch (state) {
        MotionState.moving =>
          (Icons.directions_walk, 'The participant is moving', AppColors.orange),
        MotionState.stationary =>
          (Icons.accessibility_new, 'The participant is still', AppColors.primaryBrown),
        MotionState.unknown =>
          (Icons.sensors, 'Detecting movement…', AppColors.textSecondary),
        MotionState.unavailable => (
            Icons.sensors_off,
            'Accelerometer not available on this device',
            AppColors.textSecondary
          ),
      };

  @override
  Widget build(BuildContext context) {
    final service = ActivityContextService();
    return ValueListenableBuilder<MotionState>(
      valueListenable: service.stateNotifier,
      builder: (context, state, _) {
        final (icon, label, color) = describe(state);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          decoration: BoxDecoration(
            color: state == MotionState.moving
                ? AppColors.accent1
                : AppColors.mauve30.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            border: Border.all(
                color: state == MotionState.moving ? AppColors.orange : AppColors.mauve30,
                width: state == MotionState.moving ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: compact ? 22 : 32),
                  const SizedBox(width: AppDimensions.paddingS),
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: compact ? 14 : 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                  ),
                ],
              ),
              if (state == MotionState.unavailable)
                const Padding(
                  padding: EdgeInsets.only(top: AppDimensions.paddingS),
                  child: Text(
                    'This device or platform does not provide accelerometer data (for example, web or some emulators). No values are simulated; location is shared every few minutes instead.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                )
              else
                ValueListenableBuilder<MotionReading?>(
                  valueListenable: service.readingNotifier,
                  builder: (_, reading, __) => _Values(reading: reading, compact: compact),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Values extends StatelessWidget {
  final MotionReading? reading;
  final bool compact;
  const _Values({required this.reading, required this.compact});

  String _f(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final r = reading;
    if (r == null) {
      return const Padding(
        padding: EdgeInsets.only(top: AppDimensions.paddingS),
        child: Text('Waiting for sensor data…',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      );
    }
    const style = TextStyle(fontSize: 13, color: AppColors.text);
    final mean = r.windowMean;
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.paddingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact)
            Text('Acceleration x: ${_f(r.x)}  y: ${_f(r.y)}  z: ${_f(r.z)} m/s²',
                style: style),
          Text('Deviation from gravity |a| − g: ${_f(r.deviation)} m/s²', style: style),
          Text(
            mean == null
                ? 'Average of the last ~2 s: collecting samples…'
                : 'Average of the last ~2 s: ${_f(mean)} m/s²',
            style: style,
          ),
          const SizedBox(height: 4),
          // Barra: promedio respecto al umbral de movimiento (1.0 m/s²).
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: mean == null
                  ? 0.0
                  : (mean / (ActivityContextService.movingThreshold * 2))
                      .clamp(0.0, 1.0)
                      .toDouble(),
              minHeight: 8,
              backgroundColor: AppColors.mauve30.withValues(alpha: 0.3),
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Moving above ${ActivityContextService.movingThreshold} m/s² · still below ${ActivityContextService.stationaryThreshold} m/s²',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 13, color: AppColors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What is measured',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
        const SizedBox(height: 4),
        const Text(
          'The accelerometer reports acceleration in m/s² on three axes, including gravity (about 9.81 m/s²). '
          'Espoti subtracts gravity from the total and averages it every ~2 seconds (10 samples).',
          style: style,
        ),
        const SizedBox(height: 4),
        const Text(
          'Two averages in a row above ${ActivityContextService.movingThreshold} m/s² (~4 s) mean "moving". '
          'Five in a row below ${ActivityContextService.stationaryThreshold} m/s² (~10 s) mean "still".',
          style: style,
        ),
        const SizedBox(height: 4),
        Text(
          'During an active meeting, while you are moving your GPS position is sent every '
          '${LocationSharingService.movingIntervalSeconds} s, but only if it changed by at least '
          '${LocationSharingService.minDistanceMeters.toStringAsFixed(0)} m. When you are still, updates pause to save battery.',
          style: style,
        ),
        const SizedBox(height: 4),
        const Text(
          'The accelerometer does not measure distance; distance comes from GPS, which usually has an error of a few meters.',
          style: style,
        ),
      ],
    );
  }
}
