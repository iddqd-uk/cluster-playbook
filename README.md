<div align="center">
<img src="https://hsto.org/webt/zj/06/rh/zj06rhrcow4fallwh7bxki1-aw4.png" width="200"/>

# `iddqd.uk` ansible playbook

[![Release version][badge_release_version]][link_releases]
[![Build Status][badge_build]][link_actions]
[![License][badge_license]][link_license]
</div>

## 📖 Overview

This repository contains [Ansible][ansible] playbook for installing and configuring the Nomad cluster for the `iddqd.uk`. Where possible, it is automated with bots and GitHub actions.

## 📁 Directories & files

This Git repository contains the following directories & files:

```text
📁 inventory          # hosts definitions (IP addresses) and variables
├─📁 local            # local environment (eg. for the local testing)
└─📁 prod             # production environment
📁 roles              # ansible roles, config files, etc
├─📁 ...
└─📁 ...
📄 site.yml           # playbook
📄 docker-compose.yml # for using docker as a local environment
📄 Makefile           # development sugar
```

## Requirements

- Successfully tested on Debian 11 (amd64)

## Running

Please, follow the next checklist:

- [ ] Make a file `./.vault_password` with the [vault password][ansible_vault]
- [ ] Check the inventory file (for required environment - `local|production`)

After the checklist passing, you can run the playbook:

```shell
$ ansible-playbook ./site.yml -i ./inventory/local # for local
$ ansible-playbook ./site.yml -i ./inventory/prod  # for production
```

### Secrets

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
$ ansible localhost -m ansible.builtin.debug -a var="some.secret_key" -e "@inventory/prod/group_vars/all.yml"
localhost | SUCCESS => {
    "changed": false,
    "nomad.secret_key": "your secret value"
}
```

[badge_release_version]:https://img.shields.io/github/release/iddqd-uk/cluster-playbook.svg?maxAge=30
[badge_build]:https://img.shields.io/github/workflow/status/iddqd-uk/cluster-playbook/tests/master
[badge_license]:https://img.shields.io/github/license/iddqd-uk/cluster-playbook.svg?longCache=true

[link_releases]:https://github.com/iddqd-uk/cluster-playbook/releases
[link_actions]:https://github.com/iddqd-uk/cluster-playbook/actions
[link_license]:https://github.com/iddqd-uk/cluster-playbook/blob/master/LICENSE

[ansible]:https://www.ansible.com/
[ansible_vault]:https://docs.ansible.com/ansible/latest/user_guide/vault.html
