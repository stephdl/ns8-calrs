*** Settings ***
Library    SSHLibrary
Resource    api.resource
Resource    calrs.resource

*** Test Cases ***
Check if calrs is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if the mail server is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${mail_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if the user domain is removed correctly
    Run task    remove-internal-domain    {"domain":"${USER_DOMAIN}"}
