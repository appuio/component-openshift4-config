local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.openshift4_config;

local esp = import 'lib/espejote.libsonnet';

local namespace = 'openshift-config';

local sa = kube.ServiceAccount('appuio-etcd-manager') {
  metadata+: {
    namespace: namespace,
  },
};

local etcd = import 'espejote-templates/etcd-helpers.libsonnet';

local clusterrole = kube.ClusterRole('appuio:openshift4-config:etcd-manager') {
  rules: [
    {
      apiGroups: [ etcd.apiGroup ],
      resources: [ etcd.resource ],
      resourceNames: [ etcd.resourceName ],
      verbs: [ 'get', 'list', 'watch', 'patch' ],
    },
  ],
};

local clusterrolebinding =
  kube.ClusterRoleBinding('appuio:openshift4-config:etcd-manager') {
    roleRef_: clusterrole,
    subjects_: [ sa ],
  };

local jl = esp.jsonnetLibrary('appuio-etcd', namespace) {
  metadata+: {
    namespace: 'openshift-config',
  },
  spec: {
    data: {
      'spec.json': std.manifestJson(params.etcd.spec),
      'etcd.libsonnet': importstr 'espejote-templates/etcd-helpers.libsonnet',
    },
  },
};

local mr = esp.managedResource('appuio-etcd', namespace) {
  spec: {
    // Set force=true so we can take ownership of previously manually edited
    // fields in `spec`.
    applyOptions: { force: true },
    serviceAccountRef: { name: sa.metadata.name },
    triggers: [
      {
        name: 'etcd',
        watchResource: {
          apiVersion: etcd.apiVersion,
          kind: etcd.kind,
          name: etcd.resourceName,
        },
      },
    ],
    template: importstr 'espejote-templates/manage-etcd.jsonnet',
  },
};

[ sa, clusterrole, clusterrolebinding, jl, mr ]
