*** Settings ***
Documentation    Names and helpers shared by the suites of this directory.
Library    SSHLibrary

*** Variables ***
# Any resolvable-looking name: the schema demands a dot, nothing resolves it.
${TEST_HOST}    calrs.ns8-ci.test
${USER_DOMAIN}    ldap.dom.test
${MAIL_DOMAIN}    domain.test
${MAIL_HOSTNAME}    mail.${MAIL_DOMAIN}
# The administrator and the guest are mailboxes of the domain that
# 20__mail_stack.robot creates, so 30__mail_delivery.robot can watch the
# booking mail reach them
${ADMIN_EMAIL}    u1@${MAIL_DOMAIN}
${GUEST_EMAIL}    u3@${MAIL_DOMAIN}
${ADMIN_PASSWORD}    Nethesis,1234
# calrs derives the username from the email local part
${ADMIN_USERNAME}    u1
${EVENT_SLUG}    ci-booking

*** Keywords ***
Run calrs cli
    [Documentation]    Run the calrs CLI in an ephemeral container on the module volume
    [Arguments]    ${arguments}
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'podman run --rm --network=none --volume calrs-data:/var/lib/calrs:z \${CALRS_IMAGE} ${arguments}'
    ...    return_rc=True
    RETURN    ${output}    ${rc}

Run calrs cli with the smarthost
    [Documentation]    The same container with the network left on and the
    ...                discovered SMTP block passed in: calrs reads the
    ...                environment before the database
    [Arguments]    ${arguments}
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'podman run --rm --volume calrs-data:/var/lib/calrs:z --env-file $AGENT_STATE_DIR/discovery.env \${CALRS_IMAGE} ${arguments}'
    ...    return_rc=True
    RETURN    ${output}    ${rc}

Fetch page
    [Documentation]    Fetch a page through Traefik, following redirects
    [Arguments]    ${path}
    ${output}  ${rc} =    Execute Command
    ...    curl -fkL -H "Host: ${TEST_HOST}" https://127.0.0.1${path}
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    RETURN    ${output}
