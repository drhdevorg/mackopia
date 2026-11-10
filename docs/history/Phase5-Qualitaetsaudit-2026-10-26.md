# Phase 5 – Qualitätsaudit, 2026-10-26

## Umfang und Codezustand

Branch `codex/p5-native-quality`, Produktionscode `70309cb`, [Draft PR #7](https://github.com/drhdevorg/mackopia/pull/7). Basis: integrierter Phase-4-Stand auf `main`.
Xcode 27.1 (27A9275), Swift 6.4, Sprachmodus 6, SDK macOS 27, natives arm64.
Kopia 0.23.1, unveränderte Dependencies/Entitlements/Buildphasen/XPC-Version 7.
Dies ist ein automatisierter und statischer Audit mit konkretem Live-Blocker, keine abgeschlossene UI-Abnahme.

## Befunde und verdrahtete Korrekturen

| Befund | Änderung | Evidenz |
|---|---|---|
| Private Vorschau bleibt nach hartem Dienstabbruch liegen | `RestorePreviewCache` räumt beim Dienststart und vor neuer Vorschau eigene UUID-Sitzungen auf | 3 Cache-Tests plus Dienst-Neustarttest, vorhandener echter Restore-/Vorschau-Lifecycle |
| Restore fehlt als laufender Vorgang in der Menüleiste | Laufendes Symbol, Restore-Text, Fortschrittsanzeige und Abbrechen über vorhandenen Dienstvertrag | Xcode-Build; Live-Menüleistenprüfung offen |
| Health-Warnung oder nicht verfügbarer Dienst fehlt im Menüleistensymbol | Warnungszustand berücksichtigt jede nicht-OK-Health und `unavailable` | Statischer Zustandsvergleich; Live-Prüfung offen |
| ⌘. bleibt während Request aktiv, während Toolbar Stoppen sperrt | Derselbe Busy-Guard für Menükommando und Toolbar | Statischer Abgleich; Tastaturdurchgang offen |
| Fortschritt/Pausenmenü/Quellenentfernen ohne expliziten A11y-Namen | Bestehende DE/EN-Texte als Labels ergänzt, Backup-Fortschritt in Menüleiste bestimmt falls verfügbar | Build/Format/Katalogprüfung; VoiceOver offen |
| README beschreibt SFTP noch als nächsten Backend-Schritt | Integrierten Backend-Stand korrigiert | Dokumentprüfung |

## Cache-Sicherheitsvertrag

Nur der Agent besitzt den Cache. Cleanup greift ausschließlich auf
`Library/Caches/MacKopia/QuickLook` unter dem injizierten Home zu. Der Root muss symlinkfrei,
regulär, im Besitz des aktuellen Nutzers und 0700 sein. Nur kanonische UUID-Namen mit demselben
Besitzer/Modus und regulärem Verzeichnistyp werden entfernt. Unbekannte Namen und Symlinks
werden nicht entfernt; Symlink-Ziele innerhalb der Sitzung bleiben beim rekursiven Löschen erhalten.
Ein fehlender Root erzeugt beim Startup keine Verzeichnisse. Ein wiederholtes `start()` bereinigt
keine laufende Sitzung. Startup-Fehler landen ohne Pfade im Logger; vor neuer Vorschau wird die
Prüfung wiederholt und bei Fehlern abgewiesen. Andere Backups werden dadurch nicht gesperrt.
Der Test verwendet ausschließlich temporäre Homes, keine Nutzerdaten und keinen produktiven Cache.

## Automatisierte Prüfung

- Package: **557 Tests / 105 Suites bestanden**, einschließlich realer temporärer lokaler/S3-/WebDAV-/SFTP-
  und Restore-Integration; `/tmp/mackopia-p5-package.log`, Laufzeit 164,4 s.
- Cache: Schutz privater Sitzungen, Symlinks innerhalb/außerhalb der Sitzung, unbekannter Dateien,
  nicht privatem/umgeleitetem Root, fehlendem Root, Idempotenz und Dienststart geprüft.
- Strikter Swift-Format-Lint sauber; Diff-Whitespace sauber.
- Kataloge: App 246 / Agent 126 Einträge, kein nichtleerer Schlüssel ohne Englisch.
- Xcode `build test`: **Exit 65**, Test-Runner hängt vor Verbindungsaufbau (832 s), zusätzlich
  Daemon-Control-Session-Timeout. Log `/tmp/mackopia-p5-xcode.log`. Keine Swift-Compilerwarnungen.
  Gezielte Diagnose per `xcrun xctest` auf gebautem Bundle: **4 Tests bestanden**, 0,063 s;
  `/tmp/mackopia-p5-bundle-direct.log`. Das ersetzt keinen erfolgreichen kombinierten Xcode-Lauf.
  Eigenständiger Xcode-Build **erfolgreich**, `/tmp/mackopia-p5-build.log`.
  Nach bestätigtem Entsperren `test-without-building` erneut ohne Testergebnis im IDE-Start;
  bewusst abgebrochen, `/tmp/mackopia-p5-xcode-unlocked.log`. Keine weitere Vollsuite wiederholt.
- Erster Compile-Versuch fand einen fehlenden `BackupDomain`-Import im neuen Helper; vor der
  erfolgreichen Package-Vollprüfung korrigiert. Keine Assertions oder Sicherheitsregeln abgeschwächt.

## Live-Audit und exakter Wiederaufnahmeweg

Computer Use inventarisierte native Oberflächen erfolgreich. Der Versuch, das frisch gebaute
`MacKopia.app` zu öffnen, meldete: Mac gesperrt, automatisches Entsperren nicht möglich.
Der Nutzer hat auf Nachfrage „entsperrt“ bestätigt. Anschließend liefen native `getApp`-Aufrufe
für das gebaute MacKopia nach 30 und 60 Sekunden in Timeout/Kernel-Reset; auch `getApp` für den
bereits laufenden Finder scheiterte nach 47 Sekunden. `getState` liefert weiterhin das App-Inventar.
Damit bleibt der native Automationszugriff blockiert; ein MacKopia-Startfehler ist daraus nicht belegt.
Keine Screenshots, UI-/VoiceOver-Abnahme, Dienstregistrierung oder Instruments-Messwerte ableiten.
`xcrun xctrace list templates` funktioniert nach Cache-Freigabe; eine Template-Liste ist kein Profil.

Nach Wiederherstellung der nativen Computer-Use-Verbindung, Besitzer Agent + Nutzer:

1. Finder-AX-Zugriff nachweisen, dann gebautes App-Bundle öffnen. Ohne Dienst: klare Offline-Aktion, ⌘N/⌘B/⌘. gesperrt;
   ⌘, öffnet native Einstellungen, ⌘R führt nach Verbindung in Restore. Keine automatische Registrierung.
2. Registrierten Dienst und Keychain/FDA erst mit den nötigen bewussten Systemfreigaben aktivieren.
   Nur neue lokale Temp-Quelle/Temp-Speicherziel verwenden, nie bestehende Nutzerziele.
3. Neuer Plan → Backup → Prüfen → Restore → Quick Look schließen. Menüleistenstatus,
   Backup-/Restore-Abbruch und Fehler-/Wiederholungsaktion mit demselben Zustand vergleichen.
4. S3/WebDAV/SFTP-Assistenten samt Credential-Sheet, Host-Key-Freigabe und Fehlereingaben ansehen;
   nur lokale Wegwerf-Fixtures verwenden. Echte Provider bleiben im separaten Ledger.
5. DE und EN, Light/Dark/Increase Contrast bei minimalem Fenster: Screenshots pro relevante Ansicht;
   keine abgeschnittenen Aktionsbuttons. Tastatur-only, VoiceOver, Reduce Motion/Transparency prüfen.
6. Instruments Activity Monitor/File Activity/Time Profiler: nach Beruhigung 60 s Idle, danach Backup/
   Restore mit Fortschritt. CPU/Speicher/I/O und Updatefrequenz (≤ etwa 4 Hz) dokumentieren.
   Keine Zahlen aus Builds, Tests oder einem gesperrten Desktop als Produktmessung ausgeben.

Weitere bekannte Bedienlücken zur integrierten Prüfung: Quellen-Drag-and-drop, Entfernen per Entf/Undo,
Menüleisten-Restore-Navigation und Fehleraktionen sowie Quellen-/Snapshot-Pagination. Bestehende Grenzen
werden bis zur Implementierung weiter angezeigt; diese Korrekturen behaupten keine vollständige Phase 5.


## Live-Wiederaufnahme: Registrierung und Editorzustand

Native Finder- und MacKopia-AX-Verbindung am 26.10. wieder verfügbar. Der Nutzer hat die
Dienstregistrierung und ausschließlich neue temporäre Testdaten explizit freigegeben.
Offline-Fenster, gesperrte Backup-Aktionen, ⌘R-Navigation und native ⌘,-Einstellungen live geprüft.
Screenshots im Chat zeigen die deutsche Oberfläche; keine vollständige DE/EN-/Kontrast-/VoiceOver-Abnahme.

Live reproduzierte Befunde:

- Deutsche Sidebar-Texte wurden bei 144 pt abgeschnitten; 200 pt Mindestbreite/220 pt Idealbreite
  zeigen Backup-Pläne und Wiederherstellen vollständig. Native Sidebar bleibt erhalten.
- Registrierungsfehler wurden nur in einem von der Offline-Ansicht ausgeblendeten Feld gespeichert
  und vom Reconnect überschrieben. Eigene `registrationMessage` bleibt im Offline-Fenster und den
  Einstellungen sichtbar; Signaturfehler getrennt, alle Texte DE/EN, keine rohen Systemfehler.
- `SMAppService.status` lieferte vor Erstregistrierung `.notFound`; der bisherige Guard rief
  `register()` nicht auf. BTM-Log: `effectiveItemDisposition: record not found` für unsere Plist,
  obwohl Bundle-/Signaturtests die eingebettete Plist und das Programm bestätigen. Die explizite
  Registrierung wird nun nach unveränderter Signaturprüfung an macOS delegiert. Regression zuerst
  rot (`missingStatusStillAllowsExplicitRegistration`), zusätzliche echte Systemfehler bleiben typisiert.
  **Live bestätigt:** nach Neustart registriert, XPC verbunden, Übersicht „Noch kein Backup-Plan“.
- ⌘N öffnete wegen des Standardbefehls ein weiteres Fenster. Der Planbefehl ersetzt jetzt `.newItem`.
- Bei der Quellenwahl verlor der Assistent zuvor Name und Ziel. Die Sheet-Closures erzeugten Stores
  bei Parent-Updates erneut. `LocalSetupSheet` und `PlanEditorSheet` besitzen den Store als `@State`
  je Präsentation; das gilt auch für Credential-Sheets. Live-Nachprüfung erfolgreich: Name und Speicherziel bleiben nach Quellenwahl erhalten; ⌘N öffnet den Assistenten.

Temp-Workflow: nur neue Ordner unter `/private/tmp/mackopia-live-audit-xp05r3_k` (Quelle mit Audit.txt,
leeres Ziel, Restore-Elternordner). Speicherziel anschließend im nativen Assistenten erfolgreich angelegt; Generator verwendet, Passwortanzeige vor Einrichtung wieder verborgen.
Registrierter Dienst bleibt nach ausdrücklicher Nutzerfreigabe aktiv; keine FDA-Freigabe vorgenommen.
Systemlogs nur lokal unter `/tmp/mackopia-p5-registration*.log`, keine Rohlogs ins Repository.

Prüfdiagnose:

- Finaler Registrierungsstand: Xcode `build test` grün, 4 Bundle-/Signaturtests, keine Compilerwarnung;
  `/tmp/mackopia-p5-live-xcode-final.log`, Ergebnis `Run-MacKopia-2026.10.26_15-22-28-+0100.xcresult`.
- Erster Package-Lauf verwendete `/usr/bin/python3` mit LibreSSL 2.8.3; TLS-Fixtures starteten nicht.
  Wiederholung mit `MACKOPIA_TEST_PYTHON` auf gebündeltem Python/OpenSSL 3.5.8.
- Wiederholter paralleler Lauf vor finaler Registrierung: 557 Tests, WebDAV-Verifikation fehlgeschlagen.
  Paralleler finaler Registrierungsstand: 559 Tests, 15 Folgefehler in den drei Remote-Backups;
  lokaler Backup-/Restorepfad grün. Kein Zusammenhang mit Registrierung bewiesen.
  Logs `/tmp/mackopia-p5-live-package-tls.log` und `/tmp/mackopia-p5-live-package-final.log`.
- Serielle Diagnose auf demselben Package-Code und finaler Editor-Build laufen; Ergebnisse in STATUS.md
  nachtragen. Keine Assertions oder Schutzprüfungen abgeschwächt.

Finale Prüfungen nach Sheet-Integration: Xcode `build test` grün, 4 Bundle-/Signaturtests,
`/tmp/mackopia-p5-editors-xcode-final.log`, `Run-MacKopia-2026.10.26_19-05-04-+0100.xcresult`.
Keine Compilerwarnung. Beim ersten Editor-Build fehlten die neuen Dateien in der expliziten
Xcode-Dateiliste; vor finalem Lauf ergänzt. Keine neuen Buildphasen/Entitlements/Dependencies.
Package final: **559 Tests / 105 Suites bestanden**, seriell 289,839 s, einschließlich WebDAV
(163,881 s); `/tmp/mackopia-p5-live-package-serial.log`. Parallele Fehler damit eingegrenzt,
Ursache unter Last nicht isoliert. Format/Diff sauber.
Nach Neubau den leeren registrierten Dienst mit `launchctl kickstart -k` und die UI neu gestartet,
damit die strikten Signaturanker beider Prozesse auf denselben Disk-Stand zeigen; danach XPC verbunden.

Live-Abschluss des aktuellen Teilwegs: lokales Temp-Ziel erfolgreich eingerichtet, Plan in Übersicht
sichtbar, Recovery-Kit angeboten. ⌘B erreicht den registrierten Dienst. Der fehlende FDA-Nachweis
blockiert den Lauf konservativ mit „Quellenzugriff nicht bestätigt“ und Aktion zum Öffnen der
Systemeinstellungen; kein Backup-/Restore-Erfolg behauptet. Nutzer hat FDA-Freigabe ausdrücklich abgelehnt; der betroffene Live-Lauf bleibt gesperrt. Keine vorhandenen Nutzerziele benutzt.

Erste echte Instruments-Messung: Activity Monitor, 30 s am finalen MacKopia-App-Prozess,
ruhendes Fenster nach sicherem FDA-Block, 25 Samples bis 29,505 s. CPU über 24 gültige Samples:
Mittel 0,211 %, Maximum 4,975 %; physischer Footprint 58,42–58,55 MiB; gemeldete App-Disk-
Lese-/Schreibraten durchgehend 0 Bytes/s. Kein Dienst-/Backup-Profil, keine Fortschrittsfrequenzmessung
und kein vollständiger 60-s-Release-Benchmark. Lokales Artefakt `/tmp/mackopia-p5-idle.trace`,
Export `/tmp/mackopia-p5-idle-metrics.xml`; keine Trace-/Environmentdaten ins Repository übernommen.
Export benötigte Instruments-Cache-Freigabe; Sandbox-Versuch scheiterte vor der erfolgreichen Auswertung.

## Archivierte STATUS-Prüfliste (Codex, Stand `794de02`, übernommen 2026-11-10)

- Xcode 27.1 (27A9275), Swift 6.4, arm64; finaler Produktionscode auf obigem Branch.
- Package-Vollsuite: **557 Tests / 105 Suites bestanden**, echte temporäre lokale/S3-/WebDAV-/SFTP-
  und Restore-Integration; 164,4 s. Log `/tmp/mackopia-p5-package.log`, keine Compilerwarnungen.
- 4 neue Cache-/Dienststarttests bestanden: sichere Entfernung, Symlink-/Dateierhalt, unsicherer Root,
  fehlender Root, wiederholter Dienststart. Bestehender echter Preview-/Restore-Lifecycle ebenfalls grün.
- Xcode-Wiederaufnahme: **`build test` erfolgreich, 4 Bundle-/Signaturtests bestanden**, keine
  Compilerwarnungen; unveränderter Produktionscode, Xcode 27.1 / arm64.
  Log `/tmp/mackopia-p5-build-test-resume.log`, Ergebnis `Run-MacKopia-2026.10.26_15-02-06-+0100.xcresult`.
- Zuvor `test-without-building` ebenfalls erfolgreich: 4 Tests, 0,207 s;
  `/tmp/mackopia-p5-test-resume.log`. Beide Wiederaufnahmen außerhalb der Sandbox mit
  `-parallel-testing-enabled NO`; Ursache des früheren Daemon-Verbindungs-Timeouts nicht isoliert.
  Keine Scheme-/Signatur-/Entitlement-Änderung nötig. Historischer Exit 65 bleibt im früheren Log
  `/tmp/mackopia-p5-xcode.log`; direkter damaliger Bundle-Lauf ebenfalls 4 Tests grün.
- Das Xcode-Testziel enthält Bundle-/Signaturtests, noch keine automatisierten XCUITests.
- Strikter Swift-Format-Lint und `git diff --check` sauber. App 246 / Agent 126 Katalogeinträge,
  kein nichtleerer Schlüssel ohne Englisch; neue Restore-Zeile DE/EN.
- Erster Compile-Versuch: fehlender BackupDomain-Import, vor obiger Vollprüfung korrigiert.
- Live-UI wieder erreichbar; Nutzerfreigabe für Dienst/Temp-Workflow liegt vor. Registrierung nach
  `.notFound`-Fix erfolgreich, XPC verbunden. Offline/⌘R/⌘,/Sidebar und ⌘N live geprüft.
- Finale Package-Suite **559 Tests / 105 Suites grün**, seriell 289,8 s; TLS-1.3-Python explizit gesetzt.
  `/tmp/mackopia-p5-live-package-serial.log`. Parallele Remote-Fehler bleiben im Audit dokumentiert.
- Finaler Editor-/Registrierungsstand: **Xcode build test grün**, 4 Bundle-/Signaturtests,
  `/tmp/mackopia-p5-editors-xcode-final.log`, keine Compilerwarnung. Format/Diff sauber.
- Neue Regression: `.notFound` darf explizite Registrierung nach Signaturprüfung erreichen;
  zunächst rot, anschließend grün; echte Systemfehler bleiben typisiert.
- Neue Sheet-Hosts erhalten Entwürfe bei Verbindungsevents; Name/Ziel nach Quellenwahl live erhalten.
  ⌘N ersetzt Standard-Neues-Fenster-Befehl. Deutsche Sidebar ohne bisherige Trunkierung.
- Instruments-App-Idle 30 s: CPU Ø 0,211 %, Peak 4,975 %, Footprint 58,42–58,55 MiB, App-I/O 0 B/s.
  Vorläufige Messung, kein Agent-/Last-/60-s-Nachweis; Trace und Grenzen im Audit.
- Temp-Ziel live eingerichtet; ⌘B vom fehlenden FDA-Nachweis sicher blockiert, passende Fehleraktion.
  Nutzer lehnt FDA-Freigabe ausdrücklich ab; noch kein Live-Backup/-Restore.
- Vorheriger SFTP-Abschluss und einmalige WebDAV-Prüfablehnung samt unverändert erfolgreicher Diagnose:
  [Phase-4-Evidenz](history/STATUS-Phase4-SFTP-Abschluss-2026-10-26.md). Im aktuellen Vollauf WebDAV grün.

## Live-Versuch Claude, 2026-11-10 (macOS 27.2 26B123, Xcode 27.1)

Ziel: neue Bedienwege live prüfen. Temp-Ordner `/private/tmp/mackopia-live-audit-6pdyHklh`; Konfiguration leer.

1. BTM-Eintrag des Agents war `enabled, disallowed` (Hintergrundaktivität im System aus). `register()` kehrte bei
   `requiresApproval` stumm zurück. Fix: Rückgabestatus, Hinweis DE/EN, Anmeldeobjekte öffnen. Live bestätigt.
2. Nach Nutzerfreigabe `enabled, allowed`, aber kein Agent-Prozess: launchd `job state = spawn failed`,
   `last exit code = 78: EX_CONFIG`, später „Could not find and/or execute program“. App-Knopf blieb bei „enabled“ stumm.
   Fix: explizite Reparatur (unregister/register) nur bei Nutzeraktion ohne Verbindung; Tests mit Fake-Dienst.
3. Eigentliche Ursache nach Reparatur sichtbar: `xpcproxy exited due to OS_REASON_CODESIGNING | Launch Constraint
   Violation, error info: c[5]p[1]m[1]e[0], (Constraint not matched) launch type 0` für
   `…/MacKopia.app/Contents/Library/LoginItems/MacKopia Agent.app/Contents/MacOS/MacKopia Agent`;
   Kernel/AMFI: `_process_matches_constraint: Requirement not satisfied`. launchd entfernt den Job nach
   wiederholtem Fehlschlag. App/Agent ad-hoc + Hardened Runtime, keine Team-ID, `com.apple.provenance` gesetzt.
   macOS 27.2 seit 27.10.; letzter erfolgreicher Agent-Lauf laut BTM 28.10. Ursache noch nicht isoliert.
   Keine System-/BTM-Datenbank verändert; Hintergrundfreigabe hat der Nutzer selbst gesetzt.

Nebenbefund Umgebung: Command Line Tools 27.2 am 10.11. installiert, `xcode-select` zeigt seither auf CLT;
Builds liefen mit `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

### Ursachenanalyse Dienststart (Claude, 2026-11-10)

- `launchctl print gui/502/com.example.MacKopia.Agent` zeigt `managed_by = com.apple.xpc.ServiceManagement` und
  `LWCR = { reqs = { cdhash = { $in = [ <data> ] } } }`. Andere SMAppService-Jobs im selben Domain (SuperDuper,
  Microsoft) tragen stattdessen `team-identifier` + `signing-identifier` (validation-category 6) und überleben Updates.
- AMFI-Fehler `c[5]p[1]m[1]e[0]`: laut Apple DTS (Forum 795022) c5 = LightweightCodeRequirements-Spawn-Constraint,
  p1 = Prozess selbst, m1 = kein Treffer, e0 = kein Auswertungsfehler.
- smd/BTM liefern die LWCR aus dem BTM-Datensatz (`getEffectiveDisposition … have LWCR=true`), nicht neu aus dem Binary.
- Versuche ohne Erfolg: `unregister()`+`register()` (BTM-Generation neu = 1, Constraint weiter verletzt), geänderter
  LaunchAgent-Plist-Wert (ExitTimeOut, kam in launchd an), Neubau des Codex-Stands `794de02` (andere cdhash
  `2b1e2560…`). Kein zweites Bundle mit gleicher ID bei Launch Services; Standalone- und eingebettetes Agent-Binary identisch.
- Externe Berichte (Apple-Forum 795022; GitHub znasllc-io/memql-cockpit#546, GeiserX/VPN-Bypass#242): Signatur wird
  bei Registrierung festgehalten, Neuregistrieren antwortet „already registered“; berichtete Heilung nur durch
  Neuanfang (Hintergrund aus, App löschen, Eintrag verschwinden lassen, neu installieren) bzw. stabile Team-Signatur.
  Ein Autor folgert: ad-hoc-Builds überleben unter SMAppService kein Update.
- Folge: Mit kontoloser Ad-hoc-Signatur bricht vermutlich jedes Sparkle-Update den Hintergrunddienst. Nicht mit einem
  echten Update-Lauf bewiesen; Produktentscheidung offen. Die neue Reparaturtaste behebt diesen Fall nicht.
