// lib/data/models/set_model.dart
// ----------------------------------------
// Represents a Yu-Gi-Oh! booster set / expansion.

class SetModel {
  final int id;
  final String setCode;
  final String setName;
  final int? numOfCards;
  final String? tcgDate;

  SetModel({
    required this.id,
    required this.setCode,
    required this.setName,
    this.numOfCards,
    this.tcgDate,
  });

  factory SetModel.fromMap(Map<String, dynamic> map) {
    return SetModel(
      id: map['id'] as int,
      setCode: map['set_code'] as String,
      setName: map['set_name'] as String,
      numOfCards: map['num_of_cards'] as int?,
      tcgDate: map['tcg_date'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'set_code': setCode,
        'set_name': setName,
        'num_of_cards': numOfCards,
        'tcg_date': tcgDate,
      };
}
