class PaymentMethodModel {
  final String id;
  final String type; // 'card', 'upi', etc.
  final String nickname;
  final String? last4;
  final String? cardNetwork;
  final String? upiId;
  final DateTime createdAt;

  PaymentMethodModel({
    required this.id,
    required this.type,
    required this.nickname,
    this.last4,
    this.cardNetwork,
    this.upiId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'nickname': nickname,
      'last4': last4,
      'cardNetwork': cardNetwork,
      'upiId': upiId,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory PaymentMethodModel.fromMap(Map<String, dynamic> map) {
    return PaymentMethodModel(
      id: map['id'] ?? '',
      type: map['type'] ?? 'card',
      nickname: map['nickname'] ?? '',
      last4: map['last4'],
      cardNetwork: map['cardNetwork'],
      upiId: map['upiId'],
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }
}


