*** Settings ***
Library    SSHLibrary
Resource    api.resource

*** Variables ***
# Any resolvable-looking name: the schema demands a dot, nothing resolves it.
${TEST_HOST}    calrs.ns8-ci.test
${ADMIN_EMAIL}    admin@ns8-ci.test
${ADMIN_PASSWORD}    Nethesis,1234
# calrs derives the username from the email local part
${ADMIN_USERNAME}    admin
${EVENT_SLUG}    ci-booking

*** Keywords ***
Run calrs cli
    [Documentation]    Run the calrs CLI in an ephemeral container on the module volume
    [Arguments]    ${arguments}
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'podman run --rm --network=none --volume calrs-data:/var/lib/calrs:z \${CALRS_IMAGE} ${arguments}'
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

*** Test Cases ***
Check if calrs is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Suite Variable    ${module_id}    ${output.module_id}

Check if calrs can be configured
    Run task    module/${module_id}/configure-module
    ...    {"host":"${TEST_HOST}","lets_encrypt":false,"admin_email":"${ADMIN_EMAIL}","admin_name":"Administrator","admin_password":"${ADMIN_PASSWORD}"}
    ...    decode_json=${FALSE}

Check if calrs configuration reads back
    ${config} =    Run task    module/${module_id}/get-configuration    {}
    Should Be Equal    ${config}[host]    ${TEST_HOST}
    Should Be Equal    ${config}[admin_email]    ${ADMIN_EMAIL}

Check if calrs services are running
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} systemctl --user is-active calrs.service calrs-app.service
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Not Contain    ${output}    inactive

Check if calrs answers on its port
    # -f fails on any HTTP error status
    ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'curl -fs -o /dev/null http://127.0.0.1:\${TCP_PORT}/auth/login'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if the sign in page is served through Traefik
    ${output} =    Fetch page    /
    Should Contain    ${output}    Sign in
    Should Contain    ${output}    Powered by
    # The registration link is rendered only while open registration is enabled
    Should Not Contain    ${output}    /auth/register

Check if the administrator account exists
    ${output}  ${rc} =    Run calrs cli    user list
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    ${ADMIN_EMAIL}

Check if a second configuration keeps a single administrator
    Run task    module/${module_id}/configure-module
    ...    {"host":"${TEST_HOST}","lets_encrypt":false,"admin_email":"${ADMIN_EMAIL}","admin_name":"Administrator","admin_password":"${ADMIN_PASSWORD}"}
    ...    decode_json=${FALSE}
    ${output}  ${rc} =    Run calrs cli    user list
    Should Be Equal As Integers    ${rc}  0
    ${accounts} =    Evaluate    $output.count("@")
    Should Be Equal As Integers    ${accounts}  1

Check if a short administrator password is refused
    # The agent exits 10 on a JSON Schema input validation failure
    ${errors} =    Run task    module/${module_id}/configure-module
    ...    {"host":"${TEST_HOST}","lets_encrypt":false,"admin_email":"${ADMIN_EMAIL}","admin_name":"Administrator","admin_password":"short"}
    ...    decode_json=${FALSE}    rc_expected=10
    Should Contain    ${errors}    admin_password
    ${config} =    Run task    module/${module_id}/get-configuration    {}
    Should Be Equal    ${config}[host]    ${TEST_HOST}

Check if the guest booking page offers slots
    ${output}  ${rc} =    Run calrs cli
    ...    event-type create --title "CI booking" --slug ${EVENT_SLUG} --duration 30
    Should Be Equal As Integers    ${rc}  0
    ${profile} =    Fetch page    /u/${ADMIN_USERNAME}
    Should Contain    ${profile}    ${EVENT_SLUG}
    ${page} =    Fetch page    /u/${ADMIN_USERNAME}/${EVENT_SLUG}
    # Slots come from the default Mon-Fri 9-17 availability, no CalDAV source needed
    Should Contain    ${page}    /book?date=

Check if the database dump is consistent
    ${rc} =    Execute Command    runagent -m ${module_id} module-dump-state
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} python3 -c "import os, sqlite3; print(sqlite3.connect(os.environ['AGENT_STATE_DIR'] + '/calrs-backup.db').execute('PRAGMA integrity_check').fetchone()[0])"
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Be Equal    ${output}    ok

Check if calrs is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
