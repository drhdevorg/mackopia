# Status & nächster Auftrag

Stand: 2026-11-11. Einstieg: AGENTS.md, dieser Status, PROJEKT.md §14 und IMPLEMENTIERUNG.md.
Historische Evidenz bleibt im [Archiv](history/README.md).

## Aktuelle Produktphase

**Phase 5: Bedienlücken geschlossen, Restore-Pagination auf `main`; UI-/A11y-/Performance-Audit offen.**
Phase 1–4 integriert; Bedienlücken über [PR #8](https://github.com/drhdevorg/mackopia/pull/8), Pagination und
CI-Fixes über [PR #9](https://github.com/drhdevorg/mackopia/pull/9) auf `main` (`43478ae`). Phase 5 bleibt offen.

## In progress

| Agent | Auftrag | Branch | Dateien/Module |
|---|---|---|---|
| Claude | Phase-5-Audit: verwaiste Kopia-Prozesse nach Agent-Abbruch | `claude/p5-orphan-kopia` | KopiaCLI/KopiaOrphanReaper, LocalBackupService, Agent/AgentAppDelegate, docs/ |

## Verbindliche Entscheidungen

- macOS 27.x, natives arm64; Xcode 27.1 (27A9275), Swift 6.4 / Sprachmodus 6, SDK 27.
- Ad-hoc-Vertrieb/Hardened Runtime; unveränderte Entitlements/Dependencies/Buildphasen und Kopia 0.23.1.
- Agent besitzt Runtime, Schlüsselbund und Kopia; App nur über authentifiziertes XPC, Version 8.
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

- `main` @ `43478ae`, GitHub-CI (`xcode-27`) grün (Run 42954746079); Watchdog/30-Minuten-Timeout gegen Hänger.
- Lokal (Xcode 27.1 / Swift 6.4 / arm64): 581 Tests/108 Suites; nur 6 KopiaServer-Netzwerksuites rot
  (62× `FixtureError.startFailed`): `native_tls_fixture.py` braucht TLS 1.3, hier nur LibreSSL-Python; mit
  `MACKOPIA_TEST_PYTHON` auf OpenSSL-3-Python ausführen. Xcode `build test` grün, keine Warnung, Lint sauber.
- Live 2026-11-10 (Debug, Temp-Plan): Finder-Drop/⌫/Undo, Routen (laufend + Kaltstart), Aktivitätsspalten,
  Prüfgrund „Speicherziele anzeigen“, Dienstaktivierung mit Reparaturpfad. Menüleisten-Fenster nicht bedienbar
  (Computer Use findet den Agent nicht); Pager und „Noch kein Backup zum Prüfen“ nur automatisiert belegt.
- Restore-Pagination: Seiten zu 500 (`entryOffset`, `reveal`), XPC Version 8, Ordner ≤50.000 Einträge,
  Katalog ≤1.024 Quellen/10.000 Snapshots, Kopia-Antworten ≤32 MiB; echter Kopia-Ordner mit 501 Dateien getestet.
- WebDAV-Test-Fixture (nicht Produkt): Kopia sendet PROPFIND-Bodies chunked; Fixture spricht jetzt HTTP/1.1
  Keep-alive ohne Idle-Timeout mit RFC-9112-Decoding; Integrationstest verlangt Trace ohne unlesbare Requests.
  CI lädt bei Fehlschlag Kopia-Logs/Fixture-stderr hoch (7 Tage). Hang-Guards für XPC (30 s)/Dienst (120 s).
- Audit-Befund behoben (`claude/p5-orphan-kopia`): verwaiste Kopia-Kinder nach Agent-Abbruch. Agent leitet SIGTERM
  in den geordneten Shutdown; Dienststart beendet nur eigene Waisen (`KopiaOrphanReaper`, PROJEKT.md §17 2026-11-11).
  582 Tests/109 Suites, nur die 6 TLS-Suites rot; Xcode `build test` grün, Lint sauber.
  Live: erster SIGTERM-Pfad hing (terminate aus Main-Queue-Block → Shutdown-Task startet nie); behoben über
  `RunLoop.main.perform`, AppKit-Repro alt hängt/neu Exit 0. Live-Nachweis im registrierten Agent offen.
  Gotcha: Freigabe aus/an hinterlässt launchd-Job mit alter BTM-UUID (EX_CONFIG); „Hintergrunddienst aktivieren“ repariert.
- Details, Live-Fehler und Neubau-Ablauf (Freigabe aus/an, „Hintergrunddienst aktivieren“):
  [Archiv 2026-11-10](history/STATUS-Phase5-Pagination-2026-11-10.md), [Phase-5-Audit](history/Phase5-Qualitaetsaudit-2026-10-26.md).

## Offene Live-Nachweise und Grenzen – kein globaler Entwicklungsstopp

| Nachweis | Betroffene Funktion | Exakte nächste Aktion / Besitzer |
|---|---|---|
| **Ad-hoc-Agent durch BTM-Spawn-Constraint auf eine cdhash festgenagelt** (`launchctl print` → `LWCR reqs cdhash $in [...]`; AMFI `c[5]p[1]m[1]e[0]` = LWCR-Spawn-Constraint, Prozess selbst, kein Treffer). Team-signierte Agents bekommen `team-identifier`+`signing-identifier` | Jeder Neubau bricht den registrierten Dienst; **im Release jedes Update** bei kontolosem Vertrieb | Nutzer: Produktentscheidung (Vertrieb/Startmechanismus), siehe Audit. Entwicklung (belegt): nach jedem Build mit geändertem Agent-Binary Hintergrundfreigabe aus/ein → Freigabe pinnt den aktuellen Build; reine App-Änderungen ändern die Agent-cdhash nicht (Agent danach per `launchctl kickstart -k` neu starten, weil er die App-Signatur beim Start bindet) |
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
| Sehr große Kataloge/Verzeichnisse | Restore-Browser | >1.024 Quellen/10.000 Snapshots/8 MiB bzw. >50.000 Einträge je Ordner blockieren; Seiten zu 500 nur automatisiert und mit echtem Kopia (501 Dateien) geprüft, Live-UI offen |
| Gatekeeper/Updates, Checkpoint 45 statt 15 Minuten | Release | Phase 6: Installationsartefakt prüfen; Checkpoint-Produktentscheidung treffen |
| Reales SFTP/SSH/Host-Key | Provider-Kompatibilität | Nutzer stellt entbehrlichen Testordner und öffentlichen Host-Key über vertrauenswürdigen Kanal bereit; Agent prüft Create/Connect/Backup/Restore/Schlüsselwechsel |

## Nächster vollständiger Coding-Auftrag

**Phase 5 fortsetzen: zusammenhängender UI-/Accessibility-/Performance-Audit mit Temp-Workflow.**

Einstieg: PROJEKT.md §4–§5, §11–§14 Phase 5, AGENTS.md §7, IMPLEMENTIERUNG.md und Audit oben.
Native Verbindung und Dienstregistrierung sind positiv belegt; Freigabe für Temp-Workflow liegt vor.
Fenster/Menüleiste/Shortcuts, Fehleraktionen/Remote-Assistenten prüfen; DE/EN, Light/Dark/Kontrast, minimales
Fenster, Tastatur/VoiceOver mit Screenshots erfassen und Instruments Idle-CPU/Speicher/I/O/Updatefrequenz messen.
Neues Temp-Ziel einrichten; Pager im Fenster mit >500 Einträgen sichten. Agent-Neubau seit dem letzten Live-Lauf:
Hintergrundfreigabe aus/an. FDA abgelehnt; geschützten Live-Lauf nur nach neuer ausdrücklicher Freigabe.
Keine spekulativen Frameworks/Entitlements; reale Provider/Hardware bleiben separat.
Fertig: belegter integrierter Audit, behobene Befunde mit Tests, relevante Prüfungen und kompakte Übergabe.
Name/Bundle-Präfix MacKopia / com.example.MacKopia; Lizenzmodell offen.
