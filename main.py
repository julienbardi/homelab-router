# main.py

from state import State, Interface, Server, Platform, TunnelMode
from operations import (
    add_node_with_client_generated_public_key,
    add_node_without_any_client_generated_public_key,
    revoke_node,
)
from finalize import finalize
from render.server import render_server_configs
from render.client import render_client_configs
from render.qr import render_client_qr_codes


def main():
    state = State()

    # --- bootstrap ---
    state.servers["router"] = Server(
        server_id="router",
        host="10.89.12.1",
    )

    state.interfaces["wgs1"] = Interface(
        iface_name="wgs1",
        server_id="router",
        listen_port=51820,
        vpn_subnet_v4="10.89.13.0/24",
        vpn_subnet_v6="fd89:7a3b:42c0:13::/64",
        lan_subnets=[
            "10.89.12.0/24",
            "fd89:7a3b:42c0::/64",
        ],
        internet_access=True,
        ipv6_access=True,
    )

    # --- mutations ---
    add_node_with_client_generated_public_key(
        state=state,
        node_id="omen30l",
        user_id="julie",
        iface_name="wgs1",
        platform=Platform.WINDOWS,
        tunnel_mode=TunnelMode.SPLIT,
        exclude_subnets=[],
        public_key="n6Oyd3Luvi38C2Mqvh+HPR7V2XqZBigZP1VRRDeRaA4=",
    )

    private_key = add_node_without_any_client_generated_public_key(
        state=state,
        node_id="s22",
        user_id="julie",
        iface_name="wgs1",
        platform=Platform.ANDROID,
        tunnel_mode=TunnelMode.FULL,
        exclude_subnets=["10.89.12.0/24"],
    )

    revoke_node(
        state=state,
        node_id="omen30l",
        reason="device retired",
    )

    # --- FREEZE ---
    frozen = finalize(state)



    configs = render_server_configs(frozen)

    for server_id, cfg in configs.items():
        print(f"\n=== Server {server_id} ===\n")
        print(cfg)


    # --- temporary inspection (non‑UX, non‑API) ---
    print("Generated private key for s22:", private_key)

    client_cfgs = render_client_configs(
        frozen,
        interface_public_keys={
            "wgs1": "SERVER_PUBLIC_KEY_PLACEHOLDER",
        },
    )

    for peer_id, cfg in client_cfgs.items():
        print(f"\n=== Client {peer_id} ===\n")
        print(cfg)


    print("\nFrozen peers:")
    for peer_id, peer in frozen.peers.items():
        print(f"  {peer_id}:")
        print(f"    IP v4: {peer.assigned_ip_v4}")
        print(f"    AllowedIPs: {peer.allowed_ips}")

    qr_images = render_client_qr_codes(client_cfgs)

    for peer_id, img in qr_images.items():
        print(f"QR ready for {peer_id}")
        img.show()  # temporary harness only

if __name__ == "__main__":
    main()
