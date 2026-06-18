local configApiGroup = 'config.openshift.io';
local configApiVersion = '%s/v1' % configApiGroup;
local operatorApiGroup = 'operator.openshift.io';
local operatorApiVersion = '%s/v1' % operatorApiGroup;
local kind = 'Network';
local resource = 'networks';
local resourceName = 'cluster';

local config = {
  apiVersion: configApiVersion,
  kind: kind,
  metadata: {
    name: resourceName,
  },
};

local operator = {
  apiVersion: operatorApiVersion,
  kind: kind,
  metadata: {
    name: resourceName,
  },
};

{
  configApiGroup: configApiGroup,
  configApiVersion: configApiVersion,
  operatorApiGroup: operatorApiGroup,
  operatorApiVersion: operatorApiVersion,
  kind: kind,
  resource: resource,
  resourceName: resourceName,
  Config: config,
  Operator: operator,
}
