[![Build Status](https://travis-ci.org/joemccann/dillinger.svg?branch=master)]([https://github.com/AndyDevla/ipfs-http-cli])

# IPFS HTTP CLI 🖥️

**This utility is an interactive front-end for the Kubo HTTP RPC API.** Run `./main.sh` from the project root (ensure it is executable) and navigate the menus to invoke node, files, MFS, pins, network/swarm, repo, IPNS, or ad-hoc RPC commands.

```bash
╔══════════════════════════════════════════════╗
║           🪐  IPFS Node Manager              ║
╚══════════════════════════════════════════════╝

  API: https://my.domain.net
  User: host-main

  1) Node info
  2) Files (add / get / cat)
  3) MFS (browse / cp / mv / rm)
  4) Pins
  5) Network / Swarm
  6) Repository & GC
  7) IPNS & Keys
  8) Custom command

  0) Exit

Option: 
```

## Configuration

- Define `IPFS_API_URL`, `IPFS_USER`, and `IPFS_PASS` in `config.conf` sitting next to `main.sh`. The script insists all three are present and non-empty.
- If `config.conf` is missing, the startup menu prompts for domain/user/password and automatically prepends `https://` to the host unless you already include a scheme.
- Make sure the IPFS HTTP RPC endpoint is exposed with TLS+Basic Auth before pointing this tool at it.
- You can automatically configure secure HTTP RPC on the host using the `Gateway` option here https://github.com/AndyDevla/ipfs-manager-cli
- If you prefer to do it manually, you can check here https://docs.ipfs.tech/how-to/kubo-rpc-tls-auth/

  ## 🚀 Installation & Usage

### One-Liner Shell Command

Download the repository and automatically run `main.sh`

```bash
curl -sSL https://github.com/AndyDevla/ipfs-http-cli/archive/refs/heads/main.tar.gz | tar xz && cd ipfs-http-cli-main && chmod +x main.sh && ./main.sh
```

### Online Execution (Alpha)

Run an **standalone** version of **ipfs-manager-cli** directly from GitHub without manual cloning:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/AndyDevla/ipfs-http-cli/refs/heads/main/main-standalone.sh)
```
#### or try
```bash
bash <(curl -sSL https://raw.githubusercontent.com/AndyDevla/ipfs-http-cli/refs/heads/main/main-standalone.sh)
```

### Local Setup

Clone the repository for persistent access and development:

```bash
git clone https://github.com/AndyDevla/ipfs-http-cli.git
cd ipfs-http-cli
chmod +x main.sh
./main.sh
```

## Structure

- `main.sh` is the orchestrator: it loads the shared helpers, provides UI utilities, and drives the main menu.
- `lib/` holds reusable helpers (`config.sh`, `api.sh`).
- `menus/` contains each thematic menu in its own file so you can add new sections or subcommands without inflating the entrypoint.

The script is organized into functional modules to ensure a clean and scalable architecture:
  ```text
├── config.conf
├── lib
│   ├── api.sh
│   └── config.sh
├── main.sh
├── menus
│   ├── menu_custom.sh
│   ├── menu_files.sh
│   ├── menu_ipns.sh
│   ├── menu_mfs.sh
│   ├── menu_network.sh
│   ├── menu_node.sh
│   ├── menu_pins.sh
│   └── menu_repo.sh
├── main-standalone.sh
└── README.md
```

## Dependencies

- It is not required to have the IPFS `kubo` binary installed on the computer, since all commands are sent via `curl`. More info here https://docs.ipfs.tech/reference/kubo/rpc/
- `curl`, `jq`, `find`, `tar`, `mktemp`, and standard POSIX shell utilities. `jq` prettifies JSON responses and `curl` calls every `/api/v0/...` endpoint.

## Future modularization

- Each menu lives under `menus/`, so adding a new capability simply means dropping a new `menu_<name>.sh` that exposes `menu_<name>` and sourcing it from `main.sh`.
- Shared helpers live in `lib/`; any future batch command or non-interactive script can reuse `load_config` and `api` to stay consistent with authentication and encoding logic.

⚖️ License
This project is licensed under the GNU General Public License v3.0. You are free to copy, modify, and distribute this software as long as the same license is maintained.

Developed by AndyDevla 🚀
