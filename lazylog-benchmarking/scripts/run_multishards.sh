#!/bin/bash
PASSLESS_ENTRY="/users/JiyuHu23/.ssh/dassl_rsa"

benchmark_dir="/proj/rasl-PG0/jiyu/scalog-benchmarking/lazylog-benchmarking"
log_dir="/users/JiyuHu23/scalog-storage"
ssh_user="JiyuHu23"

# index into remote_nodes/ips for order nodes
order=("hp158" "hp127" "hp144")
# order=("hp158")

# index into remote_nodes/ips for data shards
data=(
    "hp121 hp147"
    "hp021 hp126"
    "hp039 hp159"
    "hp038 hp036"
    "hp124 hp123"
    # "hp127 hp144"
)

client_nodes=("hp136" "hp034" "hp007")
# client_nodes=("hp136" "hp034")
node_ip=""

get_node_ip() {
    node_ip=$(ssh -i ${PASSLESS_ENTRY} ${ssh_user}@$1.utah.cloudlab.us \
        "ifconfig | grep 'netmask 255.255.255.0'")
    node_ip=$(echo $node_ip | awk '{print $2}')
}

modify_batching_intervals() {
    sed -i "s|order-batching-interval: .*|order-batching-interval: $1|" ${benchmark_dir}/../.scalog.yaml
    sed -i "s|data-batching-interval: .*|data-batching-interval: $1|" ${benchmark_dir}/../.scalog.yaml
}

forge_yaml() {
    order_num="${#order[@]}"
    cat <<EOF > ${benchmark_dir}/../.scalog.yaml
order-port: 26733
raft-port: 27238
order-replication-factor: $order_num
order-batching-interval: 0.1ms
EOF

    for ((i=0; i<$order_num; i++))
    do
        get_node_ip ${order[$i]}
        echo "order-$i-ip: \"${node_ip}\"" >> ${benchmark_dir}/../.scalog.yaml
    done

        cat <<EOF >> ${benchmark_dir}/../.scalog.yaml

data-port: 23282
data-replication-factor: 2
data-batching-interval: 0.1ms
EOF

    for ((i=0; i<$1; i++))
    do
        current_data=(${data[$i]})
        for ((j=0; j<2; j++))
        do
            get_node_ip ${current_data[$j]}
            echo "data-$i-$j-ip: \"${node_ip}\"" >> ${benchmark_dir}/../.scalog.yaml
        done
    done

    current_data=(${data[0]})
    get_node_ip ${current_data[0]}
    cat <<EOF >> ${benchmark_dir}/../.scalog.yaml

disc-port: 23472
disc-ip: "${node_ip}"
EOF
}

forge_data_goreman() {
    for ((i=0; i<$1; i++))
    do
        for ((j=0; j<2; j++))
        do
            mkdir -p ${benchmark_dir}/data-$i-$j
            echo "goreman start" > ${benchmark_dir}/data-$i-$j/run_goreman.sh

            cat <<EOF > ${benchmark_dir}/data-$i-$j/run_goreman.sh
#!/bin/bash

goreman start
EOF
            chmod +x ${benchmark_dir}/data-$i-$j/run_goreman.sh

            cat <<EOF > ${benchmark_dir}/data-$i-$j/Procfile
# Use goreman to run \`go get github.com/mattn/goreman\`

data-${i}-${j}: sudo ../../scalog data --config=../../.scalog.yaml --sid=${i} --rid=${j}
EOF
        done
    done
}

cleanup_servers() {
    # kill existing servers
    sudo ./run_script_on_server.sh ./kill_all_goreman.sh
}

cleanup_servers_wo_log_clear() {
    # kill existing servers
    sudo ./run_script_on_server.sh ./kill_all_goreman.sh
}

cleanup_client() {
    ssh -i $PASSLESS_ENTRY "${ssh_user}@$1.utah.cloudlab.us" "cd $benchmark_dir/scripts; sudo pkill -f \"append_bench\""
}

start_order_nodes() {
    # start order nodes
    for ((i=0; i<$1; i++))
    do
        echo "Starting order-${i} on ${ssh_user}@${order[$i]}.utah.cloudlab.us"
        ssh -i $PASSLESS_ENTRY "${ssh_user}@${order[$i]}.utah.cloudlab.us" "cd $benchmark_dir/order-$i; nohup sudo ./run_goreman.sh > ${log_dir}/order-$i.log 2>&1 &"
    done
}

start_data_nodes() {
    # start data nodes
    for ((i=0; i<$1; i++))
    do
        current_data=(${data[$i]})
        for ((j=0; j<2; j++))
        do
            echo "Starting data-${i}-${j} on ${ssh_user}@${current_data[$j]}.utah.cloudlab.us"
            ssh -i $PASSLESS_ENTRY "${ssh_user}@${current_data[$j]}.utah.cloudlab.us" "cd $benchmark_dir/data-${i}-${j}; nohup sudo ./run_goreman.sh > ${log_dir}/data-${i}-${j}.log 2>&1 &"
        done
    done
}

start_discovery() {
    # start discovery
    current_data=(${data[0]})
    echo "Starting discovery on ${ssh_user}@${current_data[0]}.utah.cloudlab.us"
    ssh -i $PASSLESS_ENTRY "${ssh_user}@${current_data[0]}.utah.cloudlab.us" "cd $benchmark_dir/disc; nohup sudo ./run_goreman.sh > ${log_dir}/disc.log 2>&1 &"
}

check_data_log() {
    for ((i=0; i<$1; i++))
    do
        current_data=(${data[$i]})
        for ((j=0; j<2; j++))
        do
            echo "Checking node data-$i-$j ..."
            ssh -i $PASSLESS_ENTRY "${ssh_user}@${current_data[$j]}.utah.cloudlab.us" "grep error ${log_dir}/data-$i-$j.log"
        done
    done
}

start_client() {
    ssh -i $PASSLESS_ENTRY ${ssh_user}@$1.utah.cloudlab.us "cd $benchmark_dir/scripts; sudo ./run_client.sh $2 $3 $1 $4 $5 $6 > ${log_dir}/client_$1.log 2>&1" &
}

# single client
# clients=("1300" "1000" "1000" "700" "512" "256" "128" "64" "30" "24" "20" "18" "16" "12")
# clients=("1800" "1500" "1300" "1000")
clients=("80")
# clients=("200")

batching_intervals=("0.1ms")

curr=$(pwd)
cd ../..
sudo /usr/local/go/bin/go build -buildvcs=false
cd $curr
sleep 5

num_shard="${#data[@]}"

for ((num_s=1; num_s<=$num_shard; num_s++))
do
    echo "Running $num_s shards..."
    forge_yaml $num_s
    forge_data_goreman $num_s
    sleep 10
    for interval in "${batching_intervals[@]}";
    do
        echo "Running interval ${interval}..."
        # modify intervals
        modify_batching_intervals $interval
        for c in "${clients[@]}"; 
        do
            echo "Running $c clients for each shard..."
            # c="${clients[i]}"
            for client_node in "${client_nodes[@]}";
            do
                cleanup_client $client_node
            done 

            cleanup_servers

            # sudo ./run_script_on_all.sh ./setup_disk.sh
            sudo ./run_script_on_all.sh ./remove_tmp

            order_num="${#order[@]}"
            start_order_nodes $order_num
            start_data_nodes $num_s
            start_discovery

            # wait for 10 secs
            sleep 10

            num_client_nodes=${#client_nodes[@]}

            for client_node in "${client_nodes[@]}";
            do
                # run client
                # start_client <client_id> <num_of_clients_to_run> <num_appends_per_client> <total_clients>
                start_client $client_node $(($c*$num_s/$num_client_nodes)) "4m" $c $interval $num_s
            done

            echo "Waiting for clients to terminate"
            wait

            for client_node in "${client_nodes[@]}";
            do
                cleanup_client $client_node
            done
            cleanup_servers_wo_log_clear
            check_data_log $num_s
        done
    done
done