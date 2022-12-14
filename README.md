<div align="center">
<img src="https://hsto.org/webt/zj/06/rh/zj06rhrcow4fallwh7bxki1-aw4.png" width="200"/>

# `iddqd.uk` infrastructure playbook

[![Tests Status][badge_tests]][link_actions]
[![Deploy Status][badge_deploy]][link_deploy]
</div>

## 📖 Overview

This repository contains an [Ansible][ansible] playbook for installing and configuring the dead simple Nomad cluster for the `iddqd.uk` resources and applications. Where possible, working is automated with bots and GitHub actions.

The core of the cluster consists of the following applications:

- [Consul][consul] (service-discovery and distributed key-value storage)
- [Nomad][nomad] (simple and flexible scheduler and orchestrator)
- [Docker][docker] (each run application deployed as a docker container)
- [Traefik][traefik] (ingress service with automatic SSL certs)

In addition, I decided to use the following applications:

- [Gluster][gluster] (persistent data across each node in the cluster, e.g. for the Nomad containers)

> Why not k8s? Because k8s (k3s, Minikube) have a large footprint, and my servers haven't too many resources.

Since this is a simple cluster (minimal nodes count is 2), Nomad, Consul and Gluster are used as a server and client on each machine simultaneously. Load balancing, logs aggregation, monitoring, alerting, and other services are not included - to keep this playbook simple I prefer to install them separately (as a services in docker containers).

Traefik is installed on one node (without replication), so it is not an HA solution, but scalable for the backend services (you can deploy it on as many nodes as you need).

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

> :warning: Some services bind on all interfaces (`0.0.0.0`), so you should protect them with firewall rules, or use an external firewall.
>
> Ideally, the private network should **not** have any restrictions. For a public network all ports must be closed from the outside, except for the following:
> - `<22>` (SSH, playbook variable `ansible_port`, on **each** node)
> - `80` (HTTP, Node with Traefik **only**)
> - `443` (HTTP + TLS, Node with Traefik **only**)

### ⁉ How to...

<details>
<summary><strong>😎 ...manage playbook secrets?</strong></summary>

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
</details>

<details>
<summary><strong>🔐 ...set up Nomad ACL?</strong></summary>

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
</details>

<details>
<summary><strong>🌎 ...issue CloudFlare token for Let's encrypt working?</strong></summary>

Open CloudFlare [API Tokens](https://dash.cloudflare.com/profile/api-tokens) page, and press the `Create Token` button:

![create-token](https://user-images.githubusercontent.com/7326800/183305370-1a406b06-29ef-4fc0-9407-d7430d33cade.png)

Use "Edit zone DNS" template:

![use-template](https://user-images.githubusercontent.com/7326800/183305432-3d703c25-7e29-4cec-b23c-55d4c53db3f9.png)

Optionally set IP address filtering (IPv4 and **IPv6** too - this may be important) and a token TTL:

![token-details](https://user-images.githubusercontent.com/7326800/183305505-635f5904-e220-4afb-ab7f-5b6369d5761d.png)

Save your token somewhere, and set it in the playbook variable `cloudflare_zone_api_key`. Also do not forget to set the `cloudflare_api_email` variable with your CloudFlare account email.

That's all, all should work fine after that.

> Don't forget to set `traefik_acme_lets_encrypt_staging` variable to `false` for the production.

</details>

### 🕸 Pretty cool links

- [Why you should take a look at Nomad before jumping on Kubernetes](https://atodorov.me/2021/02/27/why-you-should-take-a-look-at-nomad-before-jumping-on-kubernetes/)

[badge_tests]:https://img.shields.io/github/actions/workflow/status/iddqd-uk/cluster-playbook/tests.yml?branch=main&style=for-the-badge&logo=github&logoColor=white&label=tests
[badge_deploy]:https://img.shields.io/github/actions/workflow/status/iddqd-uk/cluster-playbook/deploy.yml?style=for-the-badge&logo=github&logoColor=white&label=deploy

[link_actions]:https://github.com/iddqd-uk/cluster-playbook/actions
[link_deploy]:https://github.com/iddqd-uk/cluster-playbook/actions/workflows/deploy.yml

[consul]:https://www.consul.io/
[nomad]:https://www.nomadproject.io/
[docker]:https://www.docker.com/
[traefik]:https://traefik.io/traefik/
[gluster]:https://www.gluster.org/
[ansible]:https://www.ansible.com/
[ansible_vault]:https://docs.ansible.com/ansible/latest/user_guide/vault.html
