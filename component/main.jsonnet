// main template for openshift4-config
local kube = import 'kube-ssa-compat.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_config;

assert std.get(params, 'globalPullSecret', null) == null :
       'Parameter `globalPullSecret` has been removed. '
       + 'Please migrate your pull secret entries to `pullSecretCustomization.auths`. '
       + 'See https://hub.syn.tools/openshift4-config/how-to/migrate-v3.html for details.';

local pullSecret =
  local manifests = import 'pull-secret.libsonnet';
  if std.length(std.objectFields(params.globalPullSecrets)) > 0 then
    std.trace(
      'Parameter `globalPullSecrets` is an alias for `pullSecretCustomization.auths`. '
      + 'Consider moving your configuration to `pullSecretCustomization.auths`.',
      manifests
    )
  else
    manifests;


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

local vsphere = import 'vsphere.libsonnet';


// Define outputs below
{
  [if std.length(motd) > 0 then '03_motd']: motd,
  [if params.etcdCustomization.enabled then '05_etcd_managedresource']: import 'etcd.libsonnet',
  [if params.networkCustomization.enabled then '05_networking_managedresource']: import 'networking.libsonnet',
  [if params.pullSecretCustomization.enabled then '05_pull_secret_managedresource']: pullSecret,
  '10_aggregate_to_cluster_reader': import 'aggregated-clusterroles.libsonnet',
  [if params.caBundle != null then '11_ca_bundle']: caBundle,
} + if params.cloud == 'vsphere' then {
  ['20_vsphere_%s' % manifest]: vsphere[manifest]
  for manifest in std.objectFields(vsphere)
  if vsphere[manifest] != null
} else {}
