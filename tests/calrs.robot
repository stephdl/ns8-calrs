*** Settings ***
Library    SSHLibrary

*** Variables ***
# Any resolvable-looking name: the schema demands a dot, nothing resolves it.
${TEST_HOST}    calrs.ns8-ci.test
${ADMIN_EMAIL}    admin@ns8-ci.test
${ADMIN_PASSWORD}    Nethesis,1234

*** Test Cases ***
Check if calrs is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Suite Variable    ${module_id}    ${output.module_id}

Check if calrs can be configured
    ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"host":"${TEST_HOST}","http2https":false,"lets_encrypt":false,"admin_email":"${ADMIN_EMAIL}","admin_name":"Administrator","admin_password":"${ADMIN_PASSWORD}"}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if calrs configuration reads back
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/get-configuration --data '{}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${config} =    Evaluate    json.loads('''${output}''')    modules=json
    Should Be Equal    ${config}[host]    ${TEST_HOST}
    Should Be Equal    ${config}[admin_email]    ${ADMIN_EMAIL}

Check if calrs services are running
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} systemctl --user is-active calrs.service calrs-app.service
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Not Contain    ${output}    inactive

Check if calrs answers on its port
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:\${TCP_PORT}/'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Be Equal    ${output}    200

Check if the administrator account exists
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'podman run --rm --network=none --volume calrs-data:/var/lib/calrs:z \${CALRS_IMAGE} user list'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    ${ADMIN_EMAIL}

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
