/// ESP32 /api/victims endpoint'inden dönen mağdur verisi modeli
class Victim {
  final String id;
  final String name;
  final String floor;
  final String people;
  final String battery;
  final String status; // "waiting" veya "rescued"
  final String? lat;   // Enlem (X)
  final String? lng;   // Boylam (Y)
  final String? alt;   // Yükseklik (Z)

  const Victim({
    required this.id,
    required this.name,
    required this.floor,
    required this.people,
    required this.battery,
    required this.status,
    this.lat,
    this.lng,
    this.alt,
  });

  bool get isWaiting => status == 'waiting';
  bool get isRescued => status == 'rescued';
  bool get isEmergency => status == 'emergency';
  bool get hasLocation => lat != null && lng != null && lat != "0" && lng != "0" && lat != "null" && lat != "";

  factory Victim.fromJson(Map<String, dynamic> json) {
    String? latStr = json['lat']?.toString();
    String? lngStr = json['lng']?.toString();
    String? altStr = json['alt']?.toString();
    
    // Geçersiz değerleri temizle
    if (latStr == "null" || latStr == "" || latStr == "0") latStr = null;
    if (lngStr == "null" || lngStr == "" || lngStr == "0") lngStr = null;
    if (altStr == "null" || altStr == "" || altStr == "0") altStr = null;

    return Victim(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      floor: json['floor']?.toString() ?? '',
      people: json['people']?.toString() ?? '',
      battery: json['battery']?.toString() ?? '',
      status: json['status']?.toString() ?? 'waiting',
      lat: latStr,
      lng: lngStr,
      alt: altStr,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'floor': floor,
      'people': people,
      'battery': battery,
      'status': status,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (alt != null) 'alt': alt,
    };
  }
}
