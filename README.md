# Evidence Organizer

> Bash CLI for pentesters — auto-sort screenshots, logs, and command output by host, port, and finding type.

## The Problem

After an engagement you have hundreds of files named like:
```
screenshot_1.png
192.168.1.10_sqli_DONE.png
rdp_cred_spray_results.log
nmap_output_final_v2.txt
```

Example of Evidence Organizer turns that chaos into:
```
organized/
├── 192.168.1.10/
│   ├── 80-http/sqli/
│   └── recon/
├── 192.168.1.20/
│   └── 3389-rdp/credential/
└── unknown-host/misc/
```

## Usage

```bash
# Make executable
chmod +x evidence-organizer.sh

# Organize a directory
./evidence-organizer.sh ./loot ./organized

# With custom tags
./evidence-organizer.sh ./loot ./organized client-acme q1-2025

# Organize from a specific engagement folder
./evidence-organizer.sh ~/engagements/client_dump ./organized
```

## How It Works

The script parses each filename for three signals:

| Signal | Example | Detected |
|--------|---------|----------|
| IP address | `192.168.1.10_sqli.png` | host: `192.168.1.10` |
| Port number | `scan_p443_vuln.txt` | port: `443` → `https` |
| Finding keyword | `rdp_bruteforce.log` | finding: `brute-force` |

**80+ finding keywords supported:** `sqli`, `xss`, `rce`, `lfi`, `privesc`, `kerberoast`, `ntlm-relay`, `ssrf`, `idor`, `deserialization`, and more.

Each file also gets a `.meta.json` sidecar:
```json
{
  "original_path": "./loot/192.168.1.10_sqli.png",
  "organized_at": "2026-06-08T19:00:00Z",
  "host": "192.168.1.10",
  "port": null,
  "service": null,
  "finding_type": "sqli",
  "tags": ["sqli"]
}
```

## Supported File Types

| Category | Extensions |
|----------|------------|
| Images | `.png .jpg .jpeg .gif` |
| Text / Notes | `.txt .md .csv .xml .json .html` |
| Tool Output | `.log .out .nmap .gnmap` |
| Documents | `.pdf` |

## Requirements

- Bash 4.0+
- Standard GNU coreutils (`find`, `grep`, `awk`, `sed`)
- No external dependencies

## Roadmap

- [ ] `--watch` mode (inotifywait) for real-time organizing
- [ ] HTML index generator
- [ ] Nmap XML parser for auto host/port detection
- [ ] Integration with report template generator

## License

MIT
