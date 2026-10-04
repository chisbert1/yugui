// lib/data/models/card_model.dart
// ----------------------------------------
// Represents a master Yu-Gi-Oh! card from catalog or API.

class CardModel {
  final int id;
  final String name;
  final String? type;
  final String? frameType;
  final String? desc;
  final int? atk;
  final int? def;
  final int? level;
  final String? race;
  final String? attribute;
  final String? imageUrlSmall;
  final String? imageUrl;
  final double? tcgplayerPrice;
  final double? cardmarketPrice;

  CardModel({
    required this.id,
    required this.name,
    this.type,
    this.frameType,
    this.desc,
    this.atk,
    this.def,
    this.level,
    this.race,
    this.attribute,
    this.imageUrlSmall,
    this.imageUrl,
    this.tcgplayerPrice,
    this.cardmarketPrice,
  });

  factory CardModel.fromMap(Map<String, dynamic> map) {
    return CardModel(
      id: map['id'] as int,
      name: map['name'] as String,
      type: map['type'] as String?,
      frameType: map['frame_type'] as String?,
      desc: map['desc'] as String?,
      atk: map['atk'] as int?,
      def: map['def'] as int?,
      level: map['level'] as int?,
      race: map['race'] as String?,
      attribute: map['attribute'] as String?,
      imageUrlSmall: map['image_url_small'] as String?,
      imageUrl: map['image_url'] as String?,
      tcgplayerPrice: (map['tcgplayer_price'] as num?)?.toDouble(),
      cardmarketPrice: (map['cardmarket_price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'frame_type': frameType,
        'desc': desc,
        'atk': atk,
        'def': def,
        'level': level,
        'race': race,
        'attribute': attribute,
        'image_url_small': imageUrlSmall,
        'image_url': imageUrl,
        'tcgplayer_price': tcgplayerPrice,
        'cardmarket_price': cardmarketPrice,
      };
}
