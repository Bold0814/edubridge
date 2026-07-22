import 'package:flutter/material.dart';

class GradeScreen extends StatelessWidget {
  const GradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final grades = [
      {'subject': 'Математик', 'score': '95', 'term': '1-р улирал'},
      {'subject': 'Монгол хэл', 'score': '88', 'term': '1-р улирал'},
      {'subject': 'Англи хэл', 'score': '92', 'term': '1-р улирал'},
      {'subject': 'Байгалийн ухаан', 'score': '90', 'term': '1-р улирал'},
      {'subject': 'Түүх', 'score': '85', 'term': '1-р улирал'},
      {'subject': 'Хөгжим', 'score': '94', 'term': '1-р улирал'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grades.length,
      itemBuilder: (context, index) {
        final item = grades[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const Icon(Icons.grade, color: Colors.purple),
            title: Text(
              item['subject']!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(item['term']!),
            trailing: Text(
              item['score']!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        );
      },
    );
  }
}
