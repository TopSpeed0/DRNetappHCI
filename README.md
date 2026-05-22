# DRNetappHCI
PowerShell Automation for VMware with SolidFire Storage Replication

## What it does
- Automated DR (Disaster Recovery) for VMware environments with NetApp SolidFire/HCI storage replication
- Config-driven: JSON-based Source↔Destination mapping for vCenter, Clusters, Datastores, Access Groups
- Interactive menu: Test Failover, Failover, Cleanup, DR, VM Migration
- Encrypted credentials management (AES key + encrypted password files)
- Modular architecture with shared function library ([HCIDR_function](https://github.com/TopSpeed0/HCIDR_function) submodule)

## Production use
Successfully used to migrate **4 production sites with zero downtime**.

## Install
Copy folder `HciVMwareDR` to your `WindowsPowerShell\Modules` and run the files from there.

```powershell
Install-Module -Name SolidFire.Core
Install-Module -Name VMware.PowerCli
```

## Background
Built in 2022 as a solo project — no formal CS background, no courses, just self-learning and 4 months of blood, sweat, and Stack Overflow. This project taught me more about code and problem-solving than any classroom could.

Four years later (2026), I decided to give this project a little color with AI — ironically, this very README update was written with AI assistance. Back in 2022 AI wasn't capable of keeping up with this kind of work without hallucinating along the way. The world moves forward, and so do the tools. But the core logic, architecture, and every line of the original code? That's all human. 🧠⚡
