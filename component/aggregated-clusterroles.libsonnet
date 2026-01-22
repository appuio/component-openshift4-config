local kube = import 'lib/kube.libjsonnet';

local operator_openshift_io_cluster_reader =
  kube.ClusterRole('syn:aggregate-operator-openshift-io-to-cluster-reader') {
    metadata+: {
      labels+: {
        'rbac.authorization.k8s.io/aggregate-to-cluster-reader': 'true',
      },
    },
    rules: [
      {
        apiGroups: [
          'operator.openshift.io',
        ],
        resources: [
          '*',
        ],
        verbs: [
          'get',
          'list',
          'watch',
        ],
      },
    ],
  };

// needed in OCP 4.20 for ipaddresses.networking.k8s.io
local networking_k8s_io_cluster_reader =
  kube.ClusterRole('syn:aggregate-networking-k8s-io-to-cluster-reader') {
    metadata+: {
      labels+: {
        'rbac.authorization.k8s.io/aggregate-to-cluster-reader': 'true',
      },
    },
    rules: [
      {
        apiGroups: [
          'networking.k8s.io',
        ],
        resources: [
          '*',
        ],
        verbs: [
          'get',
          'list',
          'watch',
        ],
      },
    ],
  };

[
  operator_openshift_io_cluster_reader,
  networking_k8s_io_cluster_reader,
]
