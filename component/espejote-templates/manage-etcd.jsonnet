local esp = import 'espejote.libsonnet';

local etcd = import 'appuio-etcd/etcd.libsonnet';
local spec = import 'appuio-etcd/spec.json';

etcd.Etcd {
  spec: spec,
}
