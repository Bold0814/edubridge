import 'package:flutter/material.dart';

class HomeworkScreen extends StatelessWidget {
  const HomeworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final homeworkList = [
      {
        'subject': 'Математик',
        'title': 'Бутархай бодлого',
        'dueDate': '2026 оны 3 сарын 18',
      },
      {
        'subject': 'Монгол хэл',
        'title': 'Өгүүлбэр бичих',
        'dueDate': '2026 оны 3 сарын 17',
      },
      {
        'subject': 'Англи хэл',
        'title': 'Үгийн сан',
        'dueDate': '2026 оны 3 сарын 20',
      },
      {
        'subject': 'Байгалийн ухаан',
        'title': 'Ургамлын бүтэц',
        'dueDate': '2026 оны 3 сарын 19',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: homeworkList.length,
      itemBuilder: (context, index) {
        final item = homeworkList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const Icon(Icons.assignment, color: Colors.orange),
            title: Text(
              item['title']!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Хичээл: ${item['subject']}'),
                  Text('Дуусах хугацаа: ${item['dueDate']}'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
