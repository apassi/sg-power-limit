#!/bin/bash

[[ "$1" == "" ]] && {
    echo "Usage: limit.sh 300  # 300=30% limit"
    exit 1
}
export param_value="$1"

[[ ! -f ./.env ]] && {
    echo "Missing .env"
    exit 1
}
. ./.env


param=$(echo "$param" | jq -cr '. + {"token": "", "lang": "en_us"}')

export token=$(expect -c '
set timeout 5
log_user 0

proc ensure_code {} {
    expect -notransfer -re {"result_code":\s*1}
    if { $expect_out(0,string) == "" } {
        puts "error"
        exit 1
    }
}

spawn uwsc -q ws://$env(HOST):8082/ws/home/overview
send "{\"lang\":\"en_US\",\"token\":\"\",\"service\":\"connect\"}\n"
ensure_code
expect -re {"token":\s+"([^"]*)"}
set token $expect_out(1,string)

send "{\"lang\":\"en_us\",\"token\":\"$token\",\"service\":\"login\",\"passwd\":\"$env(PASSWORD)\",\"username\":\"$env(USERNAME)\"}\n"
ensure_code
expect -re {"token":\s+"([^"]*)"}
puts $expect_out(1,string)
')

echo -e "\n\n"
param=$(echo "$param" | jq -rc '. + { token: env.token }')
query=$(echo $param | jq -r '[to_entries[] | (@uri "\(.key)" + "=" + @uri "\(.value)")] | join("&")')
sleep 1
curl "http://$HOST/device/getParam?$query"


echo -e "\n\n"
json=$(echo $param | jq -r ". + {param_size: \"${#param_value}\", param_value: \"$param_value\"}")
sleep 1
echo $json | curl -XPOST -H 'Content-type: application/json' --data-binary @- "http://$HOST/device/setParam"

echo -e "\n\n"
sleep 1
curl -s "http://$HOST/device/getParam?$query"
