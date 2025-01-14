class SudokuGame {
  int? id;
  String name;
  int result;
  String date;
  int level;

  SudokuGame({
    this.id,
    required this.name,
    required this.result,
    required this.date,
    required this.level,
  });

  factory SudokuGame.fromMap(Map<String, dynamic> map) {
    return SudokuGame(
      id: map['id'],
      name: map['name'],
      result: map['result'],
      date: map['date'],
      level: map['level'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'result': result,
      'date': date,
      'level': level,
    };
  }
}
