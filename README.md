<div align="center">
<img src="https://hsto.org/webt/zj/06/rh/zj06rhrcow4fallwh7bxki1-aw4.png" width="200"/>

# `iddqd.uk` ansible playbook

[![Release version][badge_release_version]][link_releases]
[![Build Status][badge_build]][link_actions]
[![License][badge_license]][link_license]
</div>

## 📖 Overview

This repository contains an [Ansible][ansible] playbook for installing and configuring the dead simple Nomad cluster for the `iddqd.uk` resources and applications. Where possible, working is automated with bots and GitHub actions.

The core of the cluster consists of the following applications:

- [Consul][consul] (service-discovery and distributed key-value storage)
- [Nomad][nomad] (simple and flexible scheduler and orchestrator)
- [Docker][docker] (each run application deployed as a docker container)

In addition, I decided to use the following applications:

- [Gluster][gluster] (persistent data across each node in the cluster, e.g. for the Nomad containers)

Since this is a simple cluster (minimal nodes count is 2), Nomad, Consul and Gluster are used as a server and client on each machine simultaneously. Load balancing, logs aggregation, monitoring, alerting, and other services are not included - to keep this playbook simple I prefer to install them separately (as a services in docker containers).

## 🗒 Requirements

- 2 (or more) machines
- 2 network interfaces on each machine - public and private
- Successfully tested on Debian 11 (amd64)

## 🚀 Running

Please, follow the next checklist:

- [x] Make a file `./.vault_password` with the [vault password][ansible_vault]
- [x] Install playbook requirements - `ansible-galaxy install -r ./requirements.yml`
- [x] Check (or create new) the inventory file (for required environment - `local|production`)

After the checklist passing, you can run the playbook:

```shell
$ ansible-playbook ./site.yml -i ./inventory/local # for local
$ ansible-playbook ./site.yml -i ./inventory/prod  # for production
```

> :warning: Some services bind on all interfaces (`0.0.0.0`), so you should protect them with firewall rules, or use an external firewall!

### 😎 Secrets

For a making encrypted value in the playbook, you can use the following command (file with the vault password `./.vault_password` should exist):

```shell
$ ansible-vault encrypt_string 'your secret value' --name 'the_secret'

the_secret: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          65666362303663356230373118643061636136336431623634633237393132663661663531643266
          3066643164333730303933663737386139326463646661640a666534306235373236303464396436
          34346139666164643934393763373765396134656230626639623164373237616462313431376266
          3934303232303432380a663736323636626134323364303336363566353532313539316436343461
          66383365396138356666353832363030363361613537316235363638646639316663
Encryption successful
```

And otherwise, for the secret reading you can:

```shell
$ ansible localhost -m ansible.builtin.debug -a var="some.the_secret" -e "@inventory/prod/group_vars/all.yml"
localhost | SUCCESS => {
    "changed": false,
    "nomad.secret_key": "your secret value"
}
```

### 🔐 Nomad ACL configuring

First, you should set the playbook variable `nomad_acl_enabled: true`. When playbook running is done, you need to connect using SSH on any server node, and execute:

```shell
$ nomad acl bootstrap
Accessor ID  = <accessor-id-goes-here>
Secret ID    = <secret-id-goes-here>
Name         = Bootstrap Token
Type         = management
Global       = true
...
```

Save this **Secret ID** somewhere (something like a KeePass usage is strongly recommended)!

> 🔥 Care should be taken not to lose all of your management tokens. If you do, you will need to [re-bootstrap the ACL subsystem](https://learn.hashicorp.com/tutorials/nomad/access-control-bootstrap?in=nomad/access-control#re-bootstrap-acl-system).

You can verify the token is working (execute on any node; correct `NOMAD_TOKEN` is needed for future operations anyway):

```shell
$ nomad status # should fails
Error querying jobs: Unexpected response code: 403 (Permission denied)

$ export NOMAD_TOKEN="<secret-id-goes-here>"

$ nomad status
No running jobs
```

It's time to deploy [ACL policies](roles/nomad/files/policies) for our cluster roles. First, we should create a namespace (named `apps`) for our future deployments:

```shell
$ nomad namespace apply -description "Cluster applications" apps

$ nomad namespace list
Name     Description
apps     Cluster applications
default  Default shared namespace # <-- new namespace
```

And after that:

```shell
# for the cluster management (using UI, for example)
$ nomad acl policy apply -description "Operators policy" devops /etc/nomad.d/policies/devops.policy.hcl
Successfully wrote "devops" ACL policy!

# for applications deployments (using CI and scripts)
$ nomad acl policy apply -description "Apps deployment policy" deploy /etc/nomad.d/policies/deploy.policy.hcl
Successfully wrote "deploy" ACL policy!

$ nomad acl policy list
Name    Description
deploy  Apps deployment policy
devops  Operators policy
```

> 🔥 On any policies update, you should re-execute those commands **manually**!

Let's [generate tokens](https://learn.hashicorp.com/tutorials/nomad/access-control-tokens?in=nomad/access-control#generate-a-client-token) for the cluster management:

```shell
$ nomad acl token create -name="Devops" -policy="devops"
Accessor ID  = <accessor-id-goes-here>
Secret ID    = <devops-secret-id-goes-here> # <-- save this somewhere
Policies     = [devops]
...

$ nomad acl token create -name="Deploy" -policy="deploy"
Accessor ID  = <accessor-id-goes-here>
Secret ID    = <deploy-secret-id-goes-here> # <-- save this somewhere
Policies     = [deploy]
...
```

You should generate a new token for each DevOps or **cluster manager** (do not share them between people; the generated token can be revoked at any time). The **first** token should be used for **cluster management** (it allows to auth in the Nomad dashboard), and the **second** - for apps **deploying only**.

## Pretty cool links

- [Why you should take a look at Nomad before jumping on Kubernetes](https://atodorov.me/2021/02/27/why-you-should-take-a-look-at-nomad-before-jumping-on-kubernetes/)

[badge_release_version]:https://img.shields.io/github/release/iddqd-uk/cluster-playbook.svg?maxAge=30
[badge_build]:https://img.shields.io/github/workflow/status/iddqd-uk/cluster-playbook/tests/master
[badge_license]:https://img.shields.io/github/license/iddqd-uk/cluster-playbook.svg?longCache=true

[link_releases]:https://github.com/iddqd-uk/cluster-playbook/releases
[link_actions]:https://github.com/iddqd-uk/cluster-playbook/actions
[link_license]:https://github.com/iddqd-uk/cluster-playbook/blob/master/LICENSE

[consul]:https://www.consul.io/
[nomad]:https://www.nomadproject.io/
[docker]:https://www.docker.com/
[gluster]:https://www.gluster.org/
[ansible]:https://www.ansible.com/
[ansible_vault]:https://docs.ansible.com/ansible/latest/user_guide/vault.html
