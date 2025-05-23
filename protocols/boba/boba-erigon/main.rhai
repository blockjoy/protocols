import "base" as base;
import "aux" as aux;

const CADDY_DIR = node_env().data_mount_point + "/caddy";
const RPC_PORT = 9545;
const WS_PORT = 9546;
const OP_RPC_PORT = 8545;
const AUTH_RPC_PORT = 8551;
const PRIV_API_PORT = 9090;
const METRICS_PORT = 6262;
const METRICS_PATH = "/debug/metrics/prometheus";

const VARIANTS = #{
    "erigon-mainnet-archive": #{
        url: "https://mainnet.boba.network",
        network: "boba-mainnet",
        l1_url: "https://eth-l1.blkjy.io",
        l1_beacon_url: "https://lighthouse.blkjy.io",
    },
};

const VARIANT = VARIANTS[node_env().node_variant];
const API_HOST = "http://127.0.0.1:" + global::RPC_PORT;
const HOME = node_env().protocol_data_path + "/erigon";
const NET = VARIANT.network;
const SEQUENCER_URL = VARIANT.url;
const L1_URL = VARIANT.l1_url;
const L1_BEACON_URL = VARIANT.l1_beacon_url;

fn plugin_config() {
    #{
        config_files: base::config_files() + aux::config_files(global::METRICS_PORT, global::METRICS_PATH, global::RPC_PORT, global::WS_PORT, global::CADDY_DIR),
        aux_services: base::aux_services() + aux::aux_services(),
        init: #{
            commands: [
                `mkdir -p ${global::HOME}`,
                `mkdir -p ${global::CADDY_DIR}`,
            ],
            jobs: [
                #{
                    name: "create_jwt",
                    run_sh: `openssl rand -hex 32 > ${global::HOME}/jwt.hex`,
                }
            ]
        },
        services: [
            #{
                name: "erigon",
                run_sh: `/root/bin/erigon --datadir=${global::HOME} --private.api.addr=127.0.0.1:${global::PRIV_API_PORT} --http.addr=127.0.0.1 --http.port=${global::RPC_PORT} --http.corsdomain="*" --http.vhosts="*" --ws --ws.port ${global::WS_PORT} --metrics --metrics.addr=127.0.0.1 --metrics.port=${global::METRICS_PORT} --bodies.cache=5G --rpc.batch.limit=200000 --db.pagesize=16k --downloader.disable.ipv6 --authrpc.addr=127.0.0.1 --authrpc.port=${global::AUTH_RPC_PORT} --authrpc.vhosts="*" --authrpc.jwtsecret=${global::HOME}/jwt.hex --chain=${global::NET} --http.api=eth,debug,net,engine,web3,debug,trace --rollup.sequencerhttp=${global::SEQUENCER_URL} --db.size.limit=8TB`,
                shutdown_timeout_secs: 120,
            },
            #{
                name: "op-node",
                run_sh: `/root/bin/op-node --l1=${global::L1_URL} --l1.beacon=${global::L1_BEACON_URL} --l2=http://127.0.0.1:${global::AUTH_RPC_PORT} --l2.jwt-secret=${global::HOME}/jwt.hex --network=${global::NET} --rpc.addr=127.0.0.1 --rpc.port=${global::OP_RPC_PORT}`,
                shutdown_timeout_secs: 120,
            },
        ],
    }
}

fn protocol_status() {
    let resp = run_jrpc(#{host: global::API_HOST, method: "/"});

    if resp.status_code == 200 {
        #{state: "broadcasting", health: "healthy"}
    } else {
        #{state: "delinquent", health: "healthy"}
    }
}

fn height() {
    parse_hex(run_jrpc(#{host: global::API_HOST, method: "eth_blockNumber"}).expect(200).result)
}

fn sync_status() {
    let resp = run_jrpc(#{host: global::API_HOST, method: "eth_syncing"}).expect(200);
    if resp.result == false {
        "synced"
    } else {
        "syncing"
    }
}
