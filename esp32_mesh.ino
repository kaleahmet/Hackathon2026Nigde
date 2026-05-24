#include "painlessMesh.h"
#include <ESPAsyncWebServer.h>
#include <DNSServer.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <DHT.h>

// --- AĞ AYARLARI ---
#define MESH_PREFIX   "AFET_YARDIM_AGI"
#define MESH_PASSWORD ""
#define MESH_PORT     5555

// !! BU DEGERI HER ESP ICIN DEGISTIR !!
// ESP-1 = 1, ESP-2 = 2
#define FLOOR_ID      1

// --- SENSOR PINLERİ ---
#define DHT_PIN       4
#define DHT_TYPE      DHT22
#define FLAME_DO_PIN  13    // Dijital cikis
#define FLAME_AO_PIN  34    // Analog cikis
#define MPU_SDA       21
#define MPU_SCL       22
#define MPU_ADDR      0x68
#define EMERGENCY_LED_PIN 2 // Dahili LED veya harici LED pin


// --- DEĞİŞKENLER ---
Scheduler userScheduler;
painlessMesh mesh;
AsyncWebServer server(80);
DNSServer dnsServer;
DHT dht(DHT_PIN, DHT_TYPE);
bool dnsStarted = false;
IPAddress myAPIP(0,0,0,0);
int meshNodeCount = 1; // Mesh agindaki toplam dugum sayisi

// FreeRTOS Kuyrugu (AsyncWebServer ile Mesh arasindaki thread-safe iletisim icin)
QueueHandle_t broadcastQueue;

// Sensor verileri
float temperature = 0, humidity = 0;
float accelX = 0, accelY = 0, accelZ = 0;
float gyroX = 0, gyroY = 0, gyroZ = 0;
int flameAnalog = 0;
bool flameDetected = false;
bool earthquakeDetected = false;
bool localEmergencyActive = false; // Telefon butonuna basildiginda tetiklenir


// --- ESIK DEGERLERI (HASSASIYET AYARLARI) ---
// Deprem: Normal yercekimi 1.0g (9.81 m/s²). Sapma ne kadar kucukse o kadar hassas.
// 0.05g = cok hassas (masaya vurmak bile tetikler)
// 0.15g = orta hassasiyet
// 0.50g = dusuk hassasiyet (guclu sarsinti gerekir)
float quakeDeviationThreshold = 0.03;  // 1.0g'den +-0.05g sapma = deprem algilama
// Yangin: Analog deger ne kadar buyukse o kadar hassas (4095 = alev yok, 0 = yakin alev)
int flameAnalogThreshold = 2500;       // Bu degerin altinda alev suphelisi
float flameTempThreshold = 40.0;       // DHT22 sicaklik C ustu = yangin suphelisi

// Mağdur listesi ve Chat gecmisi
StaticJsonDocument<4096> victimsDoc;

// Sohbet icin Ring Buffer yapisi
struct ChatMsg {
  String sender;
  String content;
  String time;
  bool isSos;
};
const int MAX_CHAT_MSG = 30;
ChatMsg chatHistory[MAX_CHAT_MSG];
int chatHead = 0;
int chatCount = 0;

void addChatMessage(String sender, String content, String time, bool isSos) {
  chatHistory[chatHead].sender = sender;
  chatHistory[chatHead].content = content;
  chatHistory[chatHead].time = time;
  chatHistory[chatHead].isSos = isSos;
  chatHead = (chatHead + 1) % MAX_CHAT_MSG;
  if(chatCount < MAX_CHAT_MSG) chatCount++;
}

// --- MPU9250 OKUMA ---
void initMPU() {
  Wire.begin(MPU_SDA, MPU_SCL);
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x6B); // PWR_MGMT_1
  Wire.write(0x00); // Uyandır
  Wire.endTransmission(true);
  delay(100);
  
  // Accelerometer +-4g ayarı
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x1C);
  Wire.write(0x08);
  Wire.endTransmission(true);
  
  // Gyroscope +-500 deg/s ayarı
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x1B);
  Wire.write(0x08);
  Wire.endTransmission(true);
  
  Serial.println("[MPU] MPU9250 baslatildi");
}

void readMPU() {
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x3B); // ACCEL_XOUT_H
  Wire.endTransmission(false);
  Wire.requestFrom((uint8_t)MPU_ADDR, (uint8_t)14, (uint8_t)true);
  
  int16_t rawAx = Wire.read() << 8 | Wire.read();
  int16_t rawAy = Wire.read() << 8 | Wire.read();
  int16_t rawAz = Wire.read() << 8 | Wire.read();
  Wire.read(); Wire.read(); // temp atla
  int16_t rawGx = Wire.read() << 8 | Wire.read();
  int16_t rawGy = Wire.read() << 8 | Wire.read();
  int16_t rawGz = Wire.read() << 8 | Wire.read();
  
  // +-4g ölçek: 8192 LSB/g
  accelX = rawAx / 8192.0;
  accelY = rawAy / 8192.0;
  accelZ = rawAz / 8192.0;
  // +-500 deg/s ölçek: 65.5 LSB/deg/s
  gyroX = rawGx / 65.5;
  gyroY = rawGy / 65.5;
  gyroZ = rawGz / 65.5;
  
  // Deprem algilama: normal yercekiminden (1.0g) ne kadar saptigina bak
  float totalAccel = sqrt(accelX*accelX + accelY*accelY + accelZ*accelZ);
  float deviation = abs(totalAccel - 1.0); // 1.0g'den sapma
  earthquakeDetected = (deviation > quakeDeviationThreshold);
  
  if(earthquakeDetected) {
    Serial.printf("[MPU-DBG] Toplam ivme: %.3fg  |  Sapma: %.3fg  (esik: %.3fg)\n", totalAccel, deviation, quakeDeviationThreshold);
  }
}

// --- SENSOR OKUMA TASK ---
Task taskReadSensors(TASK_SECOND * 2, TASK_FOREVER, []() {
  // DHT22 oku
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  if (!isnan(t)) temperature = t;
  if (!isnan(h)) humidity = h;
  
  // Alev sensoru oku (dijital + analog + sicaklik kombine)
  int flameVal = digitalRead(FLAME_DO_PIN);
  flameAnalog = analogRead(FLAME_AO_PIN);
  
  // 3 katmanli yangin algilama:
  // 1. Dijital sensorden alev sinyali
  // 2. Analog deger esik altinda (alev yakinda)
  // 3. Sicaklik anormal yuksek
  bool digitalFlame = (flameVal == HIGH);
  bool analogFlame = (flameAnalog < flameAnalogThreshold);
  bool tempFlame = (temperature > flameTempThreshold);
  
  // Herhangi ikisi birden tetiklenirse VEYA dijital kesin tetiklenmisse
  flameDetected = digitalFlame || (analogFlame && tempFlame) || analogFlame;
  
  Serial.printf("[ALEV-DBG] Dijital:%d  Analog:%d  Sicaklik:%.1f  -> %s\n", 
    flameVal, flameAnalog, temperature, flameDetected ? "YANGIN!" : "Normal");
  
  // MPU9250 oku
  readMPU();
  
  // Serial'e yazdır
  Serial.println("--- SENSOR VERILERI ---");
  Serial.printf("[DHT22]  Sicaklik: %.1f C  |  Nem: %.1f %%\n", temperature, humidity);
  Serial.printf("[ALEV]   Durum: %s  |  Analog: %d\n", flameDetected ? "ALEV VAR!" : "Normal", flameAnalog);
  Serial.printf("[MPU]    Ax:%.2f Ay:%.2f Az:%.2f g\n", accelX, accelY, accelZ);
  Serial.printf("[MPU]    Gx:%.1f Gy:%.1f Gz:%.1f deg/s\n", gyroX, gyroY, gyroZ);
  if (earthquakeDetected) Serial.println("[!!!]    DEPREM ALGILANDI!");
  if (flameDetected) Serial.println("[!!!]    YANGIN ALGILANDI!");
  Serial.println();
});

// Acil durum LED yakma taskı (500ms normal, 100ms panik)
Task taskEmergencyBlink(TASK_MILLISECOND * 100, TASK_FOREVER, []() {
  bool sensorEmergency = earthquakeDetected || flameDetected || (temperature > 50);
  
  if (localEmergencyActive) {
    // Panik modu: Cok hizli yanip son (100ms)
    digitalWrite(EMERGENCY_LED_PIN, !digitalRead(EMERGENCY_LED_PIN));
  } else if (sensorEmergency) {
    // Sensor uyarisi: Orta hizli (500ms - task 100ms oldugu icin 5 saymamiz lazim)
    static int counter = 0;
    if (++counter >= 5) {
      digitalWrite(EMERGENCY_LED_PIN, !digitalRead(EMERGENCY_LED_PIN));
      counter = 0;
    }
  } else {
    digitalWrite(EMERGENCY_LED_PIN, LOW);
  }
});

// Mesh mesaj alma
void receivedCallback(uint32_t from, String &msg) {
  Serial.printf("[MESH] Mesaj geldi (%u): %s\n", from, msg.c_str());
  StaticJsonDocument<2048> doc;
  if (deserializeJson(doc, msg)) return;
  String action = doc["action"].as<String>();
  
  if (action == "new_victim") {
    // Ayni ID zaten var mi kontrol et (tekrar eklemeyi onle)
    String newId = doc["id"].as<String>();
    JsonArray arr = victimsDoc.as<JsonArray>();
    bool exists = false;
    for (JsonObject o : arr) { if(o["id"].as<String>()==newId){ exists=true; break; } }
    if(!exists) {
      JsonObject nv = victimsDoc.createNestedObject();
      nv["id"] = doc["id"].as<String>();
      nv["name"] = doc["name"].as<String>();
      nv["floor"] = doc["floor"].as<String>();
      nv["people"] = doc["people"].as<String>();
      nv["battery"] = doc["battery"].as<String>();
      nv["lat"] = doc["lat"].as<String>();
      nv["lng"] = doc["lng"].as<String>();
      nv["alt"] = doc["alt"].as<String>();
      nv["status"] = "waiting";
      Serial.printf("[MESH] Yeni magdur senkronize edildi: %s (Konum: %s, %s)\n", nv["name"].as<String>().c_str(), nv["lat"].as<String>().c_str(), nv["lng"].as<String>().c_str());
    }
  } else if (action == "chat_msg") {
    // Yeni chat mesaji geldi
    addChatMessage(doc["sender"].as<String>(), doc["content"].as<String>(), doc["time"].as<String>(), doc["isSos"].as<bool>());
    Serial.printf("[MESH] Sohbet: [%s] %s\n", doc["sender"].as<String>().c_str(), doc["content"].as<String>().c_str());
  } else if (action == "rescue_victim") {
    String tid = doc["id"].as<String>();
    JsonArray arr = victimsDoc.as<JsonArray>();
    for (JsonObject o : arr) { if(o["id"].as<String>()==tid){ o["status"]="rescued"; break; } }
  } else if (action == "sync_request") {
    // Yeni baglanan dugum veri istiyor, tum magdurlari gonder
    Serial.printf("[MESH] Senkronizasyon istegi geldi (%u)\n", from);
    JsonArray arr = victimsDoc.as<JsonArray>();
    for (JsonObject v : arr) {
      StaticJsonDocument<512> m;
      m["action"]="new_victim";
      m["id"]=v["id"]; m["name"]=v["name"]; m["floor"]=v["floor"];
      m["people"]=v["people"]; m["battery"]=v["battery"];
      m["lat"]=v["lat"]; m["lng"]=v["lng"]; m["alt"]=v["alt"];
      String s; serializeJson(m,s);
      mesh.sendSingle(from, s);
    }
  }
}

// Yeni dugum baglandiginda
void newConnectionCallback(uint32_t nodeId) {
  meshNodeCount = mesh.getNodeList().size() + 1;
  Serial.printf("[MESH] === Yeni dugum baglandi! ID: %u === Toplam: %d dugum\n", nodeId, meshNodeCount);
}

// Dugum ayrildiginda
void droppedConnectionCallback(uint32_t nodeId) {
  meshNodeCount = mesh.getNodeList().size() + 1;
  Serial.printf("[MESH] === Dugum ayrildi! ID: %u === Toplam: %d dugum\n", nodeId, meshNodeCount);
}

// Mesh topolojisi degistiginde
void changedConnectionCallback() {
  meshNodeCount = mesh.getNodeList().size() + 1;
  Serial.printf("[MESH] Topoloji degisti. Toplam: %d dugum\n", meshNodeCount);
  // Yeni baglandigimizda mevcut verileri iste
  StaticJsonDocument<64> req;
  req["action"] = "sync_request";
  String s; serializeJson(req, s);
  mesh.sendBroadcast(s);
}

// --- ANA SAYFA HTML ---
const char index_html[] PROGMEM = R"rawliteral(
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Vanguard - Afet Yardım Sistemi</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Segoe UI',sans-serif;background:#0a0a0a;color:#fff;display:flex;justify-content:center;min-height:100vh;padding:15px}
.container{width:100%;max-width:420px}
.screen{display:none}.screen.active{display:block}
h1{font-size:20px;margin-bottom:6px;color:#e0e0e0;text-align:center}
h2{font-size:17px;margin-bottom:12px;color:#e0e0e0;text-align:center}
p.subtitle{text-align:center;color:#888;margin-bottom:18px;font-size:13px}
input{width:100%;padding:13px;margin:7px 0;border:none;border-radius:8px;background:#1e1e1e;color:#fff;font-size:15px}
input::placeholder{color:#666}
.btn{width:100%;padding:15px;margin:7px 0;border:none;border-radius:10px;font-size:16px;font-weight:bold;cursor:pointer;transition:all .2s}
.btn:active{transform:scale(.97);opacity:.8}
.btn-victim{background:#d32f2f;color:#fff}
.btn-rescue{background:#1976d2;color:#fff}
.btn-back{background:#333;color:#fff}
.btn-action{background:#388e3c;color:#fff;margin-top:8px}
.card{background:#161616;padding:14px;border-radius:10px;margin-bottom:10px;border-left:4px solid #d32f2f}
.card h3{margin-bottom:6px;font-size:15px}
.card p{margin:3px 0;font-size:13px;color:#bbb}
.logo{text-align:center;font-size:44px;margin:15px 0}
.status-msg{text-align:center;padding:18px;color:#4caf50;font-size:15px}
.empty-msg{text-align:center;padding:25px;color:#666;font-size:14px}

/* Sensor Panel */
.sensor-panel{background:#111;border-radius:12px;padding:14px;margin-bottom:15px;border:1px solid #222}
.sensor-row{display:flex;justify-content:space-between;align-items:center;padding:8px 0;border-bottom:1px solid #1a1a1a}
.sensor-row:last-child{border:none}
.sensor-label{font-size:12px;color:#888}
.sensor-value{font-size:15px;font-weight:bold}
.alert-bar{background:#d32f2f;color:#fff;text-align:center;padding:12px;border-radius:8px;margin-bottom:12px;font-weight:bold;animation:pulse 1s infinite}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:.6}}
.ok{color:#4caf50}.warn{color:#ff9800}.danger{color:#f44336}
</style>
</head>
<body>
<div class="container">
  <!-- SENSOR DURUM PANELI (her sayfada gorunur) -->
  <div id="alert-container"></div>
  <div class="sensor-panel" id="sensor-panel">
    <div class="sensor-row">
      <span class="sensor-label">🌡 Sicaklik</span>
      <span class="sensor-value" id="s-temp">--</span>
    </div>
    <div class="sensor-row">
      <span class="sensor-label">💧 Nem</span>
      <span class="sensor-value" id="s-hum">--</span>
    </div>
    <div class="sensor-row">
      <span class="sensor-label">🔥 Alev</span>
      <span class="sensor-value" id="s-flame">--</span>
    </div>
    <div class="sensor-row">
      <span class="sensor-label">📳 Titresim</span>
      <span class="sensor-value" id="s-quake">--</span>
    </div>
  </div>

  <!-- ANA MENU -->
  <div id="main-menu" class="screen active">
    <div class="logo">🆘</div>
    <h1>VANGUARD</h1>
    <p class="subtitle" id="mesh-info">Ag yukleniyor...</p>
    <button class="btn btn-victim" onclick="showScreen('victim-screen')">AFETZEDE GIRISI</button>
    <button class="btn btn-rescue" onclick="showScreen('rescue-login')">KURTARMA EKIBI</button>
  </div>

  <!-- AFETZEDE -->
  <div id="victim-screen" class="screen">
    <h2>Yardim Cagrisi Olustur</h2>
    <input type="text" id="v-name" placeholder="Isim Soyisim">
    <input type="number" id="v-floor" placeholder="Bulundugunuz Kat" min="0" max="99">
    <input type="number" id="v-people" placeholder="Yaninizdaki Kisi Sayisi" min="0">
    <input type="number" id="v-battery" placeholder="Telefon Sarjiniz (%)" min="0" max="100">
    <button class="btn btn-victim" onclick="submitVictim()">YARDIM ISTE</button>
    <button class="btn btn-back" onclick="showScreen('main-menu')">GERI</button>
  </div>

  <div id="victim-success" class="screen">
    <div class="logo">✅</div>
    <div class="status-msg">Yardim cagriniz iletildi!<br>Lutfen konumunuzu terk etmeyin.</div>
    <button class="btn btn-back" onclick="showScreen('main-menu')">ANA SAYFA</button>
  </div>

  <!-- KURTARMA PIN -->
  <div id="rescue-login" class="screen">
    <h2>Kurtarma Ekibi Girisi</h2>
    <input type="password" id="r-pin" placeholder="PIN Kodu (1122)">
    <button class="btn btn-rescue" onclick="checkPin()">GIRIS YAP</button>
    <button class="btn btn-back" onclick="showScreen('main-menu')">GERI</button>
  </div>

  <!-- KURTARMA DASHBOARD -->
  <div id="rescue-dashboard" class="screen">
    <h2>Aktif Magdurlar</h2>
    <div id="victim-list"><div class="empty-msg">Yukleniyor...</div></div>
    <button class="btn btn-back" onclick="location.reload()">CIKIS YAP</button>
  </div>
</div>

<script>
function showScreen(id){
  document.querySelectorAll('.screen').forEach(function(s){s.classList.remove('active')});
  document.getElementById(id).classList.add('active');
}

// Sensor verileri guncelle
function updateSensors(){
  var x=new XMLHttpRequest();
  x.open("GET","/api/sensors",true);
  x.onreadystatechange=function(){
    if(x.readyState==4&&x.status==200){
      var d=JSON.parse(x.responseText);
      document.getElementById('s-temp').innerHTML=d.temp.toFixed(1)+' °C';
      document.getElementById('s-temp').className='sensor-value '+(d.temp>50?'danger':d.temp>35?'warn':'ok');
      document.getElementById('s-hum').innerHTML=d.hum.toFixed(0)+' %';
      document.getElementById('s-hum').className='sensor-value ok';
      document.getElementById('s-flame').innerHTML=d.flame?'ALEV VAR!':'Normal';
      document.getElementById('s-flame').className='sensor-value '+(d.flame?'danger':'ok');
      document.getElementById('s-quake').innerHTML=d.quake?'DEPREM!':'Normal';
      document.getElementById('s-quake').className='sensor-value '+(d.quake?'danger':'ok');
      document.getElementById('mesh-info').innerHTML='Kat '+d.floor+' | Ag: '+d.nodes+' dugum aktif';
      var ac=document.getElementById('alert-container');
      var alerts='';
      if(d.flame) alerts+='<div class="alert-bar">🔥 YANGIN ALGILANDI!</div>';
      if(d.quake) alerts+='<div class="alert-bar">📳 DEPREM ALGILANDI!</div>';
      if(d.temp>50) alerts+='<div class="alert-bar">🌡 YUKSEK SICAKLIK: '+d.temp.toFixed(1)+'°C</div>';
      ac.innerHTML=alerts;
    }
  };
  x.send();
}
setInterval(updateSensors, 2000);
updateSensors();

function submitVictim(){
  var n=document.getElementById('v-name').value,f=document.getElementById('v-floor').value,
      p=document.getElementById('v-people').value,b=document.getElementById('v-battery').value;
  if(!n||!f||!p||!b){alert("Tum alanlari doldurun");return;}
  var x=new XMLHttpRequest();
  x.open("POST","/api/victim",true);
  x.setRequestHeader("Content-Type","application/json");
  x.onreadystatechange=function(){if(x.readyState==4)showScreen('victim-success')};
  x.send(JSON.stringify({id:"v_"+Date.now(),name:n,floor:f,people:p,battery:b,status:"waiting"}));
}
function checkPin(){
  if(document.getElementById('r-pin').value==="1122"){
    showScreen('rescue-dashboard');loadVictims();setInterval(loadVictims,5000);
  }else alert("Hatali PIN!");
}
function loadVictims(){
  var x=new XMLHttpRequest();
  x.open("GET","/api/victims",true);
  x.onreadystatechange=function(){
    if(x.readyState==4&&x.status==200){
      var d=JSON.parse(x.responseText),l=document.getElementById('victim-list'),
          a=d.filter(function(v){return v.status==="waiting"});
      if(a.length===0){l.innerHTML='<div class="empty-msg">Aktif yardim cagrisi yok</div>';return;}
      var h='';
      for(var i=0;i<a.length;i++){var v=a[i];
        h+='<div class="card" id="card-'+v.id+'"><h3>'+v.name+'</h3>';
        h+='<p><strong>Kat:</strong> '+v.floor+'</p>';
        h+='<p><strong>Kisi:</strong> '+v.people+'</p>';
        h+='<p><strong>Sarj:</strong> %'+v.battery+'</p>';
        h+='<button class="btn btn-action" onclick="rescueVictim(\''+v.id+'\')">KURTARMAYA GIDIYORUM</button></div>';
      }
      l.innerHTML=h;
    }
  };
  x.send();
}
function rescueVictim(id){
  if(!confirm("Kurtarma operasyonunu ustlendiginizi onayliyor musunuz?"))return;
  var x=new XMLHttpRequest();
  x.open("POST","/api/rescue",true);
  x.setRequestHeader("Content-Type","application/json");
  x.onreadystatechange=function(){if(x.readyState==4){var e=document.getElementById('card-'+id);if(e)e.remove()}};
  x.send(JSON.stringify({id:id}));
}
</script>
</body>
</html>
)rawliteral";

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n\n=============================");
  Serial.println("  VANGUARD v3.0");
  Serial.printf("  KAT: %d | MESH DESTEKLI\n", FLOOR_ID);
  Serial.println("=============================\n");

  // Sensor pinleri
  pinMode(FLAME_DO_PIN, INPUT);
  pinMode(FLAME_AO_PIN, INPUT);
  pinMode(EMERGENCY_LED_PIN, OUTPUT);
  dht.begin();
  initMPU();

  // JSON Array başlat
  victimsDoc.to<JsonArray>();

  // FreeRTOS Kuyruk oluştur
  broadcastQueue = xQueueCreate(10, sizeof(String*));

  // Mesh başlat
  mesh.setDebugMsgTypes(ERROR | STARTUP);
  mesh.init(MESH_PREFIX, MESH_PASSWORD, &userScheduler, MESH_PORT);
  mesh.onReceive(&receivedCallback);
  mesh.onNewConnection(&newConnectionCallback);
  mesh.onDroppedConnection(&droppedConnectionCallback);
  mesh.onChangedConnections(&changedConnectionCallback);

  // Sensor okuma task'ını başlat
  userScheduler.addTask(taskReadSensors);
  taskReadSensors.enable();
  
  // Acil durum LED task'ını başlat
  userScheduler.addTask(taskEmergencyBlink);
  taskEmergencyBlink.enable();

  delay(500);
  myAPIP = IPAddress(mesh.getAPIP());
  Serial.printf("[WIFI] AP IP: %s\n", myAPIP.toString().c_str());

  // WiFi bağlantı logları
  WiFi.onEvent([](WiFiEvent_t event, WiFiEventInfo_t info){
    Serial.printf("[WIFI] >> Cihaz baglandi! MAC: %02X:%02X:%02X:%02X:%02X:%02X\n",
      info.wifi_ap_staconnected.mac[0], info.wifi_ap_staconnected.mac[1],
      info.wifi_ap_staconnected.mac[2], info.wifi_ap_staconnected.mac[3],
      info.wifi_ap_staconnected.mac[4], info.wifi_ap_staconnected.mac[5]);
  }, WiFiEvent_t::ARDUINO_EVENT_WIFI_AP_STACONNECTED);

  WiFi.onEvent([](WiFiEvent_t event, WiFiEventInfo_t info){
    Serial.printf("[WIFI] << Cihaz ayrildi. MAC: %02X:%02X:%02X:%02X:%02X:%02X\n",
      info.wifi_ap_stadisconnected.mac[0], info.wifi_ap_stadisconnected.mac[1],
      info.wifi_ap_stadisconnected.mac[2], info.wifi_ap_stadisconnected.mac[3],
      info.wifi_ap_stadisconnected.mac[4], info.wifi_ap_stadisconnected.mac[5]);
  }, WiFiEvent_t::ARDUINO_EVENT_WIFI_AP_STADISCONNECTED);

  // DNS
  dnsServer.setErrorReplyCode(DNSReplyCode::NoError);
  dnsServer.start(53, "*", myAPIP);
  dnsStarted = true;

  // ============ WEB SUNUCUSU ============
  // CORS header'lari - Flutter uygulamasindan gelen istekleri kabul et
  DefaultHeaders::Instance().addHeader("Access-Control-Allow-Origin", "*");
  DefaultHeaders::Instance().addHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  DefaultHeaders::Instance().addHeader("Access-Control-Allow-Headers", "Content-Type");

  // OPTIONS preflight isteklerini karşıla
  server.on("/api/sensors", HTTP_OPTIONS, [](AsyncWebServerRequest *request){ request->send(200); });
  server.on("/api/victim", HTTP_OPTIONS, [](AsyncWebServerRequest *request){ request->send(200); });
  server.on("/api/victims", HTTP_OPTIONS, [](AsyncWebServerRequest *request){ request->send(200); });
  server.on("/api/rescue", HTTP_OPTIONS, [](AsyncWebServerRequest *request){ request->send(200); });
  server.on("/api/chat", HTTP_OPTIONS, [](AsyncWebServerRequest *request){ request->send(200); });

  server.on("/", HTTP_GET, [](AsyncWebServerRequest *request){
    request->send(200, "text/html", index_html);
  });

  // Captive Portal
  server.on("/generate_204", HTTP_GET, [](AsyncWebServerRequest *r){ r->redirect("http://"+myAPIP.toString()+"/"); });
  server.on("/gen_204", HTTP_GET, [](AsyncWebServerRequest *r){ r->redirect("http://"+myAPIP.toString()+"/"); });
  server.on("/hotspot-detect.html", HTTP_GET, [](AsyncWebServerRequest *r){ r->redirect("http://"+myAPIP.toString()+"/"); });
  server.on("/library/test/success.html", HTTP_GET, [](AsyncWebServerRequest *r){ r->redirect("http://"+myAPIP.toString()+"/"); });
  server.on("/connecttest.txt", HTTP_GET, [](AsyncWebServerRequest *r){ r->redirect("http://"+myAPIP.toString()+"/"); });
  server.on("/ncsi.txt", HTTP_GET, [](AsyncWebServerRequest *r){ r->redirect("http://"+myAPIP.toString()+"/"); });
  server.on("/canonical.html", HTTP_GET, [](AsyncWebServerRequest *r){ r->redirect("http://"+myAPIP.toString()+"/"); });

  // --- SENSOR API ---
  server.on("/api/sensors", HTTP_GET, [](AsyncWebServerRequest *request){
    StaticJsonDocument<256> doc;
    doc["temp"] = temperature;
    doc["hum"] = humidity;
    doc["flame"] = flameDetected;
    doc["flameRaw"] = flameAnalog;
    doc["quake"] = earthquakeDetected;
    doc["ax"] = accelX;
    doc["ay"] = accelY;
    doc["az"] = accelZ;
    doc["floor"] = FLOOR_ID;
    doc["nodes"] = meshNodeCount;
    String r; serializeJson(doc, r);
    request->send(200, "application/json", r);
  });

  // --- MAGDUR API ---
  server.on("/api/victim", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total){
    if (index + len == total) {
      StaticJsonDocument<512> doc;
      if(deserializeJson(doc, (const char*)data, len)) {
        request->send(400, "application/json", "{\"status\":\"error\"}");
        return;
      }
      JsonObject nv=victimsDoc.createNestedObject();
      nv["id"] = doc["id"].as<String>();
      nv["name"] = doc["name"].as<String>();
      nv["floor"] = doc["floor"].as<String>();
      nv["people"] = doc["people"].as<String>();
      nv["battery"] = doc["battery"].as<String>();
      nv["lat"] = doc["lat"].as<String>();
      nv["lng"] = doc["lng"].as<String>();
      nv["alt"] = doc["alt"].as<String>();
      nv["status"] = "waiting";

      StaticJsonDocument<512> m;
      m["action"]="new_victim";
      m["id"]=nv["id"]; m["name"]=nv["name"];
      m["floor"]=nv["floor"]; m["people"]=nv["people"]; m["battery"]=nv["battery"];
      m["lat"]=nv["lat"]; m["lng"]=nv["lng"]; m["alt"]=nv["alt"];
      String s;serializeJson(m,s);
      String* msgPtr = new String(s);
      xQueueSend(broadcastQueue, &msgPtr, 0);
      Serial.printf("[API] Yeni magdur: %s (Kat:%s, Konum:%s,%s)\n", nv["name"].as<String>().c_str(), nv["floor"].as<String>().c_str(), nv["lat"].as<String>().c_str(), nv["lng"].as<String>().c_str());
      request->send(200,"application/json","{\"status\":\"success\"}");
    }
  });

  server.on("/api/victims", HTTP_GET, [](AsyncWebServerRequest *request){
    String r;serializeJson(victimsDoc,r);
    request->send(200,"application/json",r);
  });

  server.on("/api/rescue", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total){
    if (index + len == total) {
      StaticJsonDocument<256> doc;
      if(deserializeJson(doc, (const char*)data, len)) {
        request->send(400, "application/json", "{\"status\":\"error\"}");
        return;
      }
      String tid=doc["id"].as<String>();
      JsonArray arr=victimsDoc.as<JsonArray>();
      for(JsonObject o:arr){if(o["id"].as<String>()==tid){o["status"]="rescued";break;}}
      StaticJsonDocument<256> m;
      m["action"]="rescue_victim";m["id"]=tid;
      String s;serializeJson(m,s);
      String* msgPtr = new String(s);
      xQueueSend(broadcastQueue, &msgPtr, 0);
      request->send(200,"application/json","{\"status\":\"success\"}");
    }
  });

  // --- ACİL DURUM API (PANİK BUTONU) ---
  server.on("/api/emergency", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total){
    if (index + len == total) {
      StaticJsonDocument<512> doc;
      if(deserializeJson(doc, (const char*)data, len)) {
        request->send(400, "application/json", "{\"status\":\"error\"}");
        return;
      }
      
      localEmergencyActive = true; // LED taski bunu algilayip hizli yanip sonecek
      
      // Magdur listesine ekle (Oncelikli)
      JsonObject nv = victimsDoc.createNestedObject();
      nv["id"] = doc["id"].as<String>();
      nv["name"] = doc["name"].as<String>();
      nv["floor"] = String(FLOOR_ID);
      nv["people"] = doc["people"].as<String>();
      nv["battery"] = doc["battery"].as<String>();
      nv["status"] = "emergency";
      nv["lat"] = doc["lat"].as<String>();
      nv["lng"] = doc["lng"].as<String>();
      nv["alt"] = doc["alt"].as<String>();

      // Mesh agina yayinla
      StaticJsonDocument<1024> m;
      m["action"] = "new_victim";
      m["id"] = nv["id"]; m["name"] = nv["name"]; m["floor"] = nv["floor"];
      m["people"] = nv["people"]; m["battery"] = nv["battery"]; m["status"] = "emergency";
      m["lat"] = nv["lat"]; m["lng"] = nv["lng"]; m["alt"] = nv["alt"];
      
      String s; serializeJson(m,s);
      String* msgPtr = new String(s);
      xQueueSend(broadcastQueue, &msgPtr, 0);
      
      Serial.println("[API] !!! ACIL DURUM SINYALI ALINDI VE YAYINLANDI !!!");
      request->send(200, "application/json", "{\"status\":\"success\"}");
    }
  });


  // --- CHAT API ---
  server.on("/api/chat", HTTP_GET, [](AsyncWebServerRequest *request){
    DynamicJsonDocument doc(4096);
    JsonArray arr = doc.to<JsonArray>();
    int startIdx = (chatCount < MAX_CHAT_MSG) ? 0 : chatHead;
    for(int i = 0; i < chatCount; i++) {
      int idx = (startIdx + i) % MAX_CHAT_MSG;
      JsonObject nm = arr.createNestedObject();
      nm["sender"] = chatHistory[idx].sender;
      nm["content"] = chatHistory[idx].content;
      nm["time"] = chatHistory[idx].time;
      nm["isSos"] = chatHistory[idx].isSos;
    }
    String r; serializeJson(doc, r);
    request->send(200, "application/json", r);
  });

  server.on("/api/chat", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total){
    if (index + len == total) {
      StaticJsonDocument<1024> doc;
      if(deserializeJson(doc, (const char*)data, len)) {
        request->send(400, "application/json", "{\"status\":\"error\"}");
        return;
      }
      
      String sender = doc["sender"].as<String>();
      String content = doc["content"].as<String>();
      String time = doc["time"].as<String>();
      bool isSos = (doc["isSos"].as<int>() == 1);

      // Broadcast message to mesh
      StaticJsonDocument<1024> m;
      m["action"] = "chat_msg";
      m["sender"] = sender;
      m["content"] = content;
      m["time"] = time;
      m["isSos"] = isSos;
      String s; serializeJson(m,s);
      String* msgPtr = new String(s);
      xQueueSend(broadcastQueue, &msgPtr, 0);
      
      // Save to local memory
      addChatMessage(sender, content, time, isSos);
      Serial.printf("[API] Sohbet gonderildi: %s\n", content.c_str());
      request->send(200, "application/json", "{\"status\":\"success\"}");
    }
  });

  server.onNotFound([](AsyncWebServerRequest *r){ r->redirect("http://"+myAPIP.toString()+"/"); });
  server.begin();

  Serial.println("[WEB] Sunucu baslatildi!");
  Serial.printf(">> Tarayicida: http://%s/\n\n", myAPIP.toString().c_str());
}

void loop() {
  mesh.update();
  if(dnsStarted) dnsServer.processNextRequest();

  // Kuyrukta bekleyen yayin mesajlarini Mesh'e gonder
  String* msgPtr;
  if(xQueueReceive(broadcastQueue, &msgPtr, 0) == pdTRUE) {
    mesh.sendBroadcast(*msgPtr);
    delete msgPtr; // Bellek sizintisini onle
  }
}
