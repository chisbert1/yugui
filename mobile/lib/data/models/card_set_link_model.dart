// lib/data/models/card_set_link_model.dart
// ----------------------------------------
// Represents a specific printing of a card in an expansion set.

class CardSetLinkModel {
  final int id;
  final int cardId;
  final int setId;
  final String setCode;
  final String? setRarity;
  final String? setRarityCode;
  final double? setPrice;

  // Joined fields from master_cards and master_sets
  final String? cardName;
  final String? setName;
  final String? imageUrlSmall;
  final String? imageUrl;
  final String? type;
  final String? frameType;
  final String? desc;
  final int? atk;
  final int? def;
  final int? level;
  final String? attribute;

  CardSetLinkModel({
    required this.id,
    required this.cardId,
    required this.setId,
    required this.setCode,
    this.setRarity,
    this.setRarityCode,
    this.setPrice,
    this.cardName,
    this.setName,
    this.imageUrlSmall,
    this.imageUrl,
    this.type,
    this.frameType,
    this.desc,
    this.atk,
    this.def,
    this.level,
    this.attribute,
  });

  factory CardSetLinkModel.fromMap(Map<String, dynamic> map) {
    return CardSetLinkModel(
      id: map['id'] as int,
      cardId: (map['card_id'] as int?) ?? 0,
      setId: (map['set_id'] as int?) ?? 0,
      setCode: map['set_code'] as String,
      setRarity: map['set_rarity'] as String?,
      setRarityCode: map['set_rarity_code'] as String?,
      setPrice: (map['set_price'] as num?)?.toDouble(),
      cardName: (map['card_name'] ?? map['name']) as String?,
      setName: map['set_name'] as String?,
      imageUrlSmall: map['image_url_small'] as String?,
      imageUrl: map['image_url'] as String?,
      type: map['type'] as String?,
      frameType: map['frame_type'] as String?,
      desc: map['desc'] as String?,
      atk: map['atk'] as int?,
      def: map['def'] as int?,
      level: map['level'] as int?,
      attribute: map['attribute'] as String?,
    );
  }
}
