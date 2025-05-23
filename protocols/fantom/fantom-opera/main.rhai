import "base" as base;
import "aux" as aux;

const CADDY_DIR = node_env().data_mount_point + "/caddy";
const RPC_PORT = 8080;
const WS_PORT = 8081;
const P2P_PORT = 5050;
const METRICS_PORT = 6060;
const METRICS_PATH = "/debug/metrics/prometheus";

const FANTOM_API = "http://127.0.0.1:" + global::RPC_PORT;
const FANTOM_DIR = node_env().protocol_data_path + "/fantom";

const VARIANTS = #{
    "opera-mainnet-archive": #{
        genesis_url: "https://files.fantom.network/mainnet-109331-full-mpt.g",
    },
};

const VARIANT = VARIANTS[node_env().node_variant];

fn plugin_config() {
    #{
        config_files: base::config_files() + aux::config_files(global::METRICS_PORT, global::METRICS_PATH, global::RPC_PORT, global::WS_PORT, global::CADDY_DIR),
        aux_services: base::aux_services() + aux::aux_services(),
        init: #{
            commands: [
                `mkdir -p ${global::FANTOM_DIR}/data`,
                `mkdir -p ${global::CADDY_DIR}`,
            ],
            jobs: []
        },
        services: [
            #{
                name: "opera",
                run_sh: `/root/bin/opera --genesis=${global::FANTOM_DIR}/mainnet-5577-full-mpt.g --datadir=${global::FANTOM_DIR}/.opera --http --http.addr=127.0.0.1 --http.port=${global::RPC_PORT} --http.corsdomain=* --http.api=eth,web3,net,txpool,ftm,trace --ws --ws.addr=127.0.0.1 --ws.port=${global::WS_PORT} --ws.origins=* --ws.api=eth,web3,net,txpool,ftm,trace --port ${global::P2P_PORT} --maxpeers 165 --cache 32000 --tracenode --metrics --metrics.addr 127.0.0.1 --metrics.port ${global::METRICS_PORT} --db.preset pbl-1`,
                shutdown_timeout_secs: 300,
            },
        ],
        download: #{
            max_connections: 5,
        },
        upload: #{
            exclude: [],
        },
    }
}

fn protocol_status() {
    let resp = run_jrpc(#{host: global::FANTOM_API, method: "/"});

    if resp.status_code == 200 {
        #{state: "broadcasting", health: "healthy"}
    } else {
        #{state: "delinquent", health: "healthy"}
    }
}

fn height() {
    let resp = run_jrpc(#{host: global::FANTOM_API, method: "eth_blockNumber"});
    if resp.status_code != 200 {
      throw resp;
    }
    let h = parse_json(resp.body);
    parse_int(sub_string(h.result,2),16)
}

fn sync_status() {
    let resp = run_jrpc(#{host: global::FANTOM_API, method: "eth_syncing"}).expect(200);
    if resp.result == false {
        "synced"
    } else {
        "syncing"
    }
}
