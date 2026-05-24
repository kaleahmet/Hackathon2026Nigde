import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import '../models/sensor_data.dart';
import '../models/victim.dart';
import '../models/chat_message.dart';

/// ESP32 Mesh ağıyla HTTP üzerinden iletişim kuran servis.
///
/// ESP32 captive portal'ı WiFi üzerinden erişilebilir bir web sunucusu çalıştırır.
/// Bu servis, telefon/cihaz ESP32 AP'sine bağlıyken verileri çeker.
///
/// API Endpoint'leri (ESP32 tarafı):
///   GET  /api/sensors  → Sensör verileri (temp, hum, flame, quake, accel, floor, nodes)
///   GET  /api/victims  → Mağdur listesi
///   POST /api/victim   → Yeni mağdur kaydı
///   POST /api/rescue   → Mağdur kurtarma işareti
class Esp32Service extends ChangeNotifier {
  /// ESP32 Captive Portal DNS sunucusu tüm domainleri kendi IP'sine yönlendirir.
  /// Bu sayede 'vanguard.local' yazıldığında ESP32 otomatik olarak kendi güncel IP'sini (örn: 10.x.x.x) verir.
  String _baseUrl = 'http://vanguard.local';

  /// Bağlantı durumu
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// Son hata mesajı
  String? _lastError;
  String? get lastError => _lastError;

  /// Sensör verileri
  SensorData _sensorData = SensorData.empty;
  SensorData get sensorData => _sensorData;

  /// Mağdur listesi
  List<Victim> _victims = [];
  List<Victim> get victims => _victims;
  List<Victim> get activeVictims =>
      _victims.where((v) => v.isWaiting).toList();

  /// Sensör geçmişi (grafik çizimleri için son 60 okuma)
  final List<SensorData> _sensorHistory = [];
  List<SensorData> get sensorHistory => List.unmodifiable(_sensorHistory);

  /// Sohbet mesajları
  List<ChatMessage> _chatMessages = [];
  List<ChatMessage> get chatMessages => _chatMessages;

  /// Bu cihazın rastgele mesh ismi
  final String myName = 'Kullanıcı-${Random().nextInt(1000)}';

  /// Periyodik güncelleme timer'ları
  Timer? _sensorTimer;
  Timer? _victimTimer;
  Timer? _chatTimer;

  /// Bağlantı zaman aşımı süresi
  static const Duration _timeout = Duration(seconds: 5);

  /// Sensör güncelleme aralığı (ESP32 tarafında 2 saniyede bir okuyor)
  static const Duration _sensorInterval = Duration(seconds: 2);

  /// Mağdur listesi güncelleme aralığı
  static const Duration _victimInterval = Duration(seconds: 2);

  /// Ağ varsayılan base URL'ini değiştir
  void setBaseUrl(String url) {
    _baseUrl = url;
    notifyListeners();
  }

  String get baseUrl => _baseUrl;

  /// Periyodik veri çekmeyi başlat
  void startPolling() {
    stopPolling(); // Önceki timer'ları temizle

    // İlk çekimi hemen yap
    fetchSensors();
    fetchVictims();
    fetchChat();
    // Periyodik timer'ları kur
    _sensorTimer = Timer.periodic(_sensorInterval, (_) => fetchSensors());
    _victimTimer = Timer.periodic(_victimInterval, (_) => fetchVictims());
    _chatTimer = Timer.periodic(_sensorInterval, (_) => fetchChat());
  }

  /// Periyodik veri çekmeyi durdur
  void stopPolling() {
    _sensorTimer?.cancel();
    _victimTimer?.cancel();
    _chatTimer?.cancel();
    _sensorTimer = null;
    _victimTimer = null;
    _chatTimer = null;
  }

  /// ESP32'den sensör verilerini çek
  /// GET /api/sensors
  Future<void> fetchSensors() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/sensors'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _sensorData = SensorData.fromJson(json);
        _isConnected = true;
        _lastError = null;

        // Geçmişe ekle (max 60 kayıt)
        _sensorHistory.add(_sensorData);
        if (_sensorHistory.length > 60) {
          _sensorHistory.removeAt(0);
        }

        notifyListeners();
      } else {
        _handleError('Sensör verisi alınamadı (HTTP ${response.statusCode})');
      }
    } catch (e) {
      _handleError('ESP32 bağlantısı kurulamadı');
    }
  }

  /// ESP32'den mağdur listesini çek
  /// GET /api/victims
  Future<void> fetchVictims() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/victims'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonList = jsonDecode(response.body) as List<dynamic>;
        final List<Victim> rawList = jsonList.map((j) => Victim.fromJson(j as Map<String, dynamic>)).toList();
        
        // Önceliklendirme: emergency > waiting > rescued
        rawList.sort((a, b) {
          if (a.isEmergency && !b.isEmergency) return -1;
          if (!a.isEmergency && b.isEmergency) return 1;
          if (a.isWaiting && b.isRescued) return -1;
          if (a.isRescued && b.isWaiting) return 1;
          return 0;
        });
        
        _victims = rawList;
        _isConnected = true;
        _lastError = null;
        notifyListeners();
      } else {
        _handleError('Mağdur listesi alınamadı (HTTP ${response.statusCode})');
      }
    } catch (e) {
      _handleError('ESP32 bağlantısı kurulamadı');
    }
  }

  /// Yeni mağdur kaydı gönder
  /// POST /api/victim
  Future<bool> submitVictim({
    required String name,
    required String floor,
    required String people,
    required String battery,
  }) async {
    try {
      Position? pos;
      try {
        pos = await _getCurrentPosition();
      } catch (e) {
        debugPrint("Konum alınamadı: $e");
      }

      final body = jsonEncode({
        'id': 'v_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'floor': floor,
        'people': people,
        'battery': battery,
        'status': 'waiting',
        if (pos != null) 'lat': pos.latitude.toString(),
        if (pos != null) 'lng': pos.longitude.toString(),
        if (pos != null) 'alt': pos.altitude.toString(),
      });

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/victim'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        // Listeyi hemen yenile
        await fetchVictims();
        return true;
      }
      return false;
    } catch (e) {
      _handleError('Yardım çağrısı gönderilemedi');
      return false;
    }
  }

  /// Acil durum sinyali gönder (Panik Butonu)
  /// POST /api/emergency
  Future<bool> sendEmergencySOS() async {
    try {
      Position? pos;
      try {
        pos = await _getCurrentPosition();
      } catch (e) {
        debugPrint("Konum alınamadı: $e");
      }

      final body = jsonEncode({
        'id': 'EMERGENCY_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'ACİL YARDIM!',
        'floor': 'Bilinmiyor',
        'people': '1',
        'battery': '!', // Kritik işaret
        'status': 'emergency',
        if (pos != null) 'lat': pos.latitude.toString(),
        if (pos != null) 'lng': pos.longitude.toString(),
        if (pos != null) 'alt': pos.altitude.toString(),
      });

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/emergency'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      _handleError('Acil sinyal gönderilemedi');
      return false;
    }
  }

  /// Mağduru kurtarıldı olarak işaretle
  /// POST /api/rescue
  Future<bool> rescueVictim(String victimId) async {
    try {
      final body = jsonEncode({'id': victimId});

      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/rescue'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        // Listeyi hemen yenile
        await fetchVictims();
        return true;
      }
      return false;
    } catch (e) {
      _handleError('Kurtarma işlemi gönderilemedi');
      return false;
    }
  }

  /// ESP32'den sohbet geçmişini çek (GET /api/chat)
  Future<void> fetchChat() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/chat')).timeout(_timeout);
      if (response.statusCode == 200) {
        final jsonList = jsonDecode(response.body) as List<dynamic>;
        _chatMessages = jsonList.map((j) => ChatMessage.fromJson(j as Map<String, dynamic>, myName)).toList();
        notifyListeners();
      }
    } catch (e) {
      // Arka plan chat polling hatalarını sessizce yoksayabiliriz
    }
  }

  /// Mesh ağına yeni sohbet mesajı gönder (POST /api/chat)
  Future<bool> sendChatMessage(String content, {bool isSos = false}) async {
    // 1. Optimistic Update (Arayüzde hemen göster)
    final tempMsg = ChatMessage(
      senderName: myName,
      avatar: isSos ? '🆘' : myName.substring(0, 1).toUpperCase(),
      content: content,
      time: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      type: isSos ? MessageType.sos : MessageType.outgoing,
      isUrgent: isSos,
    );
    _chatMessages.add(tempMsg);
    notifyListeners();

    try {
      final body = jsonEncode({
        'sender': isSos ? 'SOS · $myName' : myName,
        'content': content,
        'time': tempMsg.time,
        'isSos': isSos ? 1 : 0,
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        await fetchChat(); // Sunucudan kesinleşmiş listeyi çek
        return true;
      }
      
      // Hata durumunda mesajı listeden geri çek
      _chatMessages.remove(tempMsg);
      notifyListeners();
      return false;
    } catch (e) {
      _chatMessages.remove(tempMsg);
      notifyListeners();
      return false;
    }
  }

  void _handleError(String message) {
    _isConnected = false;
    _lastError = message;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
  /// Mevcut konumu al
  Future<Position?> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 5),
    );
  }
}
