import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';
import '../utils/theme_controller.dart';
import '../utils/notification_service.dart';
import 'edit_avatar_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();

  static const _keyPushNotif = 'pref_push_notifications';
  static const _keyEmailReminders = 'pref_email_reminders';

  bool _pushNotifications = false;
  bool _emailReminders = false;

  String _fullName = '';
  String _email = '';
  String _phone = '';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserSession();
    _loadPreferences();
  }

  Future<void> _loadUserSession() async {
    final session = await _authService.getSavedSession();
    if (session != null && mounted) {
      setState(() {
        _fullName = session.fullName;
        _email = session.email;
        _phone = session.phone;
        _avatarUrl = session.avatarUrl;
      });
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _pushNotifications = prefs.getBool(_keyPushNotif) ?? false;
        _emailReminders = prefs.getBool(_keyEmailReminders) ?? false;
      });
    }
  }

  Future<void> _togglePushNotifications(bool value) async {
    if (value) {
      // On demande la permission réelle avant d'activer (Android 13+).
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Permission refusée. Active-la dans les paramètres du téléphone.'),
            ),
          );
        }
        return; // on ne coche pas le switch si la permission est refusée
      }
    } else {
      // Désactiver = annuler tous les rappels déjà programmés.
      await NotificationService.cancelAll();
    }

    setState(() => _pushNotifications = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPushNotif, value);
  }

  Future<void> _toggleEmailReminders(bool value) async {
    setState(() => _emailReminders = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEmailReminders, value);
    // Note : l'envoi d'email réel nécessiterait un service backend dédié
    // (hors périmètre de ce projet) — seule la préférence est enregistrée.
  }

  Future<void> _goToEditAvatar() async {
    final newAvatarUrl = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EditAvatarScreen(currentAvatarUrl: _avatarUrl),
      ),
    );
    if (newAvatarUrl != null && mounted) {
      setState(() => _avatarUrl = newAvatarUrl);
    }
  }

  Future<void> _editProfileInfo() async {
    final nameController = TextEditingController(text: _fullName);
    final phoneController = TextEditingController(text: _phone);
    final emailController = TextEditingController(text: _email);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom complet'),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Téléphone'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (saved == true) {
      try {
        final updated = await _authService.updateProfile(
          fullName: nameController.text.trim(),
          phone: phoneController.text.trim(),
          email: emailController.text.trim(),
        );
        if (!mounted) return;
        setState(() {
          _fullName = updated.fullName;
          _phone = updated.phone;
          _email = updated.email;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour !')),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Échec de la mise à jour, réessaie.')),
          );
        }
      }
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _authService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildAvatarSection(),
                    const SizedBox(height: 28),
                    _buildFieldSection(),
                    const SizedBox(height: 20),
                    _buildPreferencesCard(),
                    const SizedBox(height: 16),
                    _buildAppearanceCard(),
                    const SizedBox(height: 28),
                    _buildLogoutButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 16),
          const Text(
            'Paramètres',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: AppColors.inputFill,
          backgroundImage:
              _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
          child: _avatarUrl == null
              ? Icon(Icons.person, size: 40, color: AppColors.textPlaceholder)
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _goToEditAvatar,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.edit, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('INFORMATIONS', style: AppTextStyles.label),
            GestureDetector(
              onTap: _editProfileInfo,
              child: Row(
                children: [
                  Icon(Icons.edit, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text('Modifier',
                      style: TextStyle(fontSize: 12, color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('NOM COMPLET', style: AppTextStyles.label),
        const SizedBox(height: 4),
        Text(_fullName.isEmpty ? '—' : _fullName,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
        const Divider(height: 24, color: AppColors.inputBorder),
        Text('TÉLÉPHONE', style: AppTextStyles.label),
        const SizedBox(height: 4),
        Text(_phone.isEmpty ? '—' : _phone,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
        const Divider(height: 24, color: AppColors.inputBorder),
        Text('EMAIL', style: AppTextStyles.label),
        const SizedBox(height: 4),
        Text(_email,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildPreferencesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PRÉFÉRENCES', style: AppTextStyles.label),
          const SizedBox(height: 12),
          _switchRow(
            title: 'Notifications push',
            subtitle: 'Rappels à la date d\'échéance des tâches',
            value: _pushNotifications,
            onChanged: _togglePushNotifications,
          ),
          const Divider(height: 24, color: AppColors.inputBorder),
          _switchRow(
            title: 'Rappels par email',
            subtitle: 'Résumé quotidien des tâches',
            value: _emailReminders,
            onChanged: _toggleEmailReminders,
          ),
        ],
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: AppColors.textLabel)),
            ],
          ),
        ),
        Switch(
          value: value,
          activeColor: AppColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildAppearanceCard() {
    Widget modeButton(String label, ThemeMode option, ThemeMode current) {
      final isSelected = current == option;
      return GestureDetector(
        onTap: () => ThemeController.setMode(option),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textLabel,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('APPARENCE', style: AppTextStyles.label),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Mode sombre',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              const Spacer(),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.mode,
                builder: (context, currentMode, _) {
                  return Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        modeButton('Auto', ThemeMode.system, currentMode),
                        modeButton('Clair', ThemeMode.light, currentMode),
                        modeButton('Sombre', ThemeMode.dark, currentMode),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _confirmLogout,
        icon: const Icon(Icons.logout, size: 18, color: Colors.red),
        label: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}
