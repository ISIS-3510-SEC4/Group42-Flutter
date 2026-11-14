import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/input_limits.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/friend_code_service.dart';
import '../../core/services/friends_service.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_top_bar.dart';
import '../../core/services/user_service.dart';
import '../../models/friend.dart';
import '../meetings/contacts_picker_sheet.dart';

/// Amigos: código propio, búsqueda por código e importación desde Google
/// Contacts.
///
/// - Búsqueda por código: [FriendCodeService.findByCode] consulta el
///   directorio público `user_codes/{CODIGO}` (solo nombre, foto y código) y
///   muestra el resultado con un botón para agregarlo.
///
/// - Se eliminaron los amigos de ejemplo; sin amigos se muestra
///   "You don't have any friends yet".
/// - "Import from Google Contacts" usa la integración existente
///   ([ContactsService] + selector de contactos) con su flujo de permisos:
///   requiere haber iniciado sesión con Google y aceptar el permiso de
///   contactos; si no, se explica en vez de inventar contactos.
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final _searchController = TextEditingController();
  bool _importing = false;
  bool _searching = false;
  String? _searchError;

  /// Resultado de la última búsqueda por código (null si no hay).
  Friend? _found;

  @override
  void initState() {
    super.initState();
    FriendsService.instance.load();
    // El código propio puede cambiar (si estaba repetido se genera otro al
    // publicarlo): se redibuja cuando cambia el perfil.
    UserService().userNotifier.addListener(_onUserChanged);
    // Asegura que el código propio esté publicado para que otros lo
    // encuentren (si ya lo está, solo lo confirma).
    FriendCodeService.instance.publishMyCode();
  }

  void _onUserChanged() {
    if (mounted) setState(() {});
  }

  void _handleNavTap(EspotiNavItem item) {
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
        Navigator.pushReplacementNamed(context, AppRoutes.createMeeting);
        break;
      case EspotiNavItem.friends:
        break;
    }
  }

  /// Valida el código (mismo límite que la interfaz), lo busca en Firestore
  /// y muestra el resultado o un mensaje claro (no existe, es tu propio
  /// código, sin conexión...).
  Future<void> _handleSearchSubmit(String value) async {
    if (_searching) return;
    FocusScope.of(context).unfocus();
    final error = FriendCodeService.validate(value);
    if (error != null) {
      setState(() {
        _searchError = error;
        _found = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
      _found = null;
    });
    try {
      final friend = await FriendCodeService.instance.findByCode(value);
      if (!mounted) return;
      setState(() {
        _found = friend;
        if (friend == null) {
          _searchError =
              'No Espoti user has the code ${FriendCodeService.normalize(value)}.';
        }
      });
    } on FriendCodeException catch (e) {
      if (mounted) setState(() => _searchError = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addFound() async {
    final friend = _found;
    if (friend == null) return;
    final added = await FriendsService.instance.addFriend(friend);
    if (!mounted) return;
    setState(() {
      _found = null;
      _searchController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(added
          ? '${friend.displayName} was added to your friends.'
          : '${friend.displayName} is already in your friends.'),
    ));
  }

  Future<void> _importFromContacts() async {
    if (_importing) return;
    // Los contactos se leen con la sesión de Google (scope de solo lectura).
    // Si se entró con correo, o la app se reinició, googleAccount es null y hay
    // que volver a entrar con Google para leer contactos.
    if (AuthService().googleAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'To import contacts, log in with Google and allow access to your contacts.'),
      ));
      return;
    }
    setState(() => _importing = true);
    try {
      final selected = await showContactsPicker(context,
          title: 'Import from Google Contacts');
      if (selected == null || selected.isEmpty || !mounted) return;
      final added = await FriendsService.instance.importContacts(selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(added == 0
            ? 'Those contacts are already in your friends.'
            : added == 1
                ? '1 friend added.'
                : '$added friends added.'),
      ));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _confirmRemove(Friend friend) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${friend.displayName}?'),
        content: const Text('They will be removed from your friends on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (remove == true) await FriendsService.instance.remove(friend);
  }

  @override
  void dispose() {
    UserService().userNotifier.removeListener(_onUserChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = UserService().currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.paddingL,
                AppDimensions.paddingM,
                AppDimensions.paddingL,
                0,
              ),
              child: EspotiTopBar(),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.mauve30,
                          backgroundImage: user.avatarUrl.isEmpty
                              ? null
                              : NetworkImage(user.avatarUrl),
                          child: user.avatarUrl.isEmpty
                              ? const Icon(Icons.person, color: AppColors.primaryBrown)
                              : null,
                        ),
                        const SizedBox(width: AppDimensions.paddingM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  const Text(
                                    AppStrings.yourCode,
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      user.code,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () async {
                                      await Clipboard.setData(ClipboardData(text: user.code));
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Code copied')),
                                      );
                                    },
                                    child: const Icon(Icons.copy, size: 14, color: AppColors.orange),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Si el código propio no se publicó, nadie podrá
                    // encontrarte: se explica y se permite reintentar.
                    ValueListenableBuilder<CodePublishStatus>(
                      valueListenable: FriendCodeService.instance.status,
                      builder: (context, status, _) => switch (status) {
                        CodePublishStatus.published => const Padding(
                            padding: EdgeInsets.only(top: AppDimensions.paddingXS),
                            child: Text('Friends can find you with this code.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ),
                        CodePublishStatus.publishing => const Padding(
                            padding: EdgeInsets.only(top: AppDimensions.paddingXS),
                            child: Text('Publishing your code…',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ),
                        CodePublishStatus.failed => Row(
                            children: [
                              Expanded(
                                child: Text(
                                  FriendCodeService.instance.lastError ??
                                      'Your code is not visible to others yet.',
                                  style: const TextStyle(fontSize: 12, color: AppColors.orange),
                                ),
                              ),
                              TextButton(
                                onPressed: FriendCodeService.instance.publishMyCode,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        CodePublishStatus.unknown => const SizedBox.shrink(),
                      },
                    ),
                    const SizedBox(height: AppDimensions.paddingL),
                    const Text(
                      'Search new friends',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    TextField(
                      controller: _searchController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _handleSearchSubmit,
                      maxLength: InputLimits.friendCode,
                      // El código de amigo solo lleva letras y números.
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                      ],
                      decoration: InputDecoration(
                        hintText: 'Enter the code',
                        helperText: 'Letters and numbers, up to ${InputLimits.friendCode} characters',
                        errorText: _searchError,
                        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search, color: AppColors.textSecondary),
                                tooltip: 'Search',
                                onPressed: () => _handleSearchSubmit(_searchController.text),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                          borderSide: const BorderSide(color: AppColors.primaryBrown, width: 1),
                        ),
                      ),
                    ),
                    if (_found != null)
                      Card(
                        margin: const EdgeInsets.only(top: AppDimensions.paddingS),
                        child: ListTile(
                          leading: _FriendAvatar(photoUrl: _found!.photoUrl),
                          title: Text(_found!.displayName,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(_found!.detail),
                          trailing: TextButton.icon(
                            onPressed: _addFound,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Add'),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppDimensions.paddingS),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _importing ? null : _importFromContacts,
                        icon: const Icon(Icons.contacts_outlined),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBrown,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                          ),
                        ),
                        label: const Text('Import from Google Contacts'),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingL),
                    const Text(
                      'Your friends:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    ValueListenableBuilder<List<Friend>>(
                      valueListenable: FriendsService.instance.friends,
                      builder: (context, friends, _) {
                        if (friends.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingM),
                            child: Row(
                              children: [
                                Icon(Icons.group_outlined, color: AppColors.textSecondary),
                                SizedBox(width: AppDimensions.paddingS),
                                Expanded(
                                  child: Text(
                                    'You don\'t have any friends yet',
                                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final f in friends)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: _FriendAvatar(photoUrl: f.photoUrl),
                                title: Text(f.displayName,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                // Correo, celular o código de Espoti.
                                subtitle: Text(f.detail,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                                  tooltip: 'Remove',
                                  onPressed: () => _confirmRemove(f),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppDimensions.paddingL),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: EspotiBottomNavigation(
        currentItem: EspotiNavItem.friends,
        onItemSelected: _handleNavTap,
      ),
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  final String photoUrl;
  const _FriendAvatar({required this.photoUrl});

  @override
  Widget build(BuildContext context) => CircleAvatar(
        backgroundColor: AppColors.mauve30,
        backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
        child: photoUrl.isEmpty
            ? const Icon(Icons.person, color: AppColors.primaryBrown)
            : null,
      );
}
