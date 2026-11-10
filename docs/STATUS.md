# Status & nächster Auftrag

Stand: 2026-11-10. Einstieg: AGENTS.md, dieser Status, PROJEKT.md §14 und IMPLEMENTIERUNG.md.
Historische Evidenz bleibt im [Archiv](history/README.md).

## Aktuelle Produktphase

**Phase 5: Bedienlücken geschlossen, Restore-Pagination umgesetzt; Live-Audit offen.**
Phase 1–4 integriert; Phase-5-Bedienlücken über [PR #8](https://github.com/drhdevorg/mackopia/pull/8) auf `main` (`19a0a6d`).
Aktueller Arbeitsbranch: `claude/p5-restore-pagination` (Basis `main` @ `19a0a6d`). Phase 5 bleibt offen.

## In progress

| Agent | Auftrag | Branch | Dateien/Module |
|---|---|---|---|
| Claude | Restore-Browser-Pagination (Verzeichnisse seitenweise, größerer Katalog, Suchtreffer auf ihrer Seite) | `claude/p5-restore-pagination` | BackupEngine/RestoreBrowser, LocalServiceRestore, AgentProtocol, KopiaServerClient, App/Restore*, docs/ |

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

- Lokal (Xcode 27.1 / Swift 6.4 / arm64) bleiben 6 KopiaServer-Netzwerksuites rot (`FixtureError.startFailed`):
  `native_tls_fixture.py` braucht TLS 1.3, hier gibt es nur LibreSSL-Python; mit `MACKOPIA_TEST_PYTHON` auf
  OpenSSL-3-Python ausführen. GitHub-CI (`xcode-27`) ist auf `main` grün; Watchdog/30-Minuten-Timeout gegen Hänger.
- **Live 2026-11-10 geprüft (temp-Plan, Debug-Build):** Finder-Drop mehrerer Ordner, ⌫, Schutz der letzten Quelle,
  ⌘Z/⇧⌘Z mit Rückkehr an alte Position; Route per verteilter Mitteilung (laufende App, unbekannter Wert ignoriert)
  und per Startargument (Kaltstart); „Aktivität anzeigen“ nach fehlgeschlagener Prüfung. Zwei Live-Fehler behoben:
  Drop erreicht in gruppierter `Form` nur Section/Form (Test-Harness: List/ForEach-Drop feuert dort nie) und
  Startroute wurde vom Fensteraufbau überschrieben (jetzt in `.task`). Menüleisten-Fenster selbst nicht bedienbar
  (Computer Use findet den Agent nicht); Routen-Mechanik direkt ausgelöst. Kein XCUITest vorhanden.
- Behoben: Aktivität zeigt neben Backup-Läufen die jeweils letzte
  Integritätsprüfung, Testwiederherstellung und Wartung je Plan (`ActivityEntry`, Spalten Vorgang/Plan, Fehler rot
  mit Symbol); `LocalServiceState.activeWork` unterscheidet Backup/Prüfung/Abschluss/Wartend für Übersicht und
  Menüleiste. Ältere Prüfungen bleiben ungespeichert (nur letzter Stand je Plan). Offen: Drop-Reihenfolge folgt Finder.
  Prüfung: 575 Tests, nur die 6 bekannten TLS-Suites rot; WebDAV-Lebenszyklus deckte eine Lese-Reihenfolge-Race in
  `currentWork()` auf (behoben, danach 3× grün). Xcode `build test` grün, keine Warnung, Lint sauber.
- Live 2026-11-10 (bc23fe3): neue Spalten und „Integritätsprüfung läuft“ bestätigt. Prüfung, die vor dem
  Kopia-Aufruf scheitert, speichert absichtlich keinen Nachweis; sie meldet jetzt ihren Grund statt `verificationFailed`
  (`SnapshotVerificationEngine.attemptVerification`, `AutomaticBackupIssue.checkNotStarted`): Preflight-Ablehnung →
  dieselbe Zuordnung wie Backups (`LocalBackupService.failure(for:)`, z. B. „Speicherziele anzeigen“), kein erfolgreiches
  Backup → neues `noBackupToVerify` mit „Jetzt sichern“. Live: Ziel-Fall bestätigt (Temp-Root war gelöscht);
  „Noch kein Backup zum Prüfen“ nur durch Tests belegt. Vollsuite seriell 577 Tests, nur 6 TLS-Suites rot.
  Neubau-Ablauf: Freigabe aus/an, dann in der App „Hintergrunddienst aktivieren“, Keychain-Abfrage durch Nutzer.
- Live 2026-11-10 gefunden und behoben: „Hintergrunddienst aktivieren“ blieb bei `requiresApproval` und bei
  „enabled“ ohne startbaren launchd-Job stumm. Jetzt Freigabehinweis + Anmeldeobjekte bzw. explizite Reparatur
  (unregister/register, nur ohne Verbindung). 10 Registrierungstests grün; Hinweis live in der App gesehen.
- Vorherige Codex-Evidenz (Registrierung, Editor-Sheets, Instruments-Idle, Temp-Ziel, FDA-Block): Audit unten.
- **Restore-Pagination (2026-11-10, `claude/p5-restore-pagination`):** `browse` trägt `entryOffset` (Vielfaches von 500)
  und optional `reveal`; XPC Version 8. Ordner bis 50.000 Einträge, Katalog bis 1.024 Quellen/10.000 Snapshots,
  Kopia-Verzeichnis-/Manifestantworten bis 32 MiB. Ein Browse liest die Quellen nur noch einmal (Katalog an `resolve`).
  `RestorePager` (Vor/Zurück, „1–500 von 12.345“, A11y-Labels) erscheint nur bei mehr als einer Seite; Dateitreffer
  öffnen ihre Seite mit Auswahl. Tests: Browser-Paging/-Grenzen/-Reveal, Request-Validierung, echter Kopia-Ordner mit
  501 Dateien (zweite Seite, Seite hinter dem Ende abgewiesen, Reveal).
  Prüfung: Vollsuite seriell 581 Tests/108 Suites, nur die 6 TLS-Suites rot (62× `startFailed`); Xcode `build test`
  grün (4 Bundle-/Signaturtests), keine Warnung, Lint sauber. Pager live im Fenster noch nicht gesehen.
- Behoben: sporadische WebDAV-Prüfablehnung (lokal unter Last, CI 2× auf PR #9) lag am Test-Fixture, nicht am
  Produkt. Der threadende Fixture-Server brach PROPFIND ab, wenn Kopia während der Auflistung eigene Log-Blobs
  umbenannte (Stresstest: 1.438 von 3.000 Listings ohne Antwort). Jetzt überspringt er verschwundene Einträge,
  schreibt PUT atomar und antwortet bei gleichzeitig gelöschtem Objekt mit 404 (`test_storage_fixture_concurrency`).

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
Fenster/Menüleiste/Shortcuts,
Fehleraktionen/Remote-Assistenten prüfen; DE/EN, Light/Dark/Kontrast, minimales Fenster, Tastatur/VoiceOver
mit Screenshots erfassen und Instruments Idle-CPU/Speicher/I/O/Updatefrequenz messen.
FDA-Freigabe abgelehnt; geschützten Live-Lauf erst nach einer neuen ausdrücklichen Freigabe fortsetzen.
Temp-Root `/private/tmp/mackopia-live-audit-xp05r3_k` ist gelöscht: für weitere Live-Läufe neues Temp-Ziel einrichten. Danach Quellen-/Snapshot-Pagination; keine spekulativen Frameworks/Entitlements. Registrierung/FDA/Keychain
nur mit bewussten nötigen Systemfreigaben; reale Provider/Hardware bleiben separat.
Fertig: belegter integrierter Audit, behobene Befunde mit Tests, relevante Prüfungen und kompakte Übergabe.
Name/Bundle-Präfix MacKopia / com.example.MacKopia; Lizenzmodell offen.
