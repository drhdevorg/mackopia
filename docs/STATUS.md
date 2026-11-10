# Status & nächster Auftrag

Stand: 2026-11-10. Einstieg: AGENTS.md, dieser Status, PROJEKT.md §14 und IMPLEMENTIERUNG.md.
Historische Evidenz bleibt im [Archiv](history/README.md).

## Aktuelle Produktphase

**Phase 5: Bedienlücken (Quellen-Drop, Entf/Undo, Menüleisten-Navigation, Fehleraktionen) geschlossen; Live-Audit offen.**
Phase 1–4 integriert; SFTP-/WebDAV-Reviewhistorie: [PR #6](https://github.com/drhdevorg/mackopia/pull/6),
[PR #5](https://github.com/drhdevorg/mackopia/pull/5). Basis auf `main`: `ebe1aaf`.
Aktueller Arbeitsbranch: `claude/p5-native-quality` (von Claude übernommen, Basis `codex/p5-native-quality` @ `794de02`,
[Draft PR #7](https://github.com/drhdevorg/mackopia/pull/7)). Phase 5 bleibt offen.

## In progress

| Agent | Auftrag | Branch | Dateien/Module |
|---|---|---|---|
| Claude | Phase 5 von Codex übernommen (Nutzerauftrag 2026-11-10): Quellen-Drag-and-drop, Entf/Undo, Menüleisten-Restore-Navigation, Fehleraktionen | `claude/p5-native-quality` (Basis `codex/p5-native-quality` @ `794de02`) | App/, Agent/, AgentProtocol, Tests, docs/ |

## Verbindliche Entscheidungen

- macOS 27.x, natives arm64; Xcode 27.1 (27A9275), Swift 6.4 / Sprachmodus 6, SDK 27.
- Ad-hoc-Vertrieb/Hardened Runtime; unveränderte Entitlements/Dependencies/Buildphasen und Kopia 0.23.1.
- Agent besitzt Runtime, Schlüsselbund und Kopia; App nur über authentifiziertes XPC, Version 7.
- S3/WebDAV/SFTP-End-to-end: Create/Connect, geprüfter Credential-Ersatz, Backup/Verify/Restore.
- WebDAV/SFTP-Runtime-JSON nur im RAM: frische anonyme Pipe, geschütztes Symlink-Verzeichnis, gemeinsame Sperre.
- SFTP: bewusste öffentliche Host-Key-Freigabe, SHA256-Pin, geschützte known_hosts; Schlüssel im Keychain.
  RSA-PEM im RAM normalisiert; SSH-Passwort/verschlüsselte OpenSSH-Schlüssel weiterhin nicht freigegeben.
- Create-only; Connect erhält fremden Wartungs-Owner. Credential-Ersatz erst nach frischer Auth-Probe.
- Neue Pläne manuell bis Terminwahl; Mitteilungen aus; Eject nie mit Force.
- Restore nur in neuen privaten UUID-Ordner (0700), Overwrite aus, keine Originalquelle nötig.
- Quick-Look-Startup-Cleanup gemäß PROJEKT.md §11.2/§17; Fehler sperren nur neue Vorschauen.

## Implementiert und verdrahtet

- Phase 1–4: gemeinsamer Dienst/Queue/Gate, UUID-/FDA-Schutz, Automatik/Pausen/Recovery,
  Health/Nacharbeit, Restore-Katalog/Browser/Suche/Quick Look und Remote-Assistenten DE/EN.
- `RestorePreviewCache`: beim Dienststart/vor Vorschau nur eigene reguläre 0700-UUID-Sitzungen im
  symlinkfreien 0700-Cache entfernen; unbekannte Namen/Symlinks erhalten. Startfehler ohne Pfade loggen.
  Wiederholtes `start()` entfernt keine laufende Sitzung; fehlender Root erzeugt keine Verzeichnisse.
- Menüleiste: laufender Restore mit Abbruchaktion, bestimmter Backup-Fortschritt falls verfügbar,
  Warnsymbol auch für Health-Warnung/nicht verfügbaren Dienst. Kein neuer IPC-Vertrag.
- ⌘. nutzt denselben Busy-Guard wie Toolbar; Fortschritt/Pausenmenü/Quelle entfernen mit A11y-Labels.
- Plan-Editor: Quellen als Liste mit Auswahl; Finder-Drop (mehrere Ordner), Entf/Kontextmenü/Minus-Taste,
  Undo/Redo für Hinzufügen und Entfernen (`SourceListEdit`, mind. eine Quelle, eindeutige Pfade, max. 1.024).
  Einrichtung akzeptiert einen gezogenen Quellordner. Drop und Auswahl teilen `AgentConnection.localSources`.
- `AppRoute` (AgentProtocol) ersetzt `showRestore`/`showActivity`. Menüleiste: „Wiederherstellen…“,
  „Aktivität anzeigen“, „Wiederherstellung anzeigen“ bei laufendem Restore, „Details anzeigen“ bei Problemen;
  Mitteilungs-Details öffnen die Übersicht. Mechanik und Sicherheitsgrenze: PROJEKT.md §17 (2026-11-10).
- Fehleraktionen: Health `reviewDestination`/`enterPassword` → Speicherziele, `reviewActivity`/`reviewDiagnostics`
  → Aktivität; Fenstermeldungen `.destination` → Speicherziele, Backup-/Prüf-/Wartungs-/Automatikfehler → Aktivität.
- Detailbefunde und reproduzierbarer Live-Wiederaufnahmeweg:
  [Phase-5-Audit](history/Phase5-Qualitaetsaudit-2026-10-26.md).

## Prüfung dieses Codezustands

- Claude, 2026-11-10, Xcode 27.1 / Swift 6.4 / arm64, finaler Stand auf `claude/p5-native-quality`.
- 9 neue Tests (`SourceListEditTests`, `AppRouteTests`) grün.
- Package-Vollsuite seriell: **568 Tests / 107 Suites**; alles grün außer 6 KopiaServer-Netzwerksuites
  (62 Issues, alle `FixtureError.startFailed`): `native_tls_fixture.py` braucht TLS 1.3, auf diesem Rechner gibt es
  nur LibreSSL-Python (`/usr/bin`, Xcode). Codex' gebündeltes Python fehlt hier. Lokal/S3/WebDAV/SFTP/Restore-Integration grün.
  Log `/tmp/mackopia-p5-claude-package.log`. Erneut mit `MACKOPIA_TEST_PYTHON` auf OpenSSL-3-Python ausführen.
- Xcode `build test` (`-parallel-testing-enabled NO`): **grün**, 4 Bundle-/Signaturtests, keine Compilerwarnung;
  `/tmp/mackopia-p5-claude-xcode.log`. Strikter Format-Lint und `git diff --check` sauber; neue Strings DE/EN.
- **Nicht live geprüft:** Drop/Entf/Undo im Editor, Menüleisten-Navigation (laufende und neu gestartete App),
  Fehleraktions-Buttons. Kein XCUITest vorhanden.
- Vorherige Codex-Evidenz (Registrierung, Editor-Sheets, Instruments-Idle, Temp-Ziel, FDA-Block): Audit unten.

## Offene Live-Nachweise und Grenzen – kein globaler Entwicklungsstopp

| Nachweis | Betroffene Funktion | Exakte nächste Aktion / Besitzer |
|---|---|---|
| Native Verbindung wieder erreichbar, Agent-Fensteraufruf einmal Timeout | UI-/A11y-/Performance-Audit | Agent: App-Fenster weiter auditieren; MenuBarExtra separat öffnen |
| Reales WebDAV/TLS/Anbieter | Provider-Kompatibilität | Nutzer stellt explizit entbehrlichen HTTPS-Testordner bereit; Agent prüft Create/Connect/Backup/Restore/Credential-Wechsel |
| Reales S3/IAM/TLS/Token-Ablauf | Provider-Kompatibilität | Nutzer stellt explizit entbehrlichen Bucket/Präfix bereit; Agent prüft Create/Connect/Backup/Restore und Credential-Wechsel |
| S3 Object Lock und spezifische Auth-Diagnose | Optionale Provider-Funktionen/UX | Eigenen Provider-Vertrag nachweisen; aktuell nicht im Assistenten, Fehler bleiben sanitisiert und führen zu Netzwerk-/Zugangsprüfung |
| Registrierter Dienst/XPC positiv verbunden | SMAppService/Peer-Vertrauen | Agent: negative registrierte Peers und Update-/Neustartpfad prüfen; positive Aktivierung live belegt |
| Login-Keychain/TCC/FDA/Updates | Produktive Secrets/geschützte Quellen | Nutzer + Agent: nur Temp-Ziel, ggf. FDA bestätigen; echte Credential-Aktualisierung und Update-ACL prüfen |
| Safari-Testdatei fehlt oder ist >1 MiB | Konservative FDA-Erkennung | Zugriff gesperrt lassen; begrenzte alternative Kind-Leseprobe entwickeln/nachweisen |
| Reales Unmount/Eject/Abziehen | Hardwarefunktion | Nutzer + Agent: entbehrliches USB-Testvolume, UUID-Wechsel/Veto/Abbruch; kein Force |
| Native Mitteilungen/Aktionen | Zustellung | Nutzer aktiviert am registrierten Dienst; Agent prüft Zustellung/Retry/Details mit Temp-Plan |
| Restore-/Remote-UI-Durchgang und Kit/PDF | Fenster, Quick Look, Druck | Agent + Nutzer: lokales Fixture/Temp-Backup, Fehler/Abbruch/Credential-Sheet und PDF-Layout prüfen |
| DE/EN, Light/Dark/Kontrast, Tastatur/VoiceOver | UI-/Releasequalität | Phase 5/6: Screenshots/minimales Fenster und A11y-Audit; bisher Code/Previews/Katalog/Build |
| Große Kataloge/Verzeichnisse | Restore-Browser | >128 Quellen/1.000 Snapshots/8 MiB bzw. >2.000 Einträge blockieren; Pagination vor größerer Freigabe |
| Gatekeeper/Updates, Checkpoint 45 statt 15 Minuten | Release | Phase 6: Installationsartefakt prüfen; Checkpoint-Produktentscheidung treffen |
| Reales SFTP/SSH/Host-Key | Provider-Kompatibilität | Nutzer stellt entbehrlichen Testordner und öffentlichen Host-Key über vertrauenswürdigen Kanal bereit; Agent prüft Create/Connect/Backup/Restore/Schlüsselwechsel |
| Einmalige WebDAV-Verifikationsablehnung im Vollauf | Prüfevidenz unter paralleler Last | Bei erneutem Auftreten sanitisierte Prozess-/Prüfzähler und Fixture-Zustand erfassen; erster Fehler und isolierte erfolgreiche Diagnose oben |


## Nächster vollständiger Coding-Auftrag

**Phase 5 fortsetzen: zusammenhängender UI-/Accessibility-/Performance-Audit mit Temp-Workflow.**

Einstieg: PROJEKT.md §4–§5, §11–§14 Phase 5, AGENTS.md §7, IMPLEMENTIERUNG.md und Audit oben.
Native Verbindung und Dienstregistrierung sind positiv belegt; Freigabe für Temp-Workflow liegt vor.
Temp-Root: `/private/tmp/mackopia-live-audit-xp05r3_k`. Fenster/Menüleiste/Shortcuts,
Fehleraktionen/Remote-Assistenten prüfen; DE/EN, Light/Dark/Kontrast, minimales Fenster, Tastatur/VoiceOver
mit Screenshots erfassen und Instruments Idle-CPU/Speicher/I/O/Updatefrequenz messen.
FDA-Freigabe abgelehnt; geschützten Live-Lauf erst nach einer neuen ausdrücklichen Freigabe fortsetzen.
Zuerst die neuen Wege live prüfen: Finder-Drop/Entf/⌘Z im Plan-Editor, Menüleiste → Wiederherstellen/Aktivität
bei laufender und geschlossener App, Fehleraktionen. Danach Quellen-/Snapshot-Pagination; keine spekulativen Frameworks/Entitlements. Registrierung/FDA/Keychain
nur mit bewussten nötigen Systemfreigaben; reale Provider/Hardware bleiben separat.
Fertig: belegter integrierter Audit, behobene Befunde mit Tests, relevante Prüfungen und kompakte Übergabe.
Name/Bundle-Präfix MacKopia / com.example.MacKopia; Lizenzmodell offen.
