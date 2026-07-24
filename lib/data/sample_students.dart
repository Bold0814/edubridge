import '../models/student.dart';

const sampleStudentsByClass = <String, List<Student>>{
  '10А': [
    Student(
      id: '10a-1',
      className: '10А',
      lastName: 'Бат',
      firstName: 'Эрдэнэ',
      gender: StudentGender.male,
      register: 'УБ00112233',
      phone: '99112233',
    ),
    Student(
      id: '10a-2',
      className: '10А',
      lastName: 'Болор',
      firstName: 'Маа',
      gender: StudentGender.female,
    ),
    Student(
      id: '10a-3',
      className: '10А',
      lastName: 'Наран',
      firstName: 'Сүх',
      gender: StudentGender.male,
    ),
    Student(
      id: '10a-4',
      className: '10А',
      lastName: 'Энх',
      firstName: 'Жин',
      gender: StudentGender.female,
      phone: '88001122',
    ),
    Student(
      id: '10a-5',
      className: '10А',
      lastName: 'Тэмүү',
      firstName: 'Лэн',
      gender: StudentGender.male,
    ),
  ],
  '6А': [
    Student(
      id: '6a-1',
      className: '6А',
      lastName: 'Амар',
      firstName: 'Сайхан',
      gender: StudentGender.male,
    ),
    Student(
      id: '6a-2',
      className: '6А',
      lastName: 'Сараа',
      firstName: 'Цэцэг',
      gender: StudentGender.female,
    ),
  ],
};
