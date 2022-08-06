# namespace docs: <https://learn.hashicorp.com/tutorials/nomad/namespaces>
namespace "default" {
  policy = "read"
}

namespace "apps" {
  policy = "write"
}

# rule docs:  https://learn.hashicorp.com/tutorials/nomad/access-control-policies

# controls access to the Node API such as listing nodes or triggering a node drain
node {
  policy = "write"
}

# controls access to the utility operations in the Agent API, such as join and leave
agent {
  policy = "write"
}

# controls access to the Operator API (interacting with the Raft subsystem, licensing,
# snapshots, autopilot and scheduler configuration)
operator {
  policy = "write"
}

# controls access to the quota specification operations in the Quota API, such as quota
# creation and deletion
quota {
  policy = "write"
}

# controls access to mounting and accessing host volumes
host_volume "*" {
  policy = "write"
}

# controls access to CSI plugins, such as listing plugins or getting plugin status
plugin {
  policy = "list"
}
