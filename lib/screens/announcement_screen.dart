import 'package:flutter/material.dart';

class AnnouncementScreen extends StatelessWidget {
  const AnnouncementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final announcements = [
      {
        'title': 'Хичээлийн амралтын мэдэгдэл',
        'date': '2026 оны 3 сарын 15',
        'body': '3 сарын 20-нд сургууль амарна.',
      },
      {
        'title': 'Эцэг эхийн уулзалт',
        'date': '2026 оны 3 сарын 10',
        'body': 'Баасан гараг 17:00 цагт 101 тоот өрөөнд болно.',
      },
      {
        'title': 'Спортын наадам',
        'date': '2026 оны 3 сарын 5',
        'body': '4 сарын 5-нд спортын талбай дээр зохион байгуулна.',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: announcements.length,
      itemBuilder: (context, index) {
        final item = announcements[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const Icon(Icons.campaign, color: Colors.blue),
            title: Text(
              item['title']!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['date']!),
                  const SizedBox(height: 4),
                  Text(item['body']!),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
