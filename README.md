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

No release is tagged yet, so `latest` does not exist: every branch is published as
`ghcr.io/stephdl/calrs:<branch name>`, for instance `ghcr.io/stephdl/calrs:calrs-module`.

## Configure

Let's assume the instance is named `calrs1`.

Launch `configure-module` with the following parameters:

- `host`: fully qualified domain name of the application (required)
- `lets_encrypt`: request a Let's Encrypt certificate (true/false)
- `mail_from`: sender address of booking messages, defaults to `noreply@<host>`
- `allow_private_hosts`: host names allowed to bypass the calrs private address
  check, needed to reach a CalDAV server on a private address (see
  [Private CalDAV hosts](#private-caldav-hosts))
- `admin_email`, `admin_name`, `admin_password`: first administrator account,
  the password must be at least 12 characters

Example:

```
api-cli run configure-module --agent module/calrs1 --data - <<EOF
{
  "host": "calrs.domain.com",
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

### Private CalDAV hosts

CalDAV source URLs are typed by the users, so calrs refuses any URL whose host
name resolves to a private or reserved IP address: loopback, RFC1918,
link-local, ULA. The check runs before the first HTTP request and guards
against server-side request forgery.

A calendar server on the LAN is refused by that same check. List its host name
in `allow_private_hosts` to lift the check for that host only; every other host
is still validated. Matching is exact and case-insensitive: no wildcards, no
subdomain matching. Keep the list as short as possible.

```
"allow_private_hosts": ["nextcloud.lan", "192.168.1.10"]
```

### Administrator account

calrs grants the administrator role to the first account that registers. When
`admin_email` and `admin_password` are given, the module creates that account
before the service starts and closes open registration in the same run, so the
role is never up for grabs. That single write is the whole of the module's
involvement: the registration setting then belongs to the calrs admin panel,
and no later `configure-module` touches it.

The step is skipped when an account already exists, so an existing installation
is never touched: `CALRS_ADMIN_EMAIL` is then left alone and the settings page
keeps offering the form. The password is used once and never stored in the
module environment.

A `configure-module` run without `admin_email` and `admin_password` — the CLI
with a host alone — starts the instance with no account and registration in
whatever state calrs left it, which on a fresh volume means open. Whoever
registers first becomes administrator. Create the account in the same run, as
the settings page does.

Further accounts are managed from the calrs admin dashboard, or with the CLI:

    runagent -m calrs1 bash -c 'podman run --rm -it --volume calrs-data:/var/lib/calrs:z ${CALRS_IMAGE} user list'

## Daily use

1. **Connect a calendar** — Dashboard > Sources. calrs reads the CalDAV collections to
   compute free/busy, and writes confirmed bookings back to the calendar you pick.
2. **Create an event type** — duration, buffers, booking horizon, which calendars block
   availability.
3. **Share the link** — `https://<host>/u/<username>/<slug>`, or `/u/<username>` for the
   whole list. Guests pick a slot and leave a name and an email: no account, no
   registration. They get a confirmation mail with a cancellation link.

A CalDAV server on a private address (an internal SOGo or Nextcloud) is refused by the
calrs SSRF guard until its host name is listed in `allow_private_hosts`. With `ns8-sogo`,
also set `dav: true` in its own configuration: the flag drives
`SOGoCalendarDAVAccessEnabled`, and CalDAV is closed while it is false.

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

Host, port and encryption are mapped one to one: NS8 `encrypt_smtp`
(`none`, `starttls`, `tls`) becomes `CALRS_SMTP_TLS_MODE`. The NS8
`tls_verify` switch has no calrs counterpart: calrs always verifies the
server certificate. An internal relay with a self-signed certificate must
therefore be declared with `encrypt_smtp: none`, or given a trusted
certificate.

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
```

The module user cannot read the journal, so follow the logs as root:

```
journalctl -t calrs-app -f
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
