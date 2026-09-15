# ns8-calrs

[calrs](https://cal.rs/) packaged for [NethServer 8](https://github.com/NethServer/ns8-core).

calrs is a self-hosted scheduling platform written in Rust: publish your
availability, share a booking link, and let people pick a slot. Free/busy is
computed from your own CalDAV calendars (Nextcloud, SOGo, Fastmail, iCloud...)
and confirmed bookings are written back to them.

The module runs a single container in a pod, stores everything in a SQLite
database inside the `calrs-data` volume, and exposes the application through
Traefik.

## Install

Instantiate the module with:

    add-module ghcr.io/stephdl/calrs:latest 1

The output of the command returns the instance name, for example:

    {"module_id": "calrs1", "image_name": "calrs", "image_url": "ghcr.io/stephdl/calrs:latest"}

## Configure

Let's assume the instance is named `calrs1`.

Launch `configure-module` with the following parameters:

- `host`: fully qualified domain name of the application (required)
- `http2https`: enable or disable HTTP to HTTPS redirection (true/false)
- `lets_encrypt`: request a Let's Encrypt certificate (true/false)
- `mail_from`: sender address of booking messages, defaults to `noreply@<host>`
- `allow_private_hosts`: host names allowed to bypass the calrs private address
  check, needed to reach a CalDAV server on a private address
- `admin_email`, `admin_name`, `admin_password`: first administrator account,
  the password must be at least 12 characters

Example:

```
api-cli run configure-module --agent module/calrs1 --data - <<EOF
{
  "host": "calrs.domain.com",
  "http2https": true,
  "lets_encrypt": false,
  "mail_from": "calrs@domain.com",
  "allow_private_hosts": ["nextcloud.domain.com"],
  "admin_email": "admin@domain.com",
  "admin_name": "Administrator",
  "admin_password": "Nethesis,1234"
}
EOF
```

The above command will:

- configure a virtual host in Traefik to reach the instance
- create the administrator account and close open registration
- start the calrs pod

### Administrator account

calrs grants the administrator role to the first account that registers. The
module closes that window: when `admin_email` and `admin_password` are given,
the account is created before the service starts and registration is disabled.
The step is skipped when an account already exists, so an existing installation
is never touched. The password is used once and never stored in the module
environment.

Further accounts are managed from the calrs admin dashboard, or with the CLI:

    runagent -m calrs1 podman run --rm -it --volume calrs-data:/var/lib/calrs:z ${CALRS_IMAGE} user list

## Get the configuration

```
api-cli run get-configuration --agent module/calrs1
```

## Uninstall

To uninstall the instance:

    remove-module --no-preserve calrs1

## Mail

SMTP settings are not part of `configure-module`: they come from the
centralized [smarthost setup](https://nethserver.github.io/ns8-core/core/smarthost/).
At every container start `bin/discover-smarthost` writes the `CALRS_SMTP_*`
block to `state/discovery.env`, and the event handler
`events/smarthost-changed/10reload_services` restarts the pod when the cluster
smarthost changes.

That environment block takes precedence over the calrs database, so the SMTP
form of the admin dashboard shows the values as read-only. Without a configured
smarthost, no block is written and the SMTP settings stay editable in calrs.

## Backup and restore

`bin/module-dump-state` takes a consistent snapshot of the live SQLite database
with the online backup API, and writes it to `state/calrs-backup.db`. The
`calrs-data` volume is backed up too: it carries `secret.key`, without which the
stored CalDAV and SMTP credentials cannot be decrypted.

On restore, `actions/restore-module/40restore_database` puts the snapshot back
in place of `calrs.db`, dropping the stale WAL files.

## Debug

The module runs under an agent that sets many environment variables (in
`/home/calrs1/.config/state`):

    runagent -m calrs1 env

Become the module user to run scripts with the same environment:

    runagent -m calrs1

Inspect the containers:

```
runagent -m calrs1 podman ps
runagent -m calrs1 podman exec calrs-app env
runagent -m calrs1 journalctl --user -u calrs-app -f
```

## Testing

Test the module using the `test-module.sh` script:

    ./test-module.sh <NODE_ADDR> ghcr.io/stephdl/calrs:latest

The tests are made using [Robot Framework](https://robotframework.org/)

## UI translation

Translated with [Weblate](https://hosted.weblate.org/projects/ns8/).

To setup the translation process:

- add [GitHub Weblate app](https://docs.weblate.org/en/latest/admin/continuous.html#github-setup) to your repository
- add your repository to [hosted.weblate.org](https://hosted.weblate.org) or ask a NethServer developer to add it to ns8 Weblate project
