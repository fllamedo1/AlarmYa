# AlarmIA

Copia de alarma tipo Alarmy para iPhone, construida con Flutter. La biblioteca incluida usa sonidos de alarma generados por IA/procedurales publicados por SFXMint bajo CC0 1.0.

## Qué hace

- Lista de alarmas con nombre, hora y días de repetición (Lun–Dom) o una sola vez.
- **Notificaciones locales de iOS**: la alarma suena con la app cerrada, pantalla bloqueada y modo avión.
- Sonido de notificación "urgente" (nivel *Time Sensitive*: el usuario puede permitir que atraviese el modo No Molestar).
- Al tocar la notificación se abre la **misión** a pantalla completa con tono en bucle loud (`AVAudioSession playback`), y solo se detiene al completarla:
  - **Botón**: detener directo (sin dificultad).
  - **Matemática**: 3 dificultades (fácil / media / difícil), cuenta nueva si fallás.
  - **Sacudir**: acelerómetro en vivo, 5–40 sacudidas configurables.
- Biblioteca de sonidos de alarma realistas: sirenas, campana y reloj generados por IA/procedurales, sin los tonos polifónicos anteriores.
- La música propia importada desde Archivos se reproduce dentro de la app; las notificaciones con el iPhone bloqueado usan siempre `despertador.wav`, un WAV corto incluido en el bundle iOS y compatible con el sistema de notificaciones. El sonido elegido se reproduce al abrir la misión.

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
- Al terminar, descargá el artifact **`AlarmIA-ipa`** → queda `AlarmIA-unsigned.ipa`.

### 3. Instalala en tu iPhone desde esta PC

1. Instalá **iTunes de Apple** (https://www.apple.com/itunes/download/win64/) para los drivers USB, o la app **Apple Devices** desde Microsoft Store.
2. Instalá **Sideloadly**: https://sideloadly.io
3. Conectá el iPhone por USB → desbloquealo → *Confiar* en la PC.
4. Sideloadly → arrastrá `AlarmIA-unsigned.ipa` → poné tu **Apple ID** → *Start* (pide otra vez la contraseña por popup de Apple).
5. Primer vez: en el iPhone → **Ajustes → General → VPN y gestión de dispositivos → confiar** en tu Apple ID.
6. Abrí AlarmIA → permití notificaciones.

### 4. Que suene aunque haya "No Molestar"

- **Ajustes → Enfoque → Tu modo → <app AlarmYa> → permitir alarmas / time sensitive.**

### 5. Semana a semana (solo con Apple ID gratuito)

Cada ~6–7 días:
1. Conectá el iPhone a esta PC.
2. Sideloadly → arrastrá el mismo IPA → re-firmar (borra los datos de la app si cambia el bundle id; con mismo bundle id se re-firma in place).

Sin esa rutina, iOS borra o desactiva la app al vencer el perfil. Con una cuenta desarrollador de Apple (US$99/año) el intervalo pasa a ~1 año y activa en Ajustes aunque no esté el IPA a mano.

## Biblioteca de sonidos

Los sonidos incluidos son recursos CC0 1.0 de SFXMint. Se descargaron como WAV PCM y se registran también en `ios/Runner/` para que las notificaciones locales puedan reproducirlos con la pantalla bloqueada:

- `alarma_sirena_ia.wav` — nuclear alarm 08 — SHA-256 `EE7B7A7ECAC20F8A52E4A82A79C38B0941EAAB12792AFCBCCD1B9A371BA1E29A`
- `alarma_reloj_ia.wav` — office alarm clock 17 — SHA-256 `5EA281DDE7D80B2C77E0EE7E0E75B85BC65648FD519E0C8260842D619FC1E11A`
- `alarma_campana_ia.wav` — bell toll 10 — SHA-256 `597CFCF954373832531C5CE78679820F555612DEB94D93935BC32EA657A2ED4E`
- `alarma_sirena_urbana_ia.wav` — burglar alarm 10 — SHA-256 `699018B97F6D7836ED27523DC0E563A791280DBF01DBC4A231AC494BEE68E262`
- `alarma_auto_ia.wav` — car alarm 04 — SHA-256 `A79D7F138DE47BE4B36ECEDA748A09401A347CF3A8C0611455D58C72684BF0D3`

Fuente y licencia: https://sfxmint.com/ y https://github.com/sfxmint/sfxmint-mcp. CC0 1.0 permite redistribución y uso comercial sin atribución obligatoria. Se conserva el nombre descriptivo en el catálogo para no confundir estos SFX con canciones completas.

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
