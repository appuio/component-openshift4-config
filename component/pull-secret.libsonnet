local kube = import 'kube-ssa-compat.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';

local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_config;

local esp = import 'lib/espejote.libsonnet';

local namespace = 'openshift-config';
local name = 'appuio-pull-secret';

local sa = kube.ServiceAccount('%s-manager' % name) {
  metadata+: {
    namespace: namespace,
  },
};

local role = kube.Role('appuio:openshift4-config:pull-secret-manager') {
  metadata+: {
    namespace: namespace,
  },
  rules: [
    {
      apiGroups: [ '' ],
      resources: [ 'secrets' ],
      resourceNames: [ 'pull-secret' ],
      verbs: [ 'get', 'list', 'watch', 'patch' ],
    },
    {
      // RBAC can't restrict reads by label, so the manager can read all
      // secrets in the namespace.
      apiGroups: [ '' ],
      resources: [ 'secrets' ],
      verbs: [ 'get', 'list', 'watch' ],
    },
    {
      apiGroups: [ 'espejote.io' ],
      resources: [ 'jsonnetlibraries' ],
      resourceNames: [ name ],
      verbs: [ 'get', 'list', 'watch' ],
    },
  ],
};

local rolebinding =
  kube.RoleBinding('appuio:openshift4-config:pull-secret-manager') {
    metadata+: {
      namespace: namespace,
    },
    roleRef_: role,
    subjects_: [ sa ],
  };

local jl = esp.jsonnetLibrary(name, namespace) {
  metadata+: {
    namespace: 'openshift-config',
  },
  spec: {
    data: {
      'spec.json': std.manifestJson({
        pullSecrets:
          params.globalPullSecrets + params.pullSecretCustomization.auths,
      }),
    },
  },
};

local mr = esp.managedResource(name, namespace) {
  metadata+: {
    annotations+: {
      'syn.tools/description': |||
        Merges the `auths` entries of every secret in namespace openshift-config
        with the include label into the cluster's global pull secret.
        Entries which aren't contributed by a labelled secret are left
        untouched.
      |||,
    },
  },
  spec: {
    // Set force=true so we can take ownership of the `.dockerconfigjson` field
    // from whoever wrote it before.
    applyOptions: { force: true },
    serviceAccountRef: { name: sa.metadata.name },
    context: [
      {
        name: 'global_pull_secret',
        resource: {
          apiVersion: 'v1',
          kind: 'Secret',
          namespace: namespace,
          name: 'pull-secret',
        },
      },
      {
        name: 'source_secrets',
        resource: {
          apiVersion: 'v1',
          kind: 'Secret',
          namespace: namespace,
          labelSelector: {
            matchLabels: {
              [params.pullSecretCustomization.label]: '',
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
      // We watch the resource we're applying to, so that manual edits are
      // reverted. This doesn't loop: the template feeds the current contents
      // of the secret back into its own output, so a second render produces a
      // byte-identical result and the server-side apply is a no-op which
      // doesn't emit another watch event.
      {
        name: 'global_pull_secret',
        watchContextResource: {
          name: 'global_pull_secret',
        },
      },
      {
        name: 'source_secrets',
        watchContextResource: {
          name: 'source_secrets',
        },
      },
    ],
    template: importstr 'espejote-templates/manage-pull-secret.jsonnet',
  },
};

[ sa, role, rolebinding, jl, mr ]
