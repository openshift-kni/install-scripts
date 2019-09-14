#!/usr/bin/env bash
set -xe

source ../common/logging.sh
source ../common/utils.sh
source common.sh

export KUBECONFIG=${KUBECONFIG:-ocp/auth/kubeconfig}
POSTINSTALL_ASSETS_DIR="./assets/post-install"
IFCFG_INTERFACE="${POSTINSTALL_ASSETS_DIR}/ifcfg-interface.template"
IFCFG_BRIDGE="${POSTINSTALL_ASSETS_DIR}/ifcfg-bridge.template"
BREXT_FILE="${POSTINSTALL_ASSETS_DIR}/99-brext-master.yaml"
MACHINE_DATA_PATCH_DIR="../preflight"

export bridge="${bridge:-brext}"

create_bridge(){
  echo "Deploying Bridge ${bridge}..."

  FIRST_MASTER=$(oc get node -o custom-columns=IP:.status.addresses[0].address --no-headers | head -1)
  export interface=$(ssh -q -o StrictHostKeyChecking=no core@$FIRST_MASTER "ip r | grep default | grep -Po  '(?<=dev )(\S+)'")
  if [ "$interface" == "" ] ; then
    echo "Issue detecting interface to use! Leaving..."
    exit 1
  fi
  if [ "$interface" != "$bridge" ] ; then
    echo "Using interface $interface"
    export interface_content=$(envsubst < ${IFCFG_INTERFACE} | base64 -w0)
    export bridge_content=$(envsubst < ${IFCFG_BRIDGE} | base64 -w0)
    envsubst < ${BREXT_FILE}.template > ${BREXT_FILE}
    echo "Done creating bridge definition"
  else
    echo "Bridge already there!"
  fi
}

apply_mc(){
  # Disable auto reboot hosts in order to apply several mcos at the same time
  for node_type in master worker; do
    oc patch --type=merge --patch='{"spec":{"paused":true}}' machineconfigpool/${node_type}
  done

  # Add extra registry if needed (this applies clusterwide)
  # https://docs.openshift.com/container-platform/4.1/openshift_images/image-configuration.html#images-configuration-insecure_image-configuration
  if [ "${EXTRA_REGISTRY}" != "" ] ; then
    echo "Adding ${EXTRA_REGISTRY}..."
    oc patch image.config.openshift.io/cluster --type merge --patch "{\"spec\":{\"registrySources\":{\"insecureRegistries\":[\"${EXTRA_REGISTRY}\"]}}}"
  fi

  # Apply machine configs
  for node_type in master worker; do
    if $(ls ${POSTINSTALL_ASSETS_DIR}/*-${node_type}.yaml >& /dev/null); then
      echo "Applying machine configs..."
      for manifest in $(ls ${POSTINSTALL_ASSETS_DIR}/*-${node_type}.yaml); do
        oc create -f ${manifest}
      done
    fi
    # Enable auto reboot
    oc patch --type=merge --patch='{"spec":{"paused":false}}' machineconfigpool/${node_type}

    echo "Rebooting nodes..."
    # This sleep is required because the machine-config changes are not immediate
    sleep 30

    # The 'while' is required because in the process of rebooting the masters, the
    # oc wait connection is lost a few times, which is normal
    while ! oc wait mcp/${node_type} --for condition=updated --timeout 600s ; do sleep 1 ; done
  done
}

create_ntp_config(){
  if [ "${NTP_SERVERS}" ]; then
    cp assets/post-install/99-chronyd-custom-master.yaml{.optional,}
    cp assets/post-install/99-chronyd-custom-worker.yaml{.optional,}
    NTPFILECONTENT=$(cat assets/files/etc/chrony.conf)
    for ntp in $(echo ${NTP_SERVERS} | tr ";" "\n"); do
      NTPFILECONTENT="${NTPFILECONTENT}"$'\n'"pool ${ntp} iburst"
    done
    NTPFILECONTENT=$(echo "${NTPFILECONTENT}" | base64 -w0)
    sed -i -e "s/NTPFILECONTENT/${NTPFILECONTENT}/g" assets/post-install/99-chronyd-custom-*.yaml
  fi
}

function link-machine-and-node () {

  machine="$1"
  node_name="$2"

  if [ -z "${machine}" -o -z "${node_name}" ]; then
      echo "Usage: $0 MACHINE NODE"
      exit 1
  fi

  # BEGIN Hack #260
  # Hack workaround for openshift-metalkube/dev-scripts#260 until it's done automatically
  # Also see https://github.com/metalkube/cluster-api-provider-baremetal/issues/49
  oc proxy &
  proxy_pid=$!
  function kill_proxy {
      kill $proxy_pid
  }
  trap kill_proxy EXIT SIGINT

  HOST_PROXY_API_PATH="http://localhost:8001/apis/metal3.io/v1alpha1/namespaces/openshift-machine-api/baremetalhosts"

  wait_for_json oc_proxy "${HOST_PROXY_API_PATH}" 10 -H "Accept: application/json" -H "Content-Type: application/json"

  addresses=$(oc get node -n openshift-machine-api ${node_name} -o json | jq -c '.status.addresses')

  machine_data=$(oc get machine -n openshift-machine-api -o json ${machine})
  host=$(echo "$machine_data" | jq '.metadata.annotations["metal3.io/BareMetalHost"]' | cut -f2 -d/ | sed 's/"//g')

  if [ -z "$host" ]; then
      echo "Machine $machine is not linked to a host yet." 1>&2
      exit 1
  fi

  # The address structure on the host doesn't match the node, so extract
  # the values we want into separate variables so we can build the patch
  # we need.
  export hostname=$(echo "${addresses}" | jq '.[] | select(. | .type == "Hostname") | .address' | sed 's/"//g')
  export ipaddr=$(echo "${addresses}" | jq '.[] | select(. | .type == "InternalIP") | .address' | sed 's/"//g')

  default_host_patch='
{
  "status": {
    "hardware": {
      "hostname": "'${hostname}'",
      "nics": [
        {
          "ip": "'${ipaddr}'",
          "mac": "00:00:00:00:00:00",
          "model": "unknown",
          "speedGbps": 25,
          "vlanId": 0,
          "pxe": true,
          "name": "eno1"
        }
      ],
      "systemVendor": {
        "manufacturer": "Dell Inc.",
        "productName": "PowerEdge r640",
        "serialNumber": ""
      },
      "firmware": {
        "bios": {
          "date": "12/17/2018",
          "vendor": "Dell Inc.",
          "version": "1.6.13"
        }
      },
      "ramMebibytes": 0,
      "storage": [],
      "cpu": {
        "arch": "x86_64",
        "model": "Intel(R) Xeon(R) Gold 6138 CPU @ 2.00GHz",
        "clockMegahertz": 2000,
        "count": 40,
        "flags": []
      }
    }
  }
}
'

  if [[ -f "${MACHINE_DATA_PATCH_DIR}/${host}.json" ]]; then
      host_patch=$(cat ${MACHINE_DATA_PATCH_DIR}/${host}.json | envsubst)
  else
      host_path=${default_host_patch}
  fi

  start_time=$(date +%s)
  while true; do
      echo -n "Waiting for ${host} to stabilize ... "

      time_diff=$(($curr_time - $start_time))
      if [[ $time_diff -gt $timeout ]]; then
          echo "\nTimed out waiting for $name"
          return 1
      fi

      state=$(curl -s \
                   -X GET \
                   ${HOST_PROXY_API_PATH}/${host}/status \
                   -H "Accept: application/json" \
                   -H "Content-Type: application/json" \
                   -H "User-Agent: link-machine-and-node" \
                  | jq '.status.provisioning.state' \
                  | sed 's/"//g')
      echo "$state"
      if [ "$state" = "externally provisioned" ]; then
          break
      fi
      sleep 5
  done

  echo "PATCHING HOST"
  echo "${host_patch}" | jq .

  curl -s \
       -X PATCH \
       ${HOST_PROXY_API_PATH}/${host}/status \
       -H "Content-type: application/merge-patch+json" \
       -d "${host_patch}"

  oc --config ocp/auth/kubeconfig get baremetalhost -n openshift-machine-api -o yaml "${host}"

}

function add-machine-ips() {

  CLUSTER_NAME=$(hostname -f | cut -d'.' -f 2)

  for node_name in $(oc get nodes -o template --template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'); do
      machine_name="${CLUSTER_NAME-}-$(echo ${node_name}" | grep -oE "(master|worker)-[0-9]+")
      if [[ "${machine_name}" == *"worker"* ]]; then
          echo "Skipping worker ${machine_name} because it should have inspection data to link automatically"
          continue
      fi
      link-machine-and-node "${machine_name}" "${node_name}"
  done

}

add-machine-ips
create_bridge
create_ntp_config
apply_mc
