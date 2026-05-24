enum MessageType { incoming, outgoing, system, sos }

class ChatMessage {
  final String? senderName;
  final String? avatar;
  final String content;
  final String time;
  final MessageType type;
  final bool isUrgent;

  const ChatMessage({
    this.senderName,
    this.avatar,
    required this.content,
    required this.time,
    required this.type,
    this.isUrgent = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String myName) {
    final sender = json['sender'] as String? ?? 'Bilinmeyen';
    final isSos = json['isSos'] == true;
    final isMe = sender == myName;

    return ChatMessage(
      senderName: sender,
      avatar: isSos ? '🆘' : (sender.isNotEmpty ? sender.substring(0, 1).toUpperCase() : '?'),
      content: json['content'] as String? ?? '',
      time: json['time'] as String? ?? '',
      type: isMe ? MessageType.outgoing : (isSos ? MessageType.sos : MessageType.incoming),
      isUrgent: isSos,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender': senderName,
      'content': content,
      'time': time,
      'isSos': isUrgent,
    };
  }

  static List<ChatMessage> get sampleMessages => [
        const ChatMessage(
          content: 'Mesh ağı aktif. Tüm mesajlar şifreli olarak iletiliyor.',
          time: '',
          type: MessageType.system,
        ),
        const ChatMessage(
          senderName: 'Ahmet Yılmaz · Kat 2',
          avatar: 'AY',
          content: 'Kat 2\'de herkes güvende. Su ve yiyecek yeterli durumda.',
          time: '14:28',
          type: MessageType.incoming,
        ),
        const ChatMessage(
          senderName: 'Elif Kaya · Kat 4',
          avatar: 'EK',
          content: 'Kat 4\'te 2 kişi yaralı. Acil tıbbi yardım gerekiyor!',
          time: '14:30',
          type: MessageType.incoming,
        ),
        const ChatMessage(
          senderName: 'SOS · Düğüm #7 (Kat 5)',
          avatar: '🆘',
          content: 'ACİL: Kat 5 merdiven çıkışı kapalı. 4 kişi mahsur!',
          time: '14:31',
          type: MessageType.sos,
          isUrgent: true,
        ),
        const ChatMessage(
          content: 'Kat 3\'ten tahliye devam ediyor. Merdiven A kullanılabilir.',
          time: '14:32',
          type: MessageType.outgoing,
        ),
      ];
}
