import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final res = store.search(_q);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              hintText: 'Ролл, пицца, сет…',
              prefixIcon: Icon(Icons.search_rounded),
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      body: _q.trim().length < 2
          ? const _Hint('Введите хотя бы две буквы')
          : res.isEmpty
              ? const _Hint('Ничего не нашлось')
              : CustomScrollView(slivers: [
                  SliverPadding(padding: const EdgeInsets.all(16), sliver: productGrid(res)),
                ]),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);
  @override
  Widget build(BuildContext context) => Center(child: Text(text, style: const TextStyle(color: RH.muted, fontSize: 16)));
}
