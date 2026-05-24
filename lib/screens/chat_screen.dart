import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../services/esp32_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const ChatScreen({super.key, this.onNavigate});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(BuildContext context) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    
    final esp = context.read<Esp32Service>();
    await esp.sendChatMessage(text);
    _scrollToBottom();
  }

  void _sendSOS(BuildContext context) async {
    final esp = context.read<Esp32Service>();
    await esp.sendChatMessage('ACİL YARDIM TALEBİ! Konum paylaşıldı.', isSos: true);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Esp32Service>(
      builder: (context, esp, child) {
        final data = esp.sensorData;
        return Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 12),
            color: AppColors.bg,
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => widget.onNavigate?.call(0)),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Mesh Chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                Text(
                  esp.isConnected
                      ? '${data.nodeCount} düğüm çevrimiçi · İnternetsiz Mod'
                      : 'Bağlantı bekleniyor · İnternetsiz Mod',
                  style: const TextStyle(fontSize: 11, color: AppColors.text2),
                ),
              ])),
              const Icon(Icons.more_vert, color: AppColors.text2, size: 22),
            ]),
          ),
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: esp.chatMessages.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Center(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
                    child: const Text('Bugün · Offline Mesh', style: TextStyle(fontSize: 11, color: AppColors.text3)),
                  ));
                }
                return Padding(padding: const EdgeInsets.only(bottom: 10), child: ChatBubble(message: esp.chatMessages[i - 1]));
              },
            ),
          ),
          // Input area
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
            decoration: const BoxDecoration(color: AppColors.bg, border: Border(top: BorderSide(color: AppColors.surface3))),
            child: Row(children: [
              const Icon(Icons.add_circle, size: 26, color: AppColors.text3),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(22)),
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(fontSize: 14, color: AppColors.text),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'Mesh üzerinden mesaj yaz...', hintStyle: TextStyle(color: AppColors.text3)),
                    onSubmitted: (_) => _send(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // SOS button
              GestureDetector(
                onTap: () => _sendSOS(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.danger, Color(0xFFCC2233)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.danger.withOpacity(0.3), blurRadius: 8)],
                  ),
                  child: const Text('SOS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _send(context),
                child: Container(
                  width: 38, height: 38,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                  child: const Icon(Icons.send, size: 20, color: AppColors.bg),
                ),
              ),
            ]),
          ),
        ]);
      },
    );
  }
}
