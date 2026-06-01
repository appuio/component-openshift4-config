local esp = import 'espejote.libsonnet';

local source = esp.context().source;
assert
  std.length(source) == 1
  : 'Expected source context to have exactly 1 element';
assert
  source[0].kind == 'Secret'
  : 'Expected source to be a `Secret`, is a `%s`' % source[0].kind;

{
  apiVersion: 'v1',
  kind: 'Secret',
  metadata: {
    name: 'vsphere-creds',
    namespace: 'kube-system',
    annotations: {
      'espejote.io/managed-by': 'openshift-config/vsphere-credentials',
    },
  },
  data: source[0].data,
}
