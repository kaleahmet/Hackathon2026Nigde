import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/esp32_service.dart';
import '../models/victim.dart';
import '../theme/app_theme.dart';
import '../widgets/floor_card.dart';
import '../widgets/risk_gauge.dart';

class RescueScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const RescueScreen({super.key, this.onNavigate});
  @override
  State<RescueScreen> createState() => _RescueScreenState();
}

class _RescueScreenState extends State<RescueScreen> {
  bool _isRescueMode = false; // PIN doğrulandı mı

  void _checkPin(String pin) {
    if (pin == '1122') {
      setState(() => _isRescueMode = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hatalı PIN!'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Esp32Service>(
      builder: (context, esp, child) {
        final data = esp.sensorData;
        final victims = esp.victims;
        final activeVictims = esp.activeVictims;

        // Toplam risk skoru hesapla
        int riskScore = 0;
        if (data.earthquakeDetected) riskScore += 40;
        if (data.flameDetected) riskScore += 35;
        if (data.temperature > 40) riskScore += 15;
        if (activeVictims.isNotEmpty) riskScore += 10;
        riskScore = riskScore.clamp(0, 100);

        return Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 12),
            color: AppColors.bg,
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => widget.onNavigate?.call(0)),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Rescue Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                Text(
                  esp.isConnected
                      ? 'Kat ${data.floorId} · ${data.nodeCount} düğüm · Canlı'
                      : 'ESP32 bağlantısı bekleniyor...',
                  style: const TextStyle(fontSize: 11, color: AppColors.text2),
                ),
              ])),
              if (_isRescueMode)
                GestureDetector(
                  onTap: () => _showVictimForm(context, esp),
                  child: const Icon(Icons.person_add, color: AppColors.primary, size: 22),
                ),
            ]),
          ),
          Expanded(
            child: _isRescueMode
                ? _buildRescueDashboard(esp, data, victims, activeVictims, riskScore)
                : _buildLoginOrVictimView(esp, data, riskScore),
          ),
        ]);
      },
    );
  }

  /// Afetzede girişi ve PIN login ekranı
  Widget _buildLoginOrVictimView(Esp32Service esp, sensorData, int riskScore) {
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      const SizedBox(height: 20),
      // Afetzede yardım çağrısı formu
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.danger.withOpacity(0.08), AppColors.surface],
          ),
          border: Border.all(color: AppColors.danger.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        child: Column(children: [
          const Icon(Icons.sos, size: 48, color: AppColors.danger),
          const SizedBox(height: 12),
          const Text('Yardım Çağrısı Oluştur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 4),
          const Text('Afetzede iseniz bilgilerinizi girin', style: TextStyle(fontSize: 12, color: AppColors.text2)),
          const SizedBox(height: 20),
          _VictimForm(esp: esp),
        ]),
      ),
      const SizedBox(height: 20),
      // Kurtarma ekibi giriş
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.surface3),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        child: Column(children: [
          const Icon(Icons.shield, size: 36, color: AppColors.accent),
          const SizedBox(height: 8),
          const Text('Kurtarma Ekibi Girişi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 16),
          _PinLogin(onSubmit: _checkPin),
        ]),
      ),
      const SizedBox(height: 80),
    ]);
  }

  /// Kurtarma dashboard — aktif mağdurlar ve kat analizi
  Widget _buildRescueDashboard(Esp32Service esp, sensorData, List<Victim> allVictims, List<Victim> activeVictims, int riskScore) {
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      // Building overview
      Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.surface3),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kat ${sensorData.floorId} · ESP32 Düğüm', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 4),
            Text('${sensorData.nodeCount} Düğüm · ${activeVictims.length} Çağrı · Canlı', style: const TextStyle(fontSize: 11, color: AppColors.text2)),
          ])),
          RiskGauge(riskValue: riskScore),
        ]),
      ),
      // Aktif mağdurlar
      if (activeVictims.isNotEmpty) ...[
        _sectionLabel('AKTİF YARDIM ÇAĞRILARI'),
        ...activeVictims.map((v) => _victimCard(v, esp)),
      ],
      // Kurtarılan mağdurlar
      if (allVictims.where((v) => v.isRescued).isNotEmpty) ...[
        _sectionLabel('KURTARILANLAR'),
        ...allVictims.where((v) => v.isRescued).map((v) => _rescuedCard(v)),
      ],
      if (allVictims.isEmpty) ...[
        _sectionLabel('MAĞDUR LİSTESİ'),
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.surface3),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          child: Column(children: [
            Icon(Icons.check_circle_outline, size: 48, color: AppColors.primary.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text('Aktif yardım çağrısı yok', style: TextStyle(fontSize: 14, color: AppColors.text2)),
          ]),
        ),
      ],
      // Kat bazlı sensör durumu
      _sectionLabel('KAT BAZLI SENSÖR ANALİZİ'),
      FloorCard(
        floorNumber: sensorData.floorId,
        floorName: 'Kat ${sensorData.floorId} · Bu Düğüm',
        risk: sensorData.earthquakeDetected || sensorData.flameDetected
            ? RiskLevel.high
            : sensorData.temperature > 35
                ? RiskLevel.medium
                : RiskLevel.low,
        score: riskScore,
        vibration: 'Sarsıntı: ${sensorData.totalAccel.toStringAsFixed(2)}g',
        temperature: 'Sıcaklık: ${sensorData.temperature.toStringAsFixed(1)}°C${sensorData.temperature > 40 ? " ⚠️" : ""}',
        people: '${activeVictims.length} kişi bekliyor',
        nodes: '${sensorData.nodeCount} düğüm aktif',
      ),
      const SizedBox(height: 80),
    ]);
  }

  Widget _victimCard(Victim victim, Esp32Service esp) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.surface3),
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 4, color: AppColors.danger),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(victim.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('BEKLİYOR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.danger, letterSpacing: 0.5)),
                  ),
                ]),
                const SizedBox(height: 8),
                _detailRow(Icons.layers, 'Kat: ${victim.floor}'),
                _detailRow(Icons.people, 'Kişi: ${victim.people}'),
                _detailRow(Icons.battery_charging_full, 'Şarj: %${victim.battery}'),
                if (victim.hasLocation)
                  _detailRow(Icons.location_on, 'Konum (X,Y,Z): ${victim.lat}, ${victim.lng}, ${victim.alt}'),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: const Text('Kurtarma Onayı', style: TextStyle(color: AppColors.text)),
                          content: Text('${victim.name} için kurtarma operasyonunu üstlendiğinizi onaylıyor musunuz?', style: const TextStyle(color: AppColors.text2)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                              child: const Text('Onayla'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await esp.rescueVictim(victim.id);
                      }
                    },
                    icon: const Icon(Icons.health_and_safety, size: 18),
                    label: const Text('KURTARMAYA GİDİYORUM'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.bg,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _rescuedCard(Victim victim) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Icon(Icons.check_circle, color: AppColors.primary.withOpacity(0.6), size: 24),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(victim.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text.withOpacity(0.5), decoration: TextDecoration.lineThrough)),
          Text('Kat ${victim.floor} · ${victim.people} kişi', style: TextStyle(fontSize: 11, color: AppColors.text3)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('KURTARILDI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.5)),
        ),
      ]),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, size: 14, color: AppColors.text3),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.text2), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  void _showVictimForm(BuildContext context, Esp32Service esp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: _VictimForm(esp: esp, onSuccess: () => Navigator.pop(ctx)),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text3, letterSpacing: 1.5)),
    );
  }
}

/// Afetzede kayıt formu
class _VictimForm extends StatefulWidget {
  final Esp32Service esp;
  final VoidCallback? onSuccess;
  const _VictimForm({required this.esp, this.onSuccess});

  @override
  State<_VictimForm> createState() => _VictimFormState();
}

class _VictimFormState extends State<_VictimForm> {
  final _nameCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _peopleCtrl = TextEditingController();
  final _batteryCtrl = TextEditingController();
  bool _sending = false;
  bool _success = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _floorCtrl.dispose();
    _peopleCtrl.dispose();
    _batteryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty || _floorCtrl.text.isEmpty || _peopleCtrl.text.isEmpty || _batteryCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tüm alanları doldurun'), backgroundColor: AppColors.warn),
      );
      return;
    }
    setState(() => _sending = true);
    final ok = await widget.esp.submitVictim(
      name: _nameCtrl.text,
      floor: _floorCtrl.text,
      people: _peopleCtrl.text,
      battery: _batteryCtrl.text,
    );
    setState(() {
      _sending = false;
      _success = ok;
    });
    if (ok) {
      widget.onSuccess?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Yardım çağrınız iletildi! Lütfen konumunuzu terk etmeyin.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Çağrı gönderilemedi. ESP32 bağlantısını kontrol edin.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle, size: 48, color: AppColors.primary),
        const SizedBox(height: 12),
        const Text('Yardım çağrınız iletildi!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary)),
        const SizedBox(height: 4),
        const Text('Lütfen konumunuzu terk etmeyin.', style: TextStyle(fontSize: 12, color: AppColors.text2)),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: () => setState(() => _success = false),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Geri Dön'),
          style: TextButton.styleFrom(foregroundColor: AppColors.text3),
        ),
      ]);
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      _input(_nameCtrl, 'İsim Soyisim', Icons.person),
      _input(_floorCtrl, 'Bulunduğunuz Kat', Icons.layers, isNumber: true),
      _input(_peopleCtrl, 'Yanınızdaki Kişi Sayısı', Icons.people, isNumber: true),
      _input(_batteryCtrl, 'Telefon Şarjınız (%)', Icons.battery_full, isNumber: true),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _sending ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _sending
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('YARDIM İSTE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ),
    ]);
  }

  Widget _input(TextEditingController ctrl, String hint, IconData icon, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 14, color: AppColors.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.text3),
          filled: true,
          fillColor: AppColors.surface2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          prefixIcon: Icon(icon, color: AppColors.text3, size: 20),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

/// PIN giriş widget'ı
class _PinLogin extends StatefulWidget {
  final Function(String) onSubmit;
  const _PinLogin({required this.onSubmit});

  @override
  State<_PinLogin> createState() => _PinLoginState();
}

class _PinLoginState extends State<_PinLogin> {
  final _pinCtrl = TextEditingController();

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(
        controller: _pinCtrl,
        obscureText: true,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 18, color: AppColors.text, letterSpacing: 8),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: 'PIN Kodu',
          hintStyle: const TextStyle(color: AppColors.text3, letterSpacing: 2),
          filled: true,
          fillColor: AppColors.surface2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => widget.onSubmit(_pinCtrl.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.bg,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('GİRİŞ YAP', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }
}
