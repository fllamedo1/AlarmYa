# AlarmYa

Copia de alarma tipo Alarmy para iPhone, construida con Flutter. Código 100% propio, sin sonidos ni assets de terceros.

## Qué hace

- Lista de alarmas con nombre, hora y días de repetición (Lun–Dom) o una sola vez.
- **Notificaciones locales de iOS**: la alarma suena con la app cerrada, pantalla bloqueada y modo avión.
- Sonido de notificación "urgente" (nivel *Time Sensitive*: el usuario puede permitir que atraviese el modo No Molestar).
- Al tocar la notificación se abre la **misión** a pantalla completa con tono en bucle loud (`AVAudioSession playback`), y solo se detiene al completarla:
  - **Botón**: detener directo (sin dificultad).
  - **Matemática**: 3 dificultades (fácil / media / difícil), cuenta nueva si fallás.
  - **Sacudir**: acelerómetro en vivo, 5–40 sacudidas configurables.
- Sonido de alarma generado programáticamente (ver `tool/gen_sound.dart`), reemplazable por cualquier `.wav` ≤ 30 s.

## Limitaciones honestas (iOS)

| Situación | Resultado |
|---|---|
| App cerrada, iPhone encendido | ✅ Suena (notificación local) |
| Pantalla bloqueada | ✅ Suena |
| Modo avión | ✅ Suena |
| No Molestar | ⚠️ El usuario debe permitir notificaciones *time sensitive* o autorizar la app en el Enfoque |
| iPhone apagado | ❌ Nada puede sonar (limite de iOS, igual que Alarmy) |
| **Apple ID gratuito** | ⚠️ La firma vence cada 7 días: hay que re-firmar semanalmente con Sideloadly |

## Instalar (sin Mac)

La app se compila en la nube (GitHub Actions con macOS) y se instale desde esta PC con **Sideloadly**.

### 1. Crea el repo en GitHub y subé el proyecto

```bash
cd C:\Users\facu_\Desktop\AlarmYa
git init
git add .
git commit -m "AlarmYa v1"
# En GitHub (github.com/new) crea un repo público "AlarmYa" sin README, y despupés:
git remote add origin https://github.com/TU_USUARIO/AlarmYa.git
git branch -M main
git push -u origin main
```

### 2. Esperá la compilación (5–15 min)

- GitHub → tu repo → pestaña **Actions** → job `build-ios`.
- Al terminar, descargá el artifact **`AlarmYa-ipa`** → queda `AlarmYa-unsigned.ipa`.

### 3. Instalala en tu iPhone desde esta PC

1. Instalá **iTunes de Apple** (https://www.apple.com/itunes/download/win64/) para los drivers USB, o la app **Apple Devices** desde Microsoft Store.
2. Instalá **Sideloadly**: https://sideloadly.io
3. Conectá el iPhone por USB → desbloquealo → *Confiar* en la PC.
4. Sideloadly → arrastrá `AlarmYa-unsigned.ipa` → poné tu **Apple ID** → *Start* (pide otra vez la contraseña por popup de Apple).
5. Primer vez: en el iPhone → **Ajustes → General → VPN y gestión de dispositivos → confiar** en tu Apple ID.
6. Abrí AlarmYa → permití notificaciones.

### 4. Que suene aunque haya "No Molestar"

- **Ajustes → Enfoque → Tu modo → <app AlarmYa> → permitir alarmas / time sensitive.**

### 5. Semana a semana (solo con Apple ID gratuito)

Cada ~6–7 días:
1. Conectá el iPhone a esta PC.
2. Sideloadly → arrastrá el mismo IPA → re-firmar (borra los datos de la app si cambia el bundle id; con mismo bundle id se re-firma in place).

Sin esa rutina, iOS borra o desactiva la app al vencer el perfil. Con una cuenta desarrollador de Apple (US$99/año) el intervalo pasa a ~1 año y activa en Ajustes aunque no esté el IPA a mano.

## Cambiar el tono de alarma

1. Pongá tu `.wav` (mono PCM 16-bit, ≤ 30 s) en:
   - `assets/sounds/alarm.wav` (para la app/misión)
   - `ios/Runner/alarm.wav` (para la notificación del sistema)
2. Hacé push → nueva compilación.

## Desarrollo

```bash
cd C:\Users\facu_\Desktop\AlarmYa
C:\Users\facu_\flutter-sdk\bin\flutter.bat analyze   # 0 errores
C:\Users\facu_\flutter-sdk\bin\flutter.bat test      # smoke test
```

¡Nada de REA aquí! Este proyecto se construyó desde cero, con permisos mínimos (`NSMotionUsageDescription`, audio en fondo, notificaciones) y sonido propio.
