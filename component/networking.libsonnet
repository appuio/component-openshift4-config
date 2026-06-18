local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.openshift4_config;

local esp = import 'lib/espejote.libsonnet';

local namespace = 'openshift-config';

local sa = kube.ServiceAccount('appuio-networking-manager') {
  metadata+: {
    namespace: namespace,
  },
};

local networking = import 'espejote-templates/networking-helpers.libsonnet';

local clusterrole = kube.ClusterRole('appuio:openshift4-config:networking-manager') {
  rules: [
    {
      apiGroups: [ networking.operatorApiGroup ],
      resources: [ networking.resource ],
      resourceNames: [ networking.resourceName ],
      verbs: [ 'get', 'list', 'watch', 'patch' ],
    },
    {
      apiGroups: [ networking.configApiGroup ],
      resources: [ networking.resource ],
      resourceNames: [ networking.resourceName ],
      verbs: [ 'get', 'list', 'watch', 'patch' ],
    },
  ],
};

local clusterrolebinding =
  kube.ClusterRoleBinding('appuio:openshift4-config:networking-manager') {
    roleRef_: clusterrole,
    subjects_: [ sa ],
  };

local role = kube.Role('appuio:openshift4-config:networking-manager') {
  metadata+: {
    namespace: namespace,
  },
  rules: [
    {
      apiGroups: [ '' ],
      resources: [ 'configmaps' ],
      verbs: [ 'get', 'list', 'watch' ],
    },
    {
      apiGroups: [ 'espejote.io' ],
      resources: [ 'jsonnetlibraries' ],
      resourceNames: [ 'appuio-networking' ],
      verbs: [ 'get', 'list', 'watch' ],
    },
  ],
};

local rolebinding =
  kube.RoleBinding('appuio:openshift4-config:networking-manager') {
    metadata+: {
      namespace: namespace,
    },
    roleRef_: role,
    subjects_: [ sa ],
  };

local jl = esp.jsonnetLibrary('appuio-networking', namespace) {
  metadata+: {
    namespace: 'openshift-config',
  },
  spec: {
    data: {
      'spec.json': std.manifestJson({
        config: params.networkCustomization.specConfig,
        operator: params.networkCustomization.specOperator,
      }),
      'networking.libsonnet': importstr 'espejote-templates/networking-helpers.libsonnet',
    },
  },
};

local mr = esp.managedResource('appuio-networking', namespace) {
  spec: {
    // Set force=true so we can take ownership of previously manually edited
    // fields in `spec`.
    applyOptions: { force: true },
    serviceAccountRef: { name: sa.metadata.name },
    context: [
      {
        name: 'configmaps_config',
        resource: {
          apiVersion: 'v1',
          kind: 'ConfigMap',
          labelSelector: {
            matchLabels: {
              [params.networkCustomization.labelConfig]: '',
            },
          },
        },
      },
      {
        name: 'configmaps_operator',
        resource: {
          apiVersion: 'v1',
          kind: 'ConfigMap',
          labelSelector: {
            matchLabels: {
              [params.networkCustomization.labelOperator]: '',
            },
          },
        },
      },
    ],
    triggers: [
      {
        name: 'jsonnetlib',
        watchResource: {
          apiVersion: jl.apiVersion,
          kind: jl.kind,
          name: jl.metadata.name,
        },
      },
      {
        name: 'networking_config',
        watchResource: {
          apiVersion: networking.configApiVersion,
          kind: networking.kind,
          name: networking.resourceName,
        },
      },
      {
        name: 'networking_operator',
        watchResource: {
          apiVersion: networking.operatorApiVersion,
          kind: networking.kind,
          name: networking.resourceName,
        },
      },
      {
        name: 'configmap_config',
        watchContextResource: {
          name: 'configmaps_config',
        },
      },
      {
        name: 'configmap_operator',
        watchContextResource: {
          name: 'configmaps_operator',
        },
      },
    ],
    template: importstr 'espejote-templates/manage-networking.jsonnet',
  },
};

[ sa, clusterrole, clusterrolebinding, role, rolebinding, jl, mr ]
