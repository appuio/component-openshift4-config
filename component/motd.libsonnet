local com = import 'lib/commodore.libjsonnet';
local esp = import 'lib/espejote.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.openshift4_config;

local namespace = {
  metadata+: {
    namespace: 'openshift-config',
  },
};

local motdRBAC =
  local motd_sa = kube.ServiceAccount('motd-manager') + namespace;
  local cluster_role = kube.ClusterRole('appuio:motd-editor') {
    rules: [
      {
        apiGroups: [ 'console.openshift.io' ],
        resources: [ 'consolenotifications' ],
        verbs: [ 'get', 'list', 'watch' ],
      },
      {
        apiGroups: [ 'espejote.io' ],
        resources: [ 'jsonnetlibraries' ],
        resourceNames: [ 'motd' ],
        verbs: [ 'get', 'list', 'watch' ],
      },
    ],
  };
  local cluster_role_binding =
    kube.ClusterRoleBinding('appuio:motd-manager') {
      subjects_: [ motd_sa ],
      roleRef_: cluster_role,
    };
  local role_binding = kube.RoleBinding('appuio:motd-manager') {
    metadata+: {
      namespace: 'openshift',
    },
    subjects_: [ motd_sa ],
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: 'edit',
    },
  };
  {
    motd_sa: motd_sa,
    cluster_role: cluster_role,
    cluster_role_binding: cluster_role_binding,
    role_binding: role_binding,
  };

local jsonnetlib =
  esp.jsonnetLibrary('motd', 'openshift-config') {
    spec: {
      data: {
        'config.json': std.manifestJson({
          motd: params.motd,
        }),
      },
    },
  };

local jsonnetlib_ref = {
  apiVersion: jsonnetlib.apiVersion,
  kind: jsonnetlib.kind,
  name: jsonnetlib.metadata.name,
  namespace: jsonnetlib.metadata.namespace,
};

local managedresource =
  esp.managedResource('motd-composer', 'openshift-config') {
    metadata+: {
      annotations: {
        'syn.tools/description': |||
          Composes the message of the day from manual entries in the syn hierarchy and active consolenotifications on the cluster.
        |||,
      },
    },
    spec: {
      serviceAccountRef: { name: motdRBAC.motd_sa.metadata.name },
      applyOptions: { force: true },
      context: [
        {
          name: 'consolenotifications',
          resource: {
            apiVersion: 'console.openshift.io/v1',
            kind: 'ConsoleNotification',
            labelSelector: {
              matchLabels: {
                'appuio.io/notification': 'true',
              },
            },
          },
        },
      ],
      triggers: [
        {
          name: 'consolenotifications',
          watchContextResource: {
            name: 'consolenotifications',
          },
        },
        {
          name: 'jsonnetlib',
          watchResource: jsonnetlib_ref,
        },
      ],
      template: importstr 'espejote-templates/motd.jsonnet',
    },
  };

if std.length(params.motd.messages) > 0 || params.motd.include_console_notifications then
  [ managedresource, jsonnetlib ] + std.objectValues(motdRBAC)
else
  []
