import 'package:flutter/material.dart';

class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Lists',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ),
    );
  }
}
