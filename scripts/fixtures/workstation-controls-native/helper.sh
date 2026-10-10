#!/usr/bin/env bash
set -Eeuo pipefail
scenario="$1"
request="$2"
case "$scenario" in
  ok) sleep 0.15; jq -cn --argjson request "$request" '{schema_version:1,type:"result",request_id:$request.request_id,status:"ok",error:null,data:{schema_version:1,density:"compact"}}' ;;
  error) jq -cn --argjson request "$request" '{schema_version:1,type:"result",request_id:$request.request_id,status:"error",error:{code:"command_failed",message:"Fixture failure"},data:null}'; exit 1 ;;
  cancelled) jq -cn --argjson request "$request" '{schema_version:1,type:"result",request_id:$request.request_id,status:"cancelled",error:null,data:null}' ;;
  malformed) printf '{}\n' ;;
  *) exit 2 ;;
esac
