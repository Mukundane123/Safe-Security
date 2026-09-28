import '../utils/datetime_util.dart';

/// A single message in an incident chat thread between a citizen and their
/// assigned responder.
class ChatMessage {
  final String messageId;
  final String incidentId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String text;
  final DateTime sentAt;
  final DateTime? readAt;

  const ChatMessage({
    required this.messageId,
    required this.incidentId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.sentAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  Map<String, dynamic> toMap() => {
        'messageId': messageId,
        'incidentId': incidentId,
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'text': text,
        'sentAt': sentAt,
        'readAt': readAt,
      };

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      messageId: (map['messageId'] as String?) ?? '',
      incidentId: (map['incidentId'] as String?) ?? '',
      senderId: (map['senderId'] as String?) ?? '',
      senderName: (map['senderName'] as String?) ?? '',
      senderRole: (map['senderRole'] as String?) ?? 'citizen',
      text: (map['text'] as String?) ?? '',
      sentAt: DateTimeUtil.parse(map['sentAt']) ?? DateTime.now(),
      readAt: DateTimeUtil.parse(map['readAt']),
    );
  }
}