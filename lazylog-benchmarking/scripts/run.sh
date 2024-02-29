#!/bin/bash
PASSLESS_ENTRY="/users/JiyuHu23/.ssh/dassl_rsa"

# remote_nodes=("034" "078" "097" "007" "090" "030" "096" "116")
# ips=("3" "4" "2" "1" "5" "6" "7" "8")

benchmark_dir="/proj/rasl-PG0/jiyu/scalog-benchmarking/lazylog-benchmarking"
log_dir="/users/JiyuHu23/scalog-storage"
ssh_user="JiyuHu23"

# index into remote_nodes/ips for order nodes
order=("093" "177" "176")

# index into remote_nodes/ips for data shards
data_0=("107" "166")

client_nodes=("109" "167" "103")

cleanup_servers() {
    # kill existing servers
    sudo ./run_script_on_all.sh ./kill_all_goreman.sh

    # mount storage and clear existing logs if any
    sudo ./run_script_on_all.sh ./setup_disk.sh
}

cleanup_servers_wo_log_clear() {
    # kill existing servers
    sudo ./run_script_on_all.sh ./kill_all_goreman.sh
}

cleanup_client() {
    ssh -i $PASSLESS_ENTRY "${ssh_user}@hp$1.utah.cloudlab.us" "cd $benchmark_dir/scripts; sudo pkill -f \"append_bench\""
}

start_order_nodes() {
    # start order nodes
    for ((i=0; i<=2; i++))
    do
        echo "Starting order-${i} on ${ssh_user}@hp${order[$i]}.utah.cloudlab.us"
        ssh -i $PASSLESS_ENTRY "${ssh_user}@hp${order[$i]}.utah.cloudlab.us" "cd $benchmark_dir/order-$i; nohup sudo ./run_goreman.sh > ${log_dir}/order-$i.log 2>&1 &"
    done
}

start_data_nodes() {
    # start data nodes
    for ((i=0; i<=1; i++))
    do
        echo "Starting data-0-${i} on ${ssh_user}@hp${data_0[$i]}.utah.cloudlab.us"
        ssh -i $PASSLESS_ENTRY "${ssh_user}@hp${data_0[$i]}.utah.cloudlab.us" "cd $benchmark_dir/data-0-$i; nohup sudo ./run_goreman.sh > ${log_dir}/data-0-$i.log 2>&1 &"
    done
}

start_discovery() {
    # start discovery
    echo "Starting discovery on ${ssh_user}@hp${data_0[0]}.utah.cloudlab.us"
    ssh -i $PASSLESS_ENTRY "${ssh_user}@hp${data_0[0]}.utah.cloudlab.us" "cd $benchmark_dir/disc; nohup sudo ./run_goreman.sh > ${log_dir}/disc.log 2>&1 &"
}

check_data_log() {
    for ((i=0; i<=1; i++))
    do
        echo "Checking data node $i..."
        ssh -i $PASSLESS_ENTRY "${ssh_user}@hp${data_0[$i]}.utah.cloudlab.us" "grep error ${log_dir}/scalog-storage/data-0-$i.log"
    done
}

start_client() {
    ssh -i $PASSLESS_ENTRY ${ssh_user}@hp$1.utah.cloudlab.us "cd $benchmark_dir/scripts; sudo ./run_client.sh $2 $3 $1 $4 > ${log_dir}/client_$1.log 2>&1" &
}

check_data_log() {
    for ((i=0; i<=1; i++))
    do
        echo "Checking data node $i..."
        ssh -i $PASSLESS_ENTRY "${ssh_user}@hp${data_0[$i]}.utah.cloudlab.us" "grep error ${log_dir}/data-0-$i.log"
    done
}

# single client
# clients=("1300" "1000" "1000" "700" "512" "256" "128" "64" "30" "24" "20" "18" "16" "12")
# clients=("1800" "1500" "1300" "1000" "700" "600" "500")
clients=("500" "600" "700" "1000" "1300" "1500" "1800" "2100")
# clients=("1800")

# two clients
# clients=("600" "700" "800" "900" "1000" "1200")
# clients=("10")

len=${#clients[@]}
# for ((i = len - 1; i >= 0; i--));
for c in "${clients[@]}"; 
do
    # c="${clients[i]}"
    for client_node in "${client_nodes[@]}";
    do
        cleanup_client $client_node
    done 

    cleanup_servers

    start_order_nodes
    start_data_nodes 
    start_discovery

    # wait for 10 secs
    sleep 10

    num_client_nodes=${#client_nodes[@]}

    for client_node in "${client_nodes[@]}";
    do
        # run client
        # start_client <client_id> <num_of_clients_to_run> <num_appends_per_client> <total_clients>
        start_client $client_node $(($c/$num_client_nodes)) "4m" $c
    done

    echo "Waiting for clients to terminate"
    wait

    for client_node in "${client_nodes[@]}";
    do
        cleanup_client $client_node
    done
    cleanup_servers_wo_log_clear
    check_data_log
done