local esp = import 'espejote.libsonnet';

local spec = import 'appuio-pull-secret/spec.json';

local global_pull_secret = std.parseJson(std.base64Decode(esp.context().global_pull_secret[0].data['.dockerconfigjson']));

// Secrets without a `.dockerconfigjson` field are ignored, so that a
// mislabelled secret doesn't break the reconciliation.
local dockerconfigSecrets(secrets) = std.filter(
  function(s) std.objectHas(std.get(s, 'data', {}), '.dockerconfigjson'),
  secrets
);

// Labelled secrets contributed by other components, merged in a stable order.
local sources = std.sort(
  dockerconfigSecrets(esp.context().source_secrets),
  function(s) s.metadata.name
);

local authsOf(secret) =
  std.get(std.parseJson(std.base64Decode(secret.data['.dockerconfigjson'])), 'auths', {});

local auths = std.foldl(
  function(a, b) a + b,
  // The entries from the hierarchy are merged last, so that the component
  // parameters take precedence over the labelled secrets.
  [ authsOf(s) for s in sources ] + [ spec.pullSecrets ],
  std.get(global_pull_secret, 'auths', {})
);

{
  apiVersion: 'v1',
  kind: 'Secret',
  metadata: {
    name: 'pull-secret',
    namespace: 'openshift-config',
    annotations: {
      'pull-secret.openshift-config.syn.tools/active-secrets':
        std.manifestJsonMinified([ s.metadata.name for s in sources ]),
    },
  },
  data: {
    '.dockerconfigjson': std.base64(std.manifestJsonMinified(global_pull_secret {
      // Entries with a `null` value are removed from the pull secret. Entries
      // which are present on the cluster but not contributed by any of the
      // merged secrets are kept as-is.
      auths: {
        [k]: std.prune(auths[k])
        for k in std.objectFields(auths)
        if auths[k] != null
      },
    })),
  },
}
