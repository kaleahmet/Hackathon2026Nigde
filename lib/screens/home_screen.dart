import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/esp32_service.dart';
import '../theme/app_theme.dart';
import '../widgets/alert_banner.dart';
import '../widgets/stat_card.dart';
import '../widgets/sensor_card.dart';

// Çevrimdışı kullanım için siren sesi asset olarak kullanılacaktır.
const String _sirenAsset = 'alarm.mp3';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isWhistlePlaying = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      // Kaynağı önceden yükle (Çevrimdışı kullanım için AssetSource kullanılır)
      await _audioPlayer.setSource(AssetSource(_sirenAsset));
      await _audioPlayer.setVolume(1.0);
    } catch (e) {
      debugPrint("Ses başlatma hatası: $e");
    }
  }

  Future<void> _startWhistle() async {
    if (_isWhistlePlaying) return;
    try {
      await _audioPlayer.resume();
      setState(() => _isWhistlePlaying = true);
    } catch (e) {
      debugPrint("Siren çalma hatası: $e");
    }
  }

  Future<void> _stopWhistle() async {
    try {
      await _audioPlayer.pause();
      await _audioPlayer.seek(Duration.zero);
      setState(() => _isWhistlePlaying = false);
    } catch (e) {
      debugPrint("Siren durdurma hatası: $e");
    }
  }

  String _currentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _showEmergency() {
    final esp = context.read<Esp32Service>();
    // SOS Gönder (GPS ve Mesh Yayını)
    esp.sendEmergencySOS();
    // Otomatik düdük başlat (isteğe bağlı ama özgün bir dokunuş)
    _startWhistle();
    
    showDialog(
      context: context,
      barrierColor: const Color(0x26FF1E32),
      builder: (_) => _EmergencyOverlay(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Esp32Service>(
      builder: (context, esp, child) {
        final data = esp.sensorData;
        final connected = esp.isConnected;
        final activeAlerts = <String>[];
        if (data.flameDetected) activeAlerts.add('Yangın Algılandı!');
        if (data.earthquakeDetected) activeAlerts.add('Sarsıntı Algılandı!');
        if (data.temperature > 50) activeAlerts.add('Kritik Sıcaklık!');
        if (_isWhistlePlaying) activeAlerts.add('Acil Düdük Aktif!');

        return Column(children: [
          // Status bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 50, 24, 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_currentTime(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: connected
                        ? AppColors.primary.withOpacity(0.12)
                        : AppColors.danger.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      connected ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                      size: 12,
                      color: connected ? AppColors.primary : AppColors.danger,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      connected ? 'Mesh' : 'Bağlantı yok',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: connected ? AppColors.primary : AppColors.danger,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.battery_5_bar, size: 16, color: AppColors.text2),
              ]),
            ]),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Vanguard', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: AppColors.text)),
                const SizedBox(height: 2),
                Row(children: [
                  const Text('Ağ Durumu: ', style: TextStyle(fontSize: 12, color: AppColors.text2)),
                  Text(
                    connected ? 'Aktif' : 'Çevrimdışı',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: connected ? AppColors.primary : AppColors.danger,
                    ),
                  ),
                ]),
              ]),
              GestureDetector(
                onTap: () => _showConnectionSettings(context, esp),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface2, border: Border.all(color: AppColors.surface3, width: 2)),
                  child: const Icon(Icons.settings, size: 20, color: AppColors.text2),
                ),
              ),
            ]),
          ),
          // Scrollable content
          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
              // Dinamik alert banner'lar
              if (data.earthquakeDetected)
                AlertBanner(
                  title: 'Sismik Aktivite Algılandı',
                  subtitle: 'Kat ${data.floorId} · ${data.totalAccel.toStringAsFixed(2)}g · Canlı',
                  alertColor: AppColors.danger,
                  icon: Icons.vibration,
                ),
              if (data.flameDetected)
                AlertBanner(
                  title: 'Yangın Algılandı!',
                  subtitle: 'Kat ${data.floorId} · Alev: ${data.flameIntensityPercent.toStringAsFixed(0)}% · Sıcaklık: ${data.temperature.toStringAsFixed(1)}°C',
                  alertColor: const Color(0xFFFF6B35),
                  icon: Icons.local_fire_department,
                ),
              if (data.temperature > 50)
                AlertBanner(
                  title: 'Yüksek Sıcaklık Uyarısı',
                  subtitle: 'Kat ${data.floorId} · ${data.temperature.toStringAsFixed(1)}°C',
                  alertColor: AppColors.warn,
                  icon: Icons.thermostat,
                ),
              if (!connected && esp.lastError != null)
                AlertBanner(
                  title: 'ESP32 Bağlantısı Kesildi',
                  subtitle: esp.lastError!,
                  alertColor: AppColors.text3,
                  icon: Icons.wifi_off,
                ),
              // Stats section
              _sectionLabel('AĞ İSTATİSTİKLERİ'),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.95,
                children: [
                  StatCard(icon: Icons.developer_board, value: '${data.nodeCount}', label: 'Aktif Düğüm', trend: connected ? 'Çevrimiçi' : 'Çevrimdışı', isTrendWarn: !connected, iconBgColor: AppColors.primary.withOpacity(0.12), iconColor: AppColors.primary),
                  StatCard(icon: Icons.hub, value: connected ? '100' : '0', valueSuffix: '%', label: 'Ağ Sağlığı', trend: connected ? 'Optimal' : 'Bağlantı yok', isTrendWarn: !connected, iconBgColor: AppColors.accent.withOpacity(0.12), iconColor: AppColors.accent),
                  StatCard(icon: Icons.people, value: '${esp.activeVictims.length}', label: 'Aktif Çağrı', trend: esp.activeVictims.isEmpty ? 'Yok' : 'Dikkat!', isTrendWarn: esp.activeVictims.isNotEmpty, iconBgColor: AppColors.purple.withOpacity(0.12), iconColor: AppColors.purple),
                  StatCard(icon: Icons.notifications_active, value: '${activeAlerts.length}', label: 'Aktif Uyarı', trend: activeAlerts.isEmpty ? 'Normal' : 'Dikkat', isTrendWarn: activeAlerts.isNotEmpty, iconBgColor: AppColors.danger.withOpacity(0.12), iconColor: AppColors.danger),
                ],
              ),
              // Sensors section — ESP32'den gelen gerçek verilerle
              _sectionLabel('SENSÖR DURUMU'),
              SensorCard(
                type: SensorType.earthquake,
                isActive: data.earthquakeDetected,
                metaLeft: 'MPU9250 · Kat ${data.floorId}',
                metaRight: '${data.totalAccel.toStringAsFixed(3)}g',
                accelX: data.accelX,
                accelY: data.accelY,
                accelZ: data.accelZ,
              ),
              const SizedBox(height: 10),
              SensorCard(
                type: SensorType.fire,
                isActive: data.flameDetected,
                metaLeft: 'IR Sensör · Kat ${data.floorId}',
                metaRight: '${data.temperature.toStringAsFixed(1)}°C',
                flameIntensity: data.flameIntensityPercent / 100,
              ),
              const SizedBox(height: 10),
              SensorCard(
                type: SensorType.temperature,
                isActive: data.temperature > 40,
                metaLeft: 'DHT22 · Kat ${data.floorId}',
                metaRight: 'Güncellendi: 2s',
                temperature: data.temperature,
                humidity: data.humidity,
              ),
              // Quick actions
              _sectionLabel('HIZLI İŞLEMLER'),
              Row(children: [
                _actionBtn(Icons.emergency_share, 'Acil Durum', isEmergency: true, onTap: _showEmergency),
                const SizedBox(width: 10),
                _actionBtn(
                  Icons.volume_up,
                  'Bas-Çal Düdük',
                  isEmergency: _isWhistlePlaying,
                  onTapDown: (_) => _startWhistle(),
                  onTapUp: (_) => _stopWhistle(),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _actionBtn(Icons.chat, 'Mesh Chat', onTap: () => widget.onNavigate(1)),
                const SizedBox(width: 10),
                _actionBtn(Icons.health_and_safety, 'Kurtarma', onTap: () => widget.onNavigate(2)),
                const SizedBox(width: 10),
                _actionBtn(Icons.account_tree, 'Topoloji', onTap: () => widget.onNavigate(3)),
              ]),
              const SizedBox(height: 80),
            ]),
          ),
        ]);
      },
    );
  }

  void _showConnectionSettings(BuildContext context, Esp32Service esp) {
    final controller = TextEditingController(text: esp.baseUrl);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('ESP32 Bağlantı Ayarları', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 4),
          Text(
            esp.isConnected ? '✅ Bağlı' : '❌ Bağlantı yok',
            style: TextStyle(fontSize: 12, color: esp.isConnected ? AppColors.primary : AppColors.danger),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            style: const TextStyle(fontSize: 14, color: AppColors.text),
            decoration: InputDecoration(
              labelText: 'ESP32 IP Adresi',
              labelStyle: const TextStyle(color: AppColors.text2),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.wifi, color: AppColors.text3),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  esp.setBaseUrl(controller.text.trim());
                  esp.startPolling();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Bağlan', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  esp.stopPolling();
                  Navigator.pop(ctx);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text2,
                  side: const BorderSide(color: AppColors.surface3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Bağlantıyı Kes'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text3, letterSpacing: 1.5)),
    );
  }

  Widget _actionBtn(IconData icon, String label, {bool isEmergency = false, VoidCallback? onTap, Function(TapDownDetails)? onTapDown, Function(TapUpDetails)? onTapUp}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        onTapDown: onTapDown,
        onTapUp: onTapUp,
        onTapCancel: _stopWhistle,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          decoration: BoxDecoration(
            color: isEmergency ? null : AppColors.surface,
            gradient: isEmergency ? LinearGradient(colors: [AppColors.danger.withOpacity(0.15), AppColors.danger.withOpacity(0.05)]) : null,
            border: Border.all(color: isEmergency ? AppColors.danger.withOpacity(0.3) : AppColors.surface3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 24, color: isEmergency ? AppColors.danger : AppColors.accent),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isEmergency ? AppColors.danger : AppColors.text), textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

class _EmergencyOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ColorFilter.mode(AppColors.danger.withOpacity(0.15), BlendMode.srcOver),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.warning_rounded, size: 80, color: AppColors.danger),
        const SizedBox(height: 16),
        Text('ACİL DURUM AKTIF', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, decoration: TextDecoration.none)),
        const SizedBox(height: 8),
        Text('GPS konumunuz ve SOS sinyaliniz tüm ağa yayılıyor...', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7), decoration: TextDecoration.none)),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white.withOpacity(0.2)), borderRadius: BorderRadius.circular(25)),
            child: const Text('İptal Et', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, decoration: TextDecoration.none)),
          ),
        ),
      ])),
    );
  }
}
