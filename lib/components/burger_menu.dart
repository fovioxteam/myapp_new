import 'package:flutter/material.dart';

class BurgerMenu extends StatelessWidget {
  const BurgerMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu, color: Colors.black),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                ListTile(leading: Icon(Icons.settings), title: Text('Settings')),
                ListTile(leading: Icon(Icons.lock_person_outlined), title: Text('Privacy')),
                ListTile(leading: Icon(Icons.logout), title: Text('Logout')),
              ],
            ),
          ),
        );
      },
    );
  }
}
