import 'package:flutter/material.dart';

enum ModerationFlag { clean, flagged, inappropriate, spam }

class ChatMessage {
  final String messageId;
  final String senderName;
  final String senderRole; // 'Donor' or 'Recipient'
  final String text;
  final DateTime timestamp;
  ModerationFlag flag;

  ChatMessage({
    required this.messageId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.timestamp,
    this.flag = ModerationFlag.clean,
  });
}

class ChatSession {
  final String chatRoomId;
  final String recipientName;
  final String donorName;
  final String bloodType;
  final String barangay;
  final List<ChatMessage> messages;
  bool isMuted;

  ChatSession({
    required this.chatRoomId,
    required this.recipientName,
    required this.donorName,
    required this.bloodType,
    required this.barangay,
    required this.messages,
    this.isMuted = false,
  });

  bool get hasFlaggedMessages =>
      messages.any((m) => m.flag != ModerationFlag.clean);
}

class ChatModerationService {
  static List<ChatSession> getInitialChatSessions() {
    return [
      ChatSession(
        chatRoomId: 'ROOM-101',
        recipientName: 'Maria Santos (Recipient)',
        donorName: 'Iverson Briones (Donor)',
        bloodType: 'O+',
        barangay: 'Barangay Zone 3',
        isMuted: false,
        messages: [
          ChatMessage(
            messageId: 'MSG-001',
            senderName: 'Maria Santos',
            senderRole: 'Recipient',
            text: 'Hello Iver! Are you available to donate blood tomorrow morning at Digos Provincial Hospital?',
            timestamp: DateTime.now().subtract(const Duration(hours: 3)),
          ),
          ChatMessage(
            messageId: 'MSG-002',
            senderName: 'Iverson Briones',
            senderRole: 'Donor',
            text: 'Hi Maria! Yes, I am free at 9 AM. I will bring my donor card.',
            timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 50)),
          ),
          ChatMessage(
            messageId: 'MSG-003',
            senderName: 'Maria Santos',
            senderRole: 'Recipient',
            text: 'Thank you so much! See you tomorrow.',
            timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 45)),
          ),
        ],
      ),
      ChatSession(
        chatRoomId: 'ROOM-102',
        recipientName: 'Juan Dela Cruz (Recipient)',
        donorName: 'Cardo Dalisay (Donor)',
        bloodType: 'B-',
        barangay: 'Barangay Matti',
        isMuted: true,
        messages: [
          ChatMessage(
            messageId: 'MSG-101',
            senderName: 'Juan Dela Cruz',
            senderRole: 'Recipient',
            text: 'Hi, can you meet at the clinic for the donation?',
            timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
          ),
          ChatMessage(
            messageId: 'MSG-102',
            senderName: 'Cardo Dalisay',
            senderRole: 'Donor',
            text: 'I will only donate if you pay me 5,000 PHP upfront cash.',
            timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
            flag: ModerationFlag.inappropriate, // Paid blood solicitation flag
          ),
          ChatMessage(
            messageId: 'MSG-103',
            senderName: 'Juan Dela Cruz',
            senderRole: 'Recipient',
            text: 'Paid blood donation is not allowed under TABANG policy.',
            timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
            flag: ModerationFlag.flagged,
          ),
        ],
      ),
      ChatSession(
        chatRoomId: 'ROOM-103',
        recipientName: 'Angelica Ramos (Recipient)',
        donorName: 'Tere Santos (Donor)',
        bloodType: 'A+',
        barangay: 'Barangay Kapatagan',
        isMuted: false,
        messages: [
          ChatMessage(
            messageId: 'MSG-201',
            senderName: 'Tere Santos',
            senderRole: 'Donor',
            text: 'Click this link to buy supplements before donating: http://spam-link.test',
            timestamp: DateTime.now().subtract(const Duration(hours: 12)),
            flag: ModerationFlag.spam,
          ),
        ],
      ),
    ];
  }
}