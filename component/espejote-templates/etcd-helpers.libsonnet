local apiGroup = 'operator.openshift.io';
local apiVersion = '%s/v1' % apiGroup;
local kind = 'Etcd';
local resource = 'etcds';
local resourceName = 'cluster';

local etcd = {
  apiVersion: apiVersion,
  kind: kind,
  metadata: {
    name: resourceName,
  },
};

{
  apiGroup: apiGroup,
  apiVersion: apiVersion,
  kind: kind,
  resource: resource,
  resourceName: resourceName,
  Etcd: etcd,
}
