// main template for openshift4-config
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_config;

local dockercfg = kube.Secret('pull-secret') {
  metadata+: {
    namespace: 'openshift-config',
  },
  stringData+: {
    '.dockerconfigjson': params.globalPullSecret,
  },
};

// Define outputs below
{
  [if params.globalPullSecret != null then '01_dockercfg']: dockercfg,
}
