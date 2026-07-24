import '../models/homework.dart';

const sampleHomeworkList = [
  Homework(
    className: '10А',
    subject: 'Математик',
    title: 'Бутархай бодлого',
    description: 'Сурах бичгийн 42-р хуудасны 1–10 бодлогыг бодож ирнэ.',
    dueDate: '2026 оны 3 сарын 18',
    status: HomeworkStatus.pending,
  ),
  Homework(
    className: '9Б',
    subject: 'Монгол хэл',
    title: 'Өгүүлбэр бичих',
    description: 'Өгөгдсөн сэдвээр 5 өгүүлбэр бичиж ирнэ.',
    dueDate: '2026 оны 3 сарын 17',
    status: HomeworkStatus.done,
  ),
  Homework(
    className: '8А',
    subject: 'Англи хэл',
    title: 'Үгийн сан',
    description: 'Unit 5-ийн шинэ үгсийг цээжилж, өгүүлбэр зохионо.',
    dueDate: '2026 оны 3 сарын 20',
    status: HomeworkStatus.pending,
  ),
  Homework(
    className: '7А',
    subject: 'Байгалийн ухаан',
    title: 'Ургамлын бүтэц',
    description: 'Ургамлын үндэс, иш, навчны бүтцийг зурж тайлбарлана.',
    dueDate: '2026 оны 3 сарын 19',
    status: HomeworkStatus.pending,
  ),
];
