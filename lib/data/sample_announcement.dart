import '../models/announcement.dart';

const sampleAnnouncementList = [
  Announcement(
    className: '10А',
    title: 'Хичээлийн амралтын мэдэгдэл',
    body: '3 сарын 20-нд сургууль амарна.\nЭцэг эхчүүдэд мэдэгдэнэ үү.',
    date: '2026 оны 3 сарын 15',
    isFeatured: true,
  ),
  Announcement(
    className: '9Б',
    title: 'Эцэг эхийн уулзалт',
    body: 'Баасан гараг 17:00 цагт 101 тоот өрөөнд болно.',
    date: '2026 оны 3 сарын 10',
    isFeatured: false,
  ),
  Announcement(
    className: '8А',
    title: 'Спортын наадам',
    body: '4 сарын 5-нд спортын талбай дээр зохион байгуулна.',
    date: '2026 оны 3 сарын 5',
    isFeatured: false,
  ),
];
