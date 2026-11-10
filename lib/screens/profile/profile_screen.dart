import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/local_demo_store.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen(
      {super.key,
      required this.store,
      required this.demoEmail,
      required this.onSignOut,
      required this.onOpenFavourites});
  final LocalDemoStore store;
  final String? demoEmail;
  final VoidCallback onSignOut;
  final VoidCallback onOpenFavourites;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<String> _name;
  late Future<bool> _notices;
  late Future<List<SavedRoute>> _favourites;

  @override
  void initState() {
    super.initState();
    _name = widget.store.loadName();
    _notices = widget.store.loadTransitModeEnabled();
    _favourites = widget.store.loadFavourites();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
        children: [
          const Text('Profile',
              style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 25,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Local demo profile · stored on this device',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
          const SizedBox(height: 20),
          FutureBuilder<String>(
              future: _name,
              builder: (context, name) => Container(
                    padding: const EdgeInsets.all(19),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      CircleAvatar(
                          radius: 25,
                          backgroundColor: AppColors.surfaceRaised,
                          child: Text(_initial(name.data ?? 'P'),
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w700))),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(name.data ?? 'Passenger',
                                style: const TextStyle(
                                    color: AppColors.primaryText,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(widget.demoEmail ?? 'Email not provided',
                                style: const TextStyle(
                                    color: AppColors.secondaryText,
                                    fontSize: 12)),
                          ])),
                      IconButton(
                          tooltip: 'Edit display name',
                          onPressed: _editName,
                          icon: const Icon(Icons.edit_outlined,
                              color: AppColors.accent)),
                    ]),
                  )),
          const SizedBox(height: 12),
          FutureBuilder<List<SavedRoute>>(
              future: _favourites,
              builder: (context, snapshot) => Card(
                    color: AppColors.surface,
                    child: ListTile(
                      leading: const Icon(Icons.favorite_border,
                          color: AppColors.accent),
                      title: const Text('Favourite routes',
                          style: TextStyle(color: AppColors.primaryText)),
                      subtitle: Text(
                          '${snapshot.data?.length ?? 0} saved on this device',
                          style:
                              const TextStyle(color: AppColors.secondaryText)),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.secondaryText),
                      onTap: widget.onOpenFavourites,
                    ),
                  )),
          const SizedBox(height: 8),
          FutureBuilder<bool>(
              future: _notices,
              builder: (context, snapshot) => SwitchListTile(
                    value: snapshot.data ?? true,
                    onChanged: (value) async {
                      await widget.store.saveTransitModeEnabled(value);
                      if (mounted) {
                        setState(() => _notices = Future.value(value));
                      }
                    },
                    title: const Text('Prefer public transit in Google Maps',
                        style: TextStyle(
                            color: AppColors.primaryText, fontSize: 14)),
                    subtitle: const Text(
                        'Sets the external directions link mode. Simulation and data notices always remain visible.',
                        style: TextStyle(
                            color: AppColors.secondaryText, fontSize: 11)),
                    activeThumbColor: AppColors.accent,
                  )),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Return to login')),
          const SizedBox(height: 16),
          const Text(
              'This prototype has no real account or cloud synchronization. Login is local validation only; profile preferences and favourites stay in this browser/device storage.',
              style: TextStyle(
                  color: AppColors.secondaryText, fontSize: 11, height: 1.45)),
        ],
      );

  String _initial(String value) =>
      value.trim().isEmpty ? 'P' : value.trim()[0].toUpperCase();

  Future<void> _editName() async {
    final current = await _name;
    if (!mounted) return;
    final controller =
        TextEditingController(text: current == 'Passenger' ? '' : current);
    final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Display name'),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 48,
                  decoration: const InputDecoration(labelText: 'Name')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: const Text('Save'))
              ],
            ));
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await widget.store.saveProfile(name: name, email: widget.demoEmail);
    if (mounted) setState(() => _name = Future.value(name.trim()));
  }
}
