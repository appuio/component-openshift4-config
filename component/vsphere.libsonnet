local kube = import 'kube-ssa-compat.libsonnet';
local esp = import 'lib/espejote.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.openshift4_config;

local name = 'vsphere-credentials-manager';


local sa = kube.ServiceAccount(name) {
  metadata+: {
    namespace: 'openshift-config',
  },
};

local role = kube.Role(name) {
  metadata+: {
    namespace: 'kube-system',
  },
  rules: [ {
    apiGroups: [ '' ],
    resources: [ 'secrets' ],
    resourceNames: [ 'vsphere-creds' ],
    verbs: [ 'get', 'list', 'watch', 'update', 'patch' ],
  } ],
};

local rolebinding = kube.RoleBinding(name) {
  metadata+: {
    namespace: 'kube-system',
  },
  roleRef_: role,
  subjects_: [ sa ],
};

local secret =
  local vsphereConfig = params.vsphere;
  assert
    vsphereConfig.vcenterURL != null
    : '`params.vsphere.vcenterURL` must be set when `params.cloud==vsphere`';
  assert
    vsphereConfig.username != null
    : '`params.vsphere.username` must be set when `params.cloud==vsphere`';
  assert
    vsphereConfig.password != null
    : '`params.vsphere.password` must be set when `params.cloud==vsphere`';
  kube.Secret('appuio-vsphere-creds') {
    metadata+: {
      namespace: 'openshift-config',
    },
    stringData: {
      ['%s.username' % vsphereConfig.vcenterURL]: vsphereConfig.username,
      ['%s.password' % vsphereConfig.vcenterURL]: vsphereConfig.password,
    },
  };

local credentialsMr =
  esp.managedResource('vsphere-credentials', 'openshift-config') {
    spec+: {
      applyOptions: {
        force: true,
      },
      serviceAccountRef: {
        name: sa.metadata.name,
      },
      context: [
        {
          name: 'source',
          resource: {
            apiVersion: secret.apiVersion,
            kind: secret.kind,
            namespace: secret.metadata.namespace,
            name: secret.metadata.name,
          },
        },
      ],
      triggers: [
        {
          name: 'vsphere-creds',
          watchResource: {
            apiVersion: 'v1',
            name: 'vsphere-creds',
            kind: 'Secret',
            namespace: 'kube-system',
          },
        },
        {
          name: 'source',
          watchContextResource: {
            name: 'source',
          },
        },
      ],
      template: importstr 'espejote-templates/vsphere-creds.jsonnet',
    },
  };

{
  credentials: [ credentialsMr, secret, sa, role, rolebinding ],
}
