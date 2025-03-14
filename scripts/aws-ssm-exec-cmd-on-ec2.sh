#!/bin/bash

CMD=$1
INSTANCE_ID=$2  
OUTPUT=$3

echo "Command to execute ${CMD}"
echo "Target instance ${INSTANCE_ID}"

if [[ -z "${INSTANCE_ID}" ]]; then
    echo "Error: INSTANCE_ID is empty. Exiting."
    exit 1
fi

CMD_ID="$(aws ssm send-command \
    --region "${AWS_REGION}" \
    --document-name "AWS-RunShellScript" \
    --targets "Key=instanceIds,Values=${INSTANCE_ID}" \
    --parameters "commands=[\"${CMD}\"]" \
    --query 'Command.CommandId' \
    --output text)"

if [[ -z "${CMD_ID}" ]]; then
    echo "Error: Failed to send command."
    exit 1
fi

echo "AWS Command ID: ${CMD_ID}"

CNT=0
while true; do
    CNT=$((CNT + 1))
    echo "Checking command status... (attempt ${CNT})"
    
    STATUS="$(aws ssm get-command-invocation \
        --region "${AWS_REGION}" \
        --instance-id "${INSTANCE_ID}" \
        --command-id "${CMD_ID}" \
        --query 'Status' \
        --output text)"
    
    if [[ "${STATUS}" != "Pending" && "${STATUS}" != "InProgress" && "${STATUS}" != "Delayed" ]]; then
        break
    fi

    if [[ "${CNT}" -eq 10 ]]; then
        echo "Error: Command '${CMD}' never completed."
        exit 42
    fi

    sleep 1
done

echo "Command status: ${STATUS}"
if [[ "${STATUS}" == "Success" ]]; then
    aws ssm get-command-invocation \
        --region "${AWS_REGION}" \
        --instance-id "${INSTANCE_ID}" \
        --command-id "${CMD_ID}" \
        --query 'StandardOutputContent' \
        --output text > "${OUTPUT}"

    echo "The result of AWS command was:"
    cat "${OUTPUT}"
else
    echo "Error: Command '${CMD}' failed with status '${STATUS}'."
    aws ssm get-command-invocation \
        --region "${AWS_REGION}" \
        --instance-id "${INSTANCE_ID}" \
        --command-id "${CMD_ID}" \
        --query 'StandardErrorContent' \
        --output text > "${OUTPUT}"

    echo "The error of AWS command was:"
    cat "${OUTPUT}"

    exit 69
fi
