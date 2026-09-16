*** Settings ***
Documentation    Book a slot and follow the two messages calrs sends, the guest
...              confirmation and the host notification, until Postfix hands
...              them to Dovecot.
Library    SSHLibrary
Library    DateTime
Library    String
Resource    api.resource
Resource    calrs.resource

*** Test Cases ***
Check if the booking page offers a slot to take
    ${output}  ${rc} =    Run calrs cli    event-type slots ${EVENT_SLUG} --days 7
    Should Be Equal As Integers    ${rc}  0
    ${dates} =    Get Regexp Matches    ${output}    (\\d{4}-\\d{2}-\\d{2}):    1
    Should Not Be Empty    ${dates}    No bookable day in the next week
    ${times} =    Get Regexp Matches    ${output}    (?m)^\\s+(\\d{2}:\\d{2}) –    1
    Should Not Be Empty    ${times}    No free slot on ${dates}[0]
    Set Suite Variable    ${booking_date}    ${dates}[0]
    Set Suite Variable    ${booking_time}    ${times}[0]

Check if a booking sends both messages
    ${timestamp} =    Get Current Date    result_format=%Y-%m-%d %H:%M:%S
    Set Suite Variable    ${sent_since}    ${timestamp}
    ${output}  ${rc} =    Run calrs cli with the smarthost
    ...    booking create ${EVENT_SLUG} --date ${booking_date} --time ${booking_time} --name "CI Guest" --email ${GUEST_EMAIL}
    Should Be Equal As Integers    ${rc}  0
    # One line per recipient, "sent" or "failed: <reason>"
    Should Contain    ${output}    Sending confirmation to ${GUEST_EMAIL}
    Should Contain    ${output}    Sending notification to ${ADMIN_EMAIL}
    Should Not Contain    ${output}    failed:
    Should Contain X Times    ${output}    sent    2

Check if the guest confirmation is delivered
    Wait Until Keyword Succeeds    10x    2s    Message should reach the mailbox of    ${GUEST_EMAIL}

Check if the host notification is delivered
    Wait Until Keyword Succeeds    10x    2s    Message should reach the mailbox of    ${ADMIN_EMAIL}

*** Keywords ***
Message should reach the mailbox of
    [Documentation]    Read the Postfix LMTP record, as the ns8-mail suite does
    [Arguments]    ${address}
    ${output}  ${rc} =    Execute Command
    ...    journalctl -o cat -t postfix/lmtp -S '${sent_since}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Match    ${output}    *to\=<${address}>*status\=sent (250 2.0.0 * Saved)*
    ...    No LMTP delivery record for ${address}
