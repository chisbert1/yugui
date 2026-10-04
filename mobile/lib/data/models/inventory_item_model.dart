// lib/data/models/inventory_item_model.dart
// ----------------------------------------
// Represents a user's collected card in their digital binder / inventory.

class InventoryItemModel {
  final int? id;
  final int cardId;
  final int cardSetLinkId;
  final String setCode;
  final String name;
  final String? setName;
  final String? rarity;
  final String? imageUrlSmall;
  final String edition;
  final String condition;
  final int quantity;
  final bool isWishlist;
  final double? price;
  final String? notes;
  final int updatedAt;

  InventoryItemModel({
    this.id,
    required this.cardId,
    required this.cardSetLinkId,
    required this.setCode,
    required this.name,
    this.setName,
    this.rarity,
    this.imageUrlSmall,
    required this.edition,
    required this.condition,
    required this.quantity,
    this.isWishlist = false,
    this.price,
    this.notes,
    required this.updatedAt,
  });

  factory InventoryItemModel.fromMap(Map<String, dynamic> map) {
    return InventoryItemModel(
      id: map['id'] as int?,
      cardId: (map['card_id'] as int?) ?? 0,
      cardSetLinkId: (map['card_set_link_id'] as int?) ?? 0,
      setCode: map['set_code'] as String,
      name: (map['name'] ?? map['card_name']) as String? ?? 'Desconocida',
      setName: map['set_name'] as String?,
      rarity: (map['rarity'] ?? map['set_rarity']) as String?,
      imageUrlSmall: map['image_url_small'] as String?,
      edition: (map['edition'] as String?) ?? '1st Edition',
      condition: (map['condition'] as String?) ?? 'Near Mint',
      quantity: (map['quantity'] as int?) ?? 1,
      isWishlist: (map['is_wishlist'] == 1 || map['is_wishlist'] == true),
      price: (map['price'] as num?)?.toDouble() ?? (map['set_price'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      updatedAt: (map['updated_at'] is int)
          ? map['updated_at'] as int
          : DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'card_id': cardId,
        'card_set_link_id': cardSetLinkId,
        'set_code': setCode,
        'name': name,
        'set_name': setName,
        'rarity': rarity,
        'image_url_small': imageUrlSmall,
        'edition': edition,
        'condition': condition,
        'quantity': quantity,
        'is_wishlist': isWishlist ? 1 : 0,
        'price': price,
        'notes': notes,
        'updated_at': updatedAt,
      };

  InventoryItemModel copyWith({
    int? id,
    int? cardId,
    int? cardSetLinkId,
    String? setCode,
    String? name,
    String? setName,
    String? rarity,
    String? imageUrlSmall,
    String? edition,
    String? condition,
    int? quantity,
    bool? isWishlist,
    double? price,
    String? notes,
    int? updatedAt,
  }) {
    return InventoryItemModel(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      cardSetLinkId: cardSetLinkId ?? this.cardSetLinkId,
      setCode: setCode ?? this.setCode,
      name: name ?? this.name,
      setName: setName ?? this.setName,
      rarity: rarity ?? this.rarity,
      imageUrlSmall: imageUrlSmall ?? this.imageUrlSmall,
      edition: edition ?? this.edition,
      condition: condition ?? this.condition,
      quantity: quantity ?? this.quantity,
      isWishlist: isWishlist ?? this.isWishlist,
      price: price ?? this.price,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
