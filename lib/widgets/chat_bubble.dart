import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../theme/app_theme.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case MessageType.system:
        return _system();
      case MessageType.incoming:
        return _incoming();
      case MessageType.outgoing:
        return _outgoing();
      case MessageType.sos:
        return _sos();
    }
  }

  Widget _system() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.08),
          border: Border.all(color: AppColors.accent.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Flexible(child: Text(message.content, style: const TextStyle(fontSize: 12, color: AppColors.text2))),
        ]),
      ),
    );
  }

  Widget _avatar(String? text, {bool isSos = false}) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSos ? AppColors.danger.withOpacity(0.2) : AppColors.surface3,
      ),
      alignment: Alignment.center,
      child: Text(text ?? '', style: TextStyle(fontSize: isSos ? 14 : 11, fontWeight: FontWeight.w700, color: AppColors.accent)),
    );
  }

  Widget _time() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(message.time, style: const TextStyle(fontSize: 10, color: AppColors.text3)),
      const SizedBox(width: 3),
      const Icon(Icons.done_all, size: 13, color: AppColors.primary),
    ]);
  }

  Widget _incoming() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        _avatar(message.avatar),
        const SizedBox(width: 8),
        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (message.senderName != null) Text(message.senderName!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.text3)),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4))),
            child: Text(message.content, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.text)),
          ),
          const SizedBox(height: 3),
          _time(),
        ])),
      ]),
    );
  }

  Widget _outgoing() {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF00694D), Color(0xFF004D3D)]),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4)),
          ),
          child: Text(message.content, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.text)),
        ),
        const SizedBox(height: 3),
        _time(),
      ]),
    );
  }

  Widget _sos() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        _avatar('🆘', isSos: true),
        const SizedBox(width: 8),
        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (message.senderName != null) Text(message.senderName!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.text3)),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.12),
              border: Border.all(color: AppColors.danger.withOpacity(0.25)),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.emergency, size: 18, color: AppColors.danger),
              const SizedBox(width: 6),
              Flexible(child: Text(message.content, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.danger))),
            ]),
          ),
          const SizedBox(height: 3),
          _time(),
        ])),
      ]),
    );
  }
}
