# Collected IT PowerShell Scripts

A curated repository of enterprise-grade PowerShell scripts, automation tools, desktop utilities, and diagnostic suites developed for corporate IT support, systems administration, and end-user computing.

---

## Repository Structure

```
Collected-IT-PowerShell-Scripts/
├── Hardware-Auditing/
│   └── USB-Device-Whitelist/
│       ├── USB Whitelist - Obtain USB Device ID vFinalv2.ps1
│       ├── USB Whitelist - Obtain USB Device ID vFinal.ps1
│       └── Samples/
│           ├── USB Capture 01.csv
│           ├── USB Capture 02.csv
│           └── USB Capture Result.csv
│
├── Helpdesk-Automation/
│   ├── Access-Request-Formatter/
│   │   ├── IB Request - Format List v2.ps1
│   │   └── IB Request - Format List.ps1
│   └── Ticket-Resolution-Generator/
│       ├── Ticket Resolution Generator v2.ps1
│       ├── Ticket Resolution Generator v1.ps1
│       ├── TicketTemplates.txt
│       └── TicketResolutionLog.csv
│
├── Monitoring-Automation/
│   ├── Auto-Refresh-Utility/
│   │   ├── GUI - AutoRefresh v4.ps1
│   │   └── Legacy-Versions/
│   │       ├── GUI - AutoRefresh v1.ps1
│   │       ├── GUI - AutoRefresh v2.ps1
│   │       └── GUI - AutoRefresh v3.ps1
│   └── ServiceNow-Web-Monitors/
│       ├── AMAS SNOW - Auto Refresh.html
│       ├── ServiceNow Incident Queue Monitor.html
│       └── ServiceNow Incident Queue Monitor v2.html
│
├── Network-Diagnostics/
│   └── Endpoint-TLS/
│       ├── Test-EndpointTLS-CLMv2.ps1
│       └── Test-EndpointTLS-CLM.ps1
│
├── Productivity-Tools/
│   └── Teleprompter/
│       ├── Teleprompter v5 GUI v3.ps1
│       └── Legacy-Versions/
│           ├── Teleprompter v1.ps1
│           ├── Teleprompter v2.ps1
│           ├── Teleprompter v3.ps1
│           ├── Teleprompter v4.ps1
│           ├── Teleprompter v5 GUI v1.ps1
│           └── Teleprompter v5 GUI v2.ps1
│
└── Teams-Diagnostics/
    ├── Collect-TeamsCallLogs.ps1
    ├── Teams Diagnostic Collection Tool vProd.ps1
    ├── Test-TeamsDetection.ps1
    └── Legacy-Versions/
        ├── Teams Call Log Collector - Background Script.ps1
        ├── Teams Call Log Collector - Enhanced Script v1.ps1
        ├── Teams Call Log Collector - Enhanced Script v2.ps1
        ├── Teams Call Log Collector - Enhanced Script Zip Func - v3.ps1
        ├── Teams Call Log Collector - Enhanced Script Zip Func - v4.ps1
        ├── Teams Diagnostic Collection Tool v5.ps1
        └── Teams Log Collector - Background Script v1.ps1
```

---

## Domains & Script Catalog

### 1. Hardware Auditing (`Hardware-Auditing/`)

#### USB Device Whitelist & Audit Tool (`USB-Device-Whitelist/`)
* **Primary Script:** `USB Whitelist - Obtain USB Device ID vFinalv2.ps1`
* **Purpose:** Automates the discovery and differential hardware identification of newly attached USB peripherals for enterprise endpoint security and device control whitelisting policies.
* **Key Features:**
  * Takes a baseline snapshot of all connected Plug-and-Play entities matching `USB\*` via WMI/CIM.
  * Prompts the administrator to attach and power on the target hardware device.
  * Executes a secondary scan and performs differential comparison to isolate newly attached devices.
  * Captures `DeviceID`, friendly `Name`, and `PNPClass`, exporting results directly to CSV format.
* **Samples:** Includes example baseline and differential capture files (`USB Capture 01.csv`, `USB Capture 02.csv`, and `USB Capture Result.csv`).

---

### 2. Helpdesk Automation (`Helpdesk-Automation/`)

#### Access Request List Formatter (`Access-Request-Formatter/`)
* **Primary Script:** `IB Request - Format List v2.ps1`
* **Purpose:** Normalizes, deduplicates, and formats bulk user name lists received in ticket requests (e.g., Information Barrier permissions, distribution list additions, and SharePoint access).
* **Key Features:**
  * Accepts multi-line or delimited text input directly from clipboard or terminal.
  * Automatically detects and removes leading ticket labels (e.g., `Access to be granted to:`, `Users:`).
  * Cleans whitespace, deduplicates entries, and provides optional alphabetical sorting.
  * Copies formatted results directly to the Windows clipboard and supports exporting to text files.

#### Ticket Resolution Generator (`Ticket-Resolution-Generator/`)
* **Primary Script:** `Ticket Resolution Generator v2.ps1`
* **Purpose:** Standardizes service desk ticket documentation and customer communications across common IT scenarios (hardware deployments, software installations, access requests, password resets).
* **Key Features:**
  * Reads template definitions dynamically from `TicketTemplates.txt`.
  * Interactive CLI prompts technicians for required placeholders (e.g., `{UserName}`, `{SoftwareName}`).
  * Auto-logs ticket generation metadata to `TicketResolutionLog.csv` (timestamp, ticket type, technician name).
  * Automatically creates an `Output/` folder for generated resolution text files.

---

### 3. Monitoring & Automation (`Monitoring-Automation/`)

#### Auto-Refresh Utility (`Auto-Refresh-Utility/`)
* **Primary Script:** `GUI - AutoRefresh v4.ps1`
* **Purpose:** Keeps operational dashboards (ServiceNow, monitoring consoles) refreshed without interrupting administrative work or stealing window focus.
* **Key Features:**
  * Operates a dedicated Microsoft Edge profile via the Edge/Chrome DevTools Protocol (CDP) WebSocket.
  * Triggers page reloads silently in the background, resolving focus-stealing limitations inherent to legacy `SendKeys("{F5}")` implementations.
  * Features a Windows Forms GUI with countdown timers, adjustable intervals, tray minimization, and configuration persistence.
* **Legacy Versions:** Includes historical iterations (`v1`–`v3`) demonstrating the transition from Win32 API window activation (`user32.dll!SetForegroundWindow`) to modern browser automation.

#### ServiceNow Web Monitors (`ServiceNow-Web-Monitors/`)
* **Scripts:** `ServiceNow Incident Queue Monitor v2.html`, `AMAS SNOW - Auto Refresh.html`
* **Purpose:** Lightweight client-side browser dashboard frames designed for network operations center (NOC) and helpdesk displays.
* **Key Features:**
  * Embedded iframes for ServiceNow incident queues with automated refresh timers.
  * Dropdown controls for interval selection and manual pause/resume functionality.

---

### 4. Network Diagnostics (`Network-Diagnostics/`)

#### Endpoint TLS & Connectivity Diagnostics (`Endpoint-TLS/`)
* **Primary Script:** `Test-EndpointTLS-CLMv2.ps1`
* **Purpose:** Comprehensive network and SSL/TLS diagnostic utility designed to troubleshoot corporate endpoint connectivity issues under strict security configurations.
* **Key Features:**
  * **Constrained Language Mode (CLM) Compatible:** Runs reliably in restricted enterprise environments where custom .NET types or assemblies are blocked by AppLocker / WDAC.
  * Validates DNS resolution using `Resolve-DnsName`.
  * Tests TCP port 443 connectivity via `Test-NetConnection`.
  * Uses native Windows `curl.exe` with certificate store validation enabled (no insecure bypasses) to inspect complete TLS handshake negotiations.
  * Captures local IP configuration and WinHTTP proxy configuration (`netsh winhttp show proxy`).
  * Generates structured log files under `$env:TEMP`.

---

### 5. Productivity & Presentation Tools (`Productivity-Tools/`)

#### Teleprompter Utility (`Teleprompter/`)
* **Primary Script:** `Teleprompter v5 GUI v3.ps1`
* **Purpose:** Full-featured desktop teleprompter utility built with WPF and XAML, designed for technical presentations, town halls, and recorded video sessions.
* **Key Features:**
  * Direct ingestion of Microsoft Word (`.docx`) documents via COM object automation.
  * Highly customizable launcher GUI: font family, font size, text alignment, mirror/flip mode for beam-splitter glass, and multi-monitor selection.
  * Smooth auto-scrolling with millisecond timer precision and multi-tiered speed presets (Levels 1–5).
  * Real-time keyboard hotkeys during prompting (`Space` to pause/resume, `+`/`-` to alter speed, `Esc` to exit).
* **Legacy Versions:** Preserves the design progression from early console scripts (`v1`–`v4`) to interactive XAML GUIs (`v5 GUI v1`–`v2`).

---

### 6. Collaboration & Voice Diagnostics (`Teams-Diagnostics/`)

#### Microsoft Teams Call Log Collector & Diagnostic Suite
* **Primary Scripts:**
  * `Collect-TeamsCallLogs.ps1` (Real-Time Directory Polling Collector)
  * `Teams Diagnostic Collection Tool vProd.ps1` (Production CLM-Optimized Collector)
  * `Test-TeamsDetection.ps1` (FileSystem & Event Detection Diagnostic)
* **Purpose:** Real-time log capture and diagnostic analysis for intermittent Microsoft Teams call drops and audio/video issues in enterprise environments.
* **Key Features:**
  * **CLM Optimization:** Built to run under PowerShell Constrained Language Mode on locked-down enterprise machines.
  * Monitors critical Teams log paths (`%APPDATA%\Microsoft\Teams`, media-stack, skylib, and new Teams packages).
  * Automatically bundles relevant logs into timestamped ZIP archives with manifest logging when calls or directory changes are detected.
  * `Test-TeamsDetection.ps1` diagnoses the underlying file system events and verifies `FileSystemWatcher` support.
* **Legacy Versions:** Contains background collection prototypes, enhanced scripts, and v1–v5 development builds in `Legacy-Versions/`.

---

## Compatibility & Requirements

| Environment Component | Requirement |
| :--- | :--- |
| **Operating System** | Windows 10 / Windows 11 / Windows Server 2016+ |
| **PowerShell Version** | Windows PowerShell 5.1 or PowerShell 7.x |
| **Language Mode** | Compatible with Full Language Mode; select diagnostic scripts (Teams, Endpoint-TLS) are explicitly optimized for **Constrained Language Mode (CLM)** |
| **Execution Policy** | `RemoteSigned` or `Bypass` for script execution (`Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned`) |
| **External Dependencies** | `curl.exe` (built-in on Windows 10+), Microsoft Edge (for CDP auto-refresh), Microsoft Word (optional, for Teleprompter `.docx` parsing) |

---

## License

This collection is licensed under the terms described in the [LICENSE](LICENSE) file.
