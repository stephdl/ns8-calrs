*** Settings ***
Documentation    Bring up the account provider and the mail server the booking
...              mail is delivered through, then point the cluster smarthost at
...              them. Shaped after the ns8-sogo test suite.
Library    SSHLibrary
Resource    api.resource
Resource    calrs.resource

*** Test Cases ***
Check if the account provider is installed
    ${response} =    Run task    add-internal-provider    {"image":"openldap","node":1}
    Set Global Variable    ${ldap_id}    ${response['module_id']}
    Run task    module/${ldap_id}/configure-module
    ...    {"domain":"${USER_DOMAIN}","admuser":"admin","admpass":"Nethesis,1234","provision":"new-domain"}

Check if the two mailbox owners are created
    # u1 hosts the bookings and is the calrs administrator, u3 books a slot
    Run task    module/${ldap_id}/add-user
    ...    {"user":"u1","display_name":"Booking Host","password":"Nethesis,1234"}
    Run task    module/${ldap_id}/add-user
    ...    {"user":"u3","display_name":"Booking Guest","password":"Nethesis,1234"}

Check if the mail server is installed
    ${output}  ${rc} =    Execute Command    add-module ghcr.io/nethserver/mail:main 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Global Variable    ${mail_id}    ${output.module_id}
    Run task    module/${mail_id}/configure-module
    ...    {"hostname":"${MAIL_HOSTNAME}","user_domain":"${USER_DOMAIN}","mail_domain":"${MAIL_DOMAIN}"}

Check if the mail filters are disabled
    # Nothing here inspects mail bodies, and ClamAV is the heaviest part of the
    # module: its signature download alone outweighs the whole suite
    Run task    module/${mail_id}/set-filter-configuration
    ...    {"antispam":{"enabled":false},"antivirus":{"enabled":false}}

Check if the smarthost points at the mail server
    ${smarthost} =    Run task    get-smarthost    {}
    ${servers} =    Set Variable    ${smarthost}[mail_server]
    Should Not Be Empty    ${servers}    The mail module published no submission service
    ${host} =    Set Variable    ${servers}[0][host]
    Set Global Variable    ${smtp_host}    ${host}
    # Postfix on port 25 presents an internal certificate, and calrs validates
    # against the root bundle compiled into its binary: none is the only mode
    Run task    set-smarthost
    ...    {"host":"${host}","port":25,"username":"","password":"","enabled":true,"encrypt_smtp":"none","tls_verify":false}

Check if calrs picked the smarthost up
    # The smarthost-changed event reaches bin/discover-smarthost, which rewrites
    # the environment block the application and the CLI read
    Wait Until Keyword Succeeds    10x    2s    Discovery env should carry    CALRS_SMTP_HOST=${smtp_host}

*** Keywords ***
Discovery env should carry
    [Arguments]    ${line}
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'cat $AGENT_STATE_DIR/discovery.env'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    ${line}
