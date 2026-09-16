*** Settings ***
Library    SSHLibrary
Resource    api.resource
Resource    calrs.resource

*** Test Cases ***
Check if calrs is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Global Variable    ${module_id}    ${output.module_id}

Check if a configuration without credentials is refused
    # calrs gives the admin role to the first account that registers: the action
    # refuses to publish an instance whose database holds nobody. The step
    # message reaches stderr, which Run task does not return
    ${stderr}  ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"host":"${TEST_HOST}","lets_encrypt":false}'
    ...    return_stdout=False    return_stderr=True    return_rc=True
    Should Be Equal As Integers    ${rc}  2
    Should Contain    ${stderr}    calrs holds no account

Check if half the administrator credentials are refused
    # The agent exits 10 on a JSON Schema input validation failure. A missing
    # dependency is reported on the whole object, not on the lonely field
    ${errors} =    Run task    module/${module_id}/configure-module
    ...    {"host":"${TEST_HOST}","lets_encrypt":false,"admin_email":"${ADMIN_EMAIL}"}
    ...    decode_json=${FALSE}    rc_expected=10
    Should Contain    ${errors}    missing_dependency

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

Check if open registration is disabled
    # create-admin closes registration right after creating the first account
    ${output}  ${rc} =    Run calrs cli    config show
    Should Be Equal As Integers    ${rc}  0
    Should Match Regexp    ${output}    Registration:\\s+disabled

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
