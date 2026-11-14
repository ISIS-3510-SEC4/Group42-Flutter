import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/input_limits.dart';
import '../../core/services/contacts_service.dart';
import '../../core/widgets/espoti_button.dart';
import '../../models/contact.dart';

/// Bottom sheet that lists the user's Google Contacts and returns the
/// selected ones (invitar a una reunión o importar como amigos).
///
/// Usa la integración real con Google People API ([ContactsService]) y su
/// flujo de permisos: si el usuario no entró con Google o no concede el
/// permiso de contactos, se muestra el error y se puede reintentar.
/// Devuelve null si se cierra sin confirmar o si no se pudieron cargar los
/// contactos (así no se borran los ya elegidos por un error de red).
Future<List<GoogleContact>?> showContactsPicker(
  BuildContext context, {
  List<GoogleContact> initiallySelected = const [],
  String title = AppStrings.selectContacts,
}) {
  return showModalBottomSheet<List<GoogleContact>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusL),
      ),
    ),
    builder: (_) => _ContactsPickerSheet(
        initiallySelected: initiallySelected, title: title),
  );
}

class _ContactsPickerSheet extends StatefulWidget {
  final List<GoogleContact> initiallySelected;
  final String title;
  const _ContactsPickerSheet(
      {required this.initiallySelected, required this.title});

  @override
  State<_ContactsPickerSheet> createState() => _ContactsPickerSheetState();
}

class _ContactsPickerSheetState extends State<_ContactsPickerSheet> {
  final _service = ContactsService();
  List<GoogleContact> _contacts = const [];
  late final Set<String> _selectedIds =
      widget.initiallySelected.map((c) => c.id).toSet();
  String _query = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Se cargan al abrir; si falla (sin Google, permiso negado, red) se
      // muestra el mensaje de ContactsException y se puede reintentar.
      final contacts = await _service.fetchContacts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ContactsException
            ? e.message
            : 'Your contacts could not be loaded.';
        _isLoading = false;
      });
    }
  }

  /// Seleccionados de la lista cargada + los que ya venían elegidos y no
  /// aparecen en ella (por ejemplo, invitados guardados solo con correo).
  List<GoogleContact>? _result() {
    if (_isLoading || _error != null) return null;
    final loadedIds = {for (final c in _contacts) c.id};
    return [
      ..._contacts.where((c) => _selectedIds.contains(c.id)),
      ...widget.initiallySelected.where(
          (c) => _selectedIds.contains(c.id) && !loadedIds.contains(c.id)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Filtrado en memoria por nombre, correo o teléfono: no hace nuevas
    // llamadas.
    final visible = _contacts.where((c) {
      final q = _query.toLowerCase();
      return q.isEmpty ||
          c.displayName.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q) ||
          c.phone.contains(q);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppDimensions.paddingM),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                maxLength: InputLimits.contactSearch,
                decoration: InputDecoration(
                  hintText: 'Search',
                  counterText: '',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.orange50,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingS),
              Expanded(child: _buildBody(visible)),
              const SizedBox(height: AppDimensions.paddingS),
              Center(
                child: EspotiButton(
                  label: AppStrings.done,
                  variant: EspotiButtonVariant.secondary,
                  width: 160,
                  onPressed: () => Navigator.pop(context, _result()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<GoogleContact> visible) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (visible.isEmpty) {
      return const Center(
        child: Text(
          'No contacts with an email address or phone number were found.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final c = visible[i];
        final selected = _selectedIds.contains(c.id);
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: AppColors.orange,
          value: selected,
          onChanged: (v) => setState(() {
            v == true ? _selectedIds.add(c.id) : _selectedIds.remove(c.id);
          }),
          secondary: CircleAvatar(
            backgroundColor: AppColors.mauve30,
            backgroundImage:
                c.photoUrl.isNotEmpty ? NetworkImage(c.photoUrl) : null,
            child: c.photoUrl.isEmpty
                ? const Icon(Icons.person, color: AppColors.primaryBrown)
                : null,
          ),
          title: Text(c.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.text)),
          // Correo o, si no tiene, el celular.
          subtitle: Text(c.detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        );
      },
    );
  }
}
