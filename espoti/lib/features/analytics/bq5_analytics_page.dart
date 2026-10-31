import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/widgets/espoti_top_bar.dart';

/// Screen for Business Question Tipo 5:
/// "How do user's location preferences and interaction patterns affect the
/// acceptance rate of meeting point recommendations?"
///
/// Reads processed aggregates directly from Firestore collection `analytics_results`,
/// document `bq5_recommendation_acceptance_FLUTTER`.
class Bq5AnalyticsPage extends StatelessWidget {
  const Bq5AnalyticsPage({super.key});

  static const String docPath = 'analytics_results/bq5_recommendation_acceptance_FLUTTER';

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('analytics_results')
        .doc('bq5_recommendation_acceptance_FLUTTER')
        .snapshots();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingL,
                AppDimensions.paddingM,
                AppDimensions.paddingL,
                AppDimensions.paddingS,
              ),
              child: EspotiTopBar(
                title: 'BQ 5 Analíticas',
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.primaryBrown),
                  tooltip: 'Volver',
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.mauve30),
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryBrown),
                    );
                  }

                  if (snapshot.hasError) {
                    return _ErrorState(error: snapshot.error.toString());
                  }

                  final doc = snapshot.data;
                  if (doc == null || !doc.exists || doc.data() == null) {
                    return const _EmptyState();
                  }

                  final data = doc.data()!;
                  return _AnalyticsContent(data: data);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsContent extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AnalyticsContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final totalDecisions = (data['totalDecisions'] as num?)?.toInt() ?? 0;
    final totalAccepted = (data['totalAccepted'] as num?)?.toInt() ?? 0;
    final totalRejected = (data['totalRejected'] as num?)?.toInt() ?? 0;
    final overallRate = (data['overallAcceptanceRate'] as num?)?.toDouble() ?? 0.0;

    final byPreference = (data['byPreference'] as Map<String, dynamic>?) ?? {};
    final byPattern = (data['byInteractionPattern'] as Map<String, dynamic>?) ?? {};
    final distanceMetrics = (data['distanceMetrics'] as Map<String, dynamic>?) ?? {};

    final avgDistAccepted = (distanceMetrics['avgDistanceAcceptedMeters'] as num?)?.toInt() ?? 0;
    final avgDistRejected = (distanceMetrics['avgDistanceRejectedMeters'] as num?)?.toInt() ?? 0;

    final calculatedAt = data['calculatedAt'] as Timestamp?;
    final dateStr = calculatedAt != null ? calculatedAt.toDate().toLocal().toString().split('.').first : 'Reciente';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Banner
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              color: AppColors.mauve30.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.mauve30),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.psychology, color: AppColors.primaryBrown, size: 28),
                const SizedBox(width: AppDimensions.paddingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Business Question Tipo 5',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.orange,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['question'] as String? ??
                            "How do user's location preferences and interaction patterns affect the acceptance rate of meeting point recommendations?",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.paddingL),

          // Main KPI: Overall Acceptance Rate
          _KpiCard(
            rate: overallRate,
            totalDecisions: totalDecisions,
            totalAccepted: totalAccepted,
            totalRejected: totalRejected,
          ),
          const SizedBox(height: AppDimensions.paddingL),

          // Breakdown: By Location Preference
          const Text(
            'Tasa de Aceptación por Preferencias de Ubicación',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
          ),
          const SizedBox(height: 8),
          const Text(
            'Comportamiento según los gustos de ubicación declarados por los usuarios:',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          if (byPreference.isEmpty)
            const _NoDataPlaceholder(label: 'Sin desglose por preferencias aún.')
          else
            ...byPreference.entries.map((entry) {
              final stats = entry.value as Map<String, dynamic>? ?? {};
              final rate = (stats['rate'] as num?)?.toDouble() ?? 0.0;
              final accepted = (stats['accepted'] as num?)?.toInt() ?? 0;
              final total = (stats['total'] as num?)?.toInt() ?? 0;
              return _RateBarItem(
                label: entry.key,
                rate: rate,
                subtext: '$accepted de $total aceptadas',
                icon: Icons.place_outlined,
              );
            }),
          const SizedBox(height: AppDimensions.paddingL),

          // Breakdown: By Interaction Pattern
          const Text(
            'Tasa de Aceptación por Patrón de Interacción',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
          ),
          const SizedBox(height: 8),
          const Text(
            'Efectividad según la forma en que el usuario interactuó con la recomendación:',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          if (byPattern.isEmpty)
            const _NoDataPlaceholder(label: 'Sin desglose por patrones de interacción aún.')
          else
            ...byPattern.entries.map((entry) {
              final stats = entry.value as Map<String, dynamic>? ?? {};
              final rate = (stats['rate'] as num?)?.toDouble() ?? 0.0;
              final accepted = (stats['accepted'] as num?)?.toInt() ?? 0;
              final total = (stats['total'] as num?)?.toInt() ?? 0;
              return _RateBarItem(
                label: _formatPattern(entry.key),
                rate: rate,
                subtext: '$accepted de $total aceptadas',
                icon: _patternIcon(entry.key),
              );
            }),
          const SizedBox(height: AppDimensions.paddingL),

          // Distance Metrics Card
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.straighten, color: AppColors.primaryBrown, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Distancias Promedio de Recomendación',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.paddingM),
                Row(
                  children: [
                    Expanded(
                      child: _MetricSubBox(
                        title: 'Aceptadas',
                        value: avgDistAccepted > 0 ? '$avgDistAccepted m' : 'N/A',
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.paddingM),
                    Expanded(
                      child: _MetricSubBox(
                        title: 'Rechazadas',
                        value: avgDistRejected > 0 ? '$avgDistRejected m' : 'N/A',
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.paddingL),

          // Footer Info
          Center(
            child: Text(
              'Firestore: analytics_results/bq5_recommendation_acceptance_FLUTTER\nÚltimo cálculo: $dateStr',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingL),
        ],
      ),
    );
  }

  static String _formatPattern(String pattern) {
    switch (pattern) {
      case 'MAP_EXPANDED':
        return 'Mapa Expandido / Inspección';
      case 'DETAILS_VIEWED':
        return 'Detalles del Lugar Consultados';
      case 'BUDGET_FILTERED':
        return 'Filtro de Presupuesto Aplicado';
      case 'DIRECT_SELECT':
        return 'Selección Directa';
      default:
        return pattern;
    }
  }

  static IconData _patternIcon(String pattern) {
    switch (pattern) {
      case 'MAP_EXPANDED':
        return Icons.map_outlined;
      case 'DETAILS_VIEWED':
        return Icons.info_outline;
      case 'BUDGET_FILTERED':
        return Icons.attach_money;
      default:
        return Icons.touch_app_outlined;
    }
  }
}

class _KpiCard extends StatelessWidget {
  final double rate;
  final int totalDecisions;
  final int totalAccepted;
  final int totalRejected;

  const _KpiCard({
    required this.rate,
    required this.totalDecisions,
    required this.totalAccepted,
    required this.totalRejected,
  });

  @override
  Widget build(BuildContext context) {
    final color = rate >= 65
        ? Colors.green.shade700
        : rate >= 40
            ? AppColors.orange
            : Colors.red.shade700;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TASA GLOBAL DE ACEPTACIÓN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(width: AppDimensions.paddingM),
              Flexible(
                child: Text(
                  '$totalAccepted de $totalDecisions recomendaciones aceptadas',
                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: totalDecisions > 0 ? (rate / 100).clamp(0.0, 1.0) : 0,
              minHeight: 10,
              backgroundColor: AppColors.mauve30,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Aceptadas: $totalAccepted', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green)),
              Text('Rechazadas: $totalRejected', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RateBarItem extends StatelessWidget {
  final String label;
  final double rate;
  final String subtext;
  final IconData icon;

  const _RateBarItem({
    required this.label,
    required this.rate,
    required this.subtext,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.mauve30.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryBrown),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.orange),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (rate / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.mauve30,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MetricSubBox extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _MetricSubBox({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart_outlined, size: 64, color: AppColors.mauve30),
            const SizedBox(height: AppDimensions.paddingM),
            const Text(
              'Aún no hay métricas procesadas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
            ),
            const SizedBox(height: 8),
            const Text(
              'No se encontró el documento `analytics_results/bq5_recommendation_acceptance_FLUTTER` en Firestore.\n\nInteractúa con recomendaciones en la app y ejecuta el script de agregación:\n`node analytics/recommendation_acceptance_analysis.js`',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;

  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: AppDimensions.paddingM),
            const Text('Error al conectar con Firestore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _NoDataPlaceholder extends StatelessWidget {
  final String label;

  const _NoDataPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
