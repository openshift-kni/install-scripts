#!/bin/bash

NAMESPACE="noobaa"
if [ -d /Users ] ; then
    platform=mac
else
    platform=linux
fi

# https://github.com/noobaa/noobaa-operator
wget https://github.com/noobaa/noobaa-operator/releases/download/v1.0.2/noobaa-$platform-v1.0.2;mv noobaa-$platform-* noobaa;chmod +x noobaa

./noobaa install

# https://github.com/umangachapagain/noobaa-mixins/blob/monitoring/noobaa-monitoring.sh
cat <<EOF | oc create -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  labels:
    prometheus: k8s
    role: alert-rules
  name: prometheus-noobaa-rules
  namespace: openshift-monitoring
spec:
  "groups":
  - "name": "noobaa-telemeter.rules"
    "rules":
    - "expr": |
        sum(NooBaa_num_unhealthy_buckets + NooBaa_num_unhealthy_bucket_claims)
      "record": "job:noobaa_total_unhealthy_buckets:sum"
    - "expr": |
        sum(NooBaa_num_buckets + NooBaa_num_buckets_claims)
      "record": "job:noobaa_bucket_count:sum"
    - "expr": |
        sum(NooBaa_num_objects + NooBaa_num_objects_buckets_claims)
      "record": "job:noobaa_total_object_count:sum"
    - "expr": |
        NooBaa_accounts_num
      "record": "noobaa_accounts_num"
    - "expr": |
        NooBaa_total_usage
      "record": "noobaa_total_usage"
EOF

cat <<EOF | oc create -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  labels:
    prometheus: k8s
    role: alert-rules
  name: prometheus-noobaa-alert-rules
  namespace: openshift-monitoring
spec:
  "groups":
  - "name": "bucket-state-alert.rules"
    "rules":
    - "alert": "NooBaaBucketErrorState"
      "annotations":
        "description": "A NooBaa bucket {{ $labels.bucket_name }} is in error   state for more than 6m"
        "message": "A NooBaa Bucket Is In Error State"
        "severity_level": "warning"
        "storage_type": "NooBaa"
      "expr": |
        NooBaa_bucket_status{bucket_name=~".*"} == 0
      "for": "6m"
      "labels":
        "severity": "warning"
    - "alert": "NooBaaBucketReachingQuotaState"
      "annotations":
        "description": "A NooBaa bucket {{ $labels.bucket_name }} is using {{   printf \"%0.0f\" $value }}% of its quota"
        "message": "A NooBaa Bucket Is In Reaching Quota State"
        "severity_level": "warning"
        "storage_type": "NooBaa"
      "expr": |
        NooBaa_bucket_quota{bucket_name=~".*"} > 80
      "labels":
        "severity": "warning"
    - "alert": "NooBaaBucketExceedingQuotaState"
      "annotations":
        "description": "A NooBaa bucket {{ $labels.bucket_name }} is exceeding   its quota - {{ printf \"%0.0f\" $value }}% used"
        "message": "A NooBaa Bucket Is In Exceeding Quota State"
        "severity_level": "warning"
        "storage_type": "NooBaa"
      "expr": |
        NooBaa_bucket_quota{bucket_name=~".*"} >= 100
      "labels":
        "severity": "warning"
    - "alert": "NooBaaBucketLowCapacityState"
      "annotations":
        "description": "A NooBaa bucket {{ $labels.bucket_name }} is using {{   printf \"%0.0f\" $value }}% of its capacity"
        "message": "A NooBaa Bucket Is In Low Capacity State"
        "severity_level": "warning"
        "storage_type": "NooBaa"
      "expr": |
        NooBaa_bucket_capacity{bucket_name=~".*"} > 80
      "labels":
        "severity": "warning"
    - "alert": "NooBaaBucketNoCapacityState"
      "annotations":
        "description": "A NooBaa bucket {{ $labels.bucket_name }} is using all of   its capacity"
        "message": "A NooBaa Bucket Is In No Capacity State"
        "severity_level": "warning"
        "storage_type": "NooBaa"
      "expr": |
        NooBaa_bucket_capacity{bucket_name=~".*"} > 95
      "labels":
        "severity": "warning"
  - "name": "resource-state-alert.rules"
    "rules":
    - "alert": "NooBaaResourceErrorState"
      "annotations":
        "description": "A NooBaa resource {{ $labels.resource_name }} is in error   state for more than 6m"
        "message": "A NooBaa Resource Is In Error State"
        "severity_level": "warning"
        "storage_type": "NooBaa"
      "expr": |
        NooBaa_resource_status{resource_name=~".*"} == 0
      "for": "6m"
      "labels":
        "severity": "warning"
  - "name": "system-capacity-alert.rules"
    "rules":
    - "alert": "NooBaaSystemCapacityWarning85"
      "annotations":
        "description": "A NooBaa system is approaching its capacity, usage is   more than 85%"
        "message": "A NooBaa System Is Approaching Its Capacity"
        "severity_level": "warning"
        "storage_type": "NooBaa"
      "expr": |
        NooBaa_system_capacity > 85
      "labels":
        "severity": "warning"
    - "alert": "NooBaaSystemCapacityWarning95"
      "annotations":
        "description": "A NooBaa system is approaching its capacity, usage is   more than 95%"
        "message": "A NooBaa System Is Approaching Its Capacity"
        "severity_level": "warning"
        "storage_type": "NooBaa"
      "expr": |
        NooBaa_system_capacity > 95
      "labels":
        "severity": "warning"
    - "alert": "NooBaaSystemCapacityWarning100"
      "annotations":
        "description": "A NooBaa system approached its capacity, usage is at 100%"
        "message": "A NooBaa System Approached Its Capacity"
        "severity_level": "warning"
        "storage_type": "NooBaa"
      "expr": |
        NooBaa_system_capacity == 100
      "labels":
        "severity": "warning"
EOF

cat <<EOF | oc create -f -
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: noobaa-metrics
  namespace: ${NAMESPACE}
rules:
 - apiGroups:
   - ""
   resources:
    - services
    - endpoints
    - pods
   verbs:
    - get
    - list
    - watch
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: noobaa-metrics
  namespace: ${NAMESPACE}
rules:
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: noobaa-metrics
subjects:
- kind: ServiceAccount
  name: prometheus-k8s
  namespace: openshift-monitoring
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    app: noobaa
  name: noobaa-mgr
  namespace: ${NAMESPACE}
spec:
  namespaceSelector:
    matchNames:
      - ${NAMESPACE}
  endpoints:
    - interval: 30s
      port: mgmt
      path: /metrics
  selector:
    matchLabels:
      app: noobaa
EOF

oc label namespace ${NAMESPACE} "openshift.io/cluster-monitoring=true"

# Remove the loadbalancer type s3 service and create a proper one
# oc delete svc s3 -n ${NAMESPACE}
# The service is created automatically by the operator...

cat << EOF | oc create -f -
apiVersion: v1
kind: Service
metadata:
  labels:
    app: noobaa
  name: s3-external
  namespace: ${NAMESPACE}
spec:
  ports:
  - name: s3
    port: 80
    protocol: TCP
    targetPort: 6001
  - name: s3-https
    port: 443
    protocol: TCP
    targetPort: 6443
  selector:
    noobaa-s3: noobaa
EOF

oc expose svc s3-external -n ${NAMESPACE}

ACCESSKEY=$(oc get secret noobaa-admin -n ${NAMESPACE} -o yaml | awk '/AWS_ACCESS_KEY_ID/ {print $2}' | base64 --decode)
SECRETKEY=$(oc get secret noobaa-admin -n ${NAMESPACE} -o yaml | awk '/AWS_SECRET_ACCESS_KEY/ {print $2}' | base64 --decode)
S3URL=$(oc get route s3-external -o jsonpath='{.status.ingress[*].host}' -n ${NAMESPACE})

echo "Object storage ready, use the following:"
echo "export AWS_HOST=${S3URL}"
echo "export AWS_ACCESS_KEY=${ACCESSKEY}"
echo "export AWS_SECRET_ACCESS_KEY=${SECRETKEY}"
