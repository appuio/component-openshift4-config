// main template for openshift4-config
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_config;

local legacyPullSecret = std.get(params, 'globalPullSecret', null);

local dockercfg = std.trace(
  'Your config for openshift4-config uses the deprecated `globalPullSecret` parameter. '
  + 'Please migrate to `globalPullSecrets`. '
  + 'See https://hub.syn.tools/openshift4-config/how-to/migrate-v1.html for details.',
  kube.Secret('pull-secret') {
    metadata+: {
      namespace: 'openshift-config',
      annotations+: {
        'argocd.argoproj.io/sync-options': 'Prune=false',
      },
    },
    stringData+: {
      '.dockerconfigjson': legacyPullSecret,
    },
    type: 'kubernetes.io/dockerconfigjson',
  }
);

local motd = import 'motd.libsonnet';

local caBundle = {
  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    name: 'syn-ca-bundle',
    namespace: 'openshift-config',
    annotations: {
      'syn.tools/description': |||
        This is a config map that's deployed via Commodore component
        openshift4-config and which is intended to be consumed by other
        Commodore components.

        OpenShift uses a separate config map called `user-ca-bundle` in this
        namespace to extend the system wide trusted CA bundle. See parameter
        `trustedCA` in Commodore component `openshift4-proxy` to configure
        that config map.
      |||,
    },
  },
  data: {
    'ca-bundle.crt': params.caBundle,
  },
};


// Define outputs below
{
  [if legacyPullSecret != null then '01_dockercfg']: dockercfg,
  [if legacyPullSecret == null && std.length(std.objectFields(params.globalPullSecrets)) > 0 then '99_cluster_pull_secret']:
    import 'pull-secret-sync-job.libsonnet',
  [if std.length(motd) > 0 then '03_motd']: motd,
  [if params.etcdCustomization.enabled then '05_etcd_managedresource']: import 'etcd.libsonnet',
  '10_aggregate_to_cluster_reader': import 'aggregated-clusterroles.libsonnet',
  [if params.caBundle != null then '11_ca_bundle']: caBundle,
}
