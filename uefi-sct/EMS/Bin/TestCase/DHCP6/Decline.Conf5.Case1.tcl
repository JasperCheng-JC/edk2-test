# 
#  Copyright 2006 - 2011 Unified EFI, Inc.<BR> 
#  Copyright (c) 2010 - 2011, Intel Corporation. All rights reserved.<BR>
# 
#  This program and the accompanying materials
#  are licensed and made available under the terms and conditions of the BSD License
#  which accompanies this distribution.  The full text of the license may be found at 
#  http://opensource.org/licenses/bsd-license.php
# 
#  THE PROGRAM IS DISTRIBUTED UNDER THE BSD LICENSE ON AN "AS IS" BASIS,
#  WITHOUT WARRANTIES OR REPRESENTATIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED.
# 
################################################################################
CaseLevel         CONFORMANCE
CaseAttribute     AUTO
CaseVerboseLevel  DEFAULT
set reportfile    report.csv

#
# test case Name, category, description, GUID...
#
CaseGuid        83658F9F-B6F2-4f51-8354-AC864239DAC5
CaseName        Decline.Conf5.Case1
CaseCategory    DHCP6
CaseDescription {Test the Decline Conformance of DHCP6 - Invoke Decline() \
                 when the user returns error status from callback function. \
                 EFI_ABORTED should be returned.
                }
################################################################################

Include DHCP6/include/Dhcp6.inc.tcl

proc CleanUpEutEnvironment {} {

    #
    # Destroy child.
    #
    Dhcp6ServiceBinding->DestroyChild "@R_Handle, &@R_Status"
    GetAck

    DestroyPacket
    EndCapture

    #
    # EndScope
    #
    EndScope _DHCP6_DECLINE_CONF5_
    #
    # End Log 
    #
    EndLog
}

#
# Begin log ...
#
BeginLog
#
# BeginScope
#
BeginScope  _DHCP6_DECLINE_CONF5_

#
# Parameter Definition
# R_ represents "Remote EFI Side Parameter"
# L_ represents "Local OS Side Parameter"
#
UINTN                                   R_Status
UINTN                                   R_Handle

#
# Create child.
#
Dhcp6ServiceBinding->CreateChild "&@R_Handle, &@R_Status"
GetAck
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                       \
                "Dhcp6SB.CreateChild - Create Child 1"                       \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"
SetVar     [subst $ENTS_CUR_CHILD]  @R_Handle

EFI_DHCP6_CONFIG_DATA                   R_ConfigData
#
# SolicitRetransmission parameters
# Irt 1
# Mrc 2
# Mrt 3
# Mrd 2
#
UINT32                                  R_SolicitRetransmission(4)
SetVar R_SolicitRetransmission          {1 2 3 2}
#
# Call Configure() to configure this child
# o Dhcp6Callback              3          0:NULL 1:Abort 2:DoNothing 3:Abort in RenewRebind,Release.
# o CallbackContext            0          
# o OptionCount                0        
# o OptionList                 0          
# o IaDescriptor               Type=Dhcp6IATypeNA IaId=1
# o IaInfoEvent                NULL          
# o ReconfigureAccept          FALSE
# o RapidCommit                FALSE
# o SolicitRetransmission      defined above
#

SetVar R_ConfigData.Dhcp6Callback              3
SetVar R_ConfigData.CallbackContext            0
SetVar R_ConfigData.OptionCount                0
SetVar R_ConfigData.OptionList                 0
SetVar R_ConfigData.IaDescriptor.Type          $Dhcp6IATypeNA
SetVar R_ConfigData.IaDescriptor.IaId          1
SetVar R_ConfigData.IaInfoEvent                0
SetVar R_ConfigData.ReconfigureAccept          FALSE
SetVar R_ConfigData.RapidCommit                FALSE
SetVar R_ConfigData.SolicitRetransmission      &@R_SolicitRetransmission

#
# Configure this child
#
Dhcp6->Configure  "&@R_ConfigData, &@R_Status"
GetAck
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid         \
                "Dhcp6.Configure - Configure Child 1"          \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

set hostmac    [GetHostMac]
set targetmac  [GetTargetMac]
RemoteEther    $targetmac
LocalEther     $hostmac
set LocalIP    "fe80::203:47ff:fead:6a28"
LocalIPv6      $LocalIP

set L_Filter "src port 546"
StartCapture CCB $L_Filter

#
# Check point: Call Start() to validate the start process.
# 1). Capture and validate DHCP6 Solicit packet. Get the remote IPv6 address
#
Dhcp6->Start "&@R_Status"

ReceiveCcbPacket CCB SolicitPacket 5
set assert pass
if { ${CCB.received} == 0} {    
    set assert fail
    RecordAssertion $assert $GenericAssertionGuid                \
                    "Dhcp6.Start - No Solicit Packet sent."	
 
    CleanUpEutEnvironment
    return
}

ParsePacket SolicitPacket -t IPv6 -IPv6_src IPV6Src -IPv6_payload IPV6Payload
EndCapture
RemoteIPv6 $IPV6Src
#puts "Remote IP: $IPV6Src"

set DuidType [lrange $IPV6Payload 16 17] 
puts "DuidType : $DuidType\n"

if { $DuidType != "0x00 0x04" } {
    set TransId_and_ClientId [lrange $IPV6Payload 9 29]
} else {
    #
    # New DHCP6 DUID-UUID type
    #
    set TransId_and_ClientId [lrange $IPV6Payload 9 33]
}


set AdvertisePayloadData [CreateDHCP6AdvertisePayloadData $IPV6Src $LocalIP \
                         $TransId_and_ClientId]

RecordAssertion $assert $GenericAssertionGuid  \
                     "Zhangchao Reach1.\n"

if { $DuidType != "0x00 0x04" } {
    set PayloadDataLength 231
} else {
    #
    # New DHCP6 DUID-UUID type
    #
    set PayloadDataLength 235
}
CreatePayload AdvertisePayload List $PayloadDataLength $AdvertisePayloadData

#
# Create Advertise packet
#
CreatePacket AdvertisePacket -t IPv6 -IPv6_ver 0x06 -IPv6_tc 0x00 -IPv6_fl 0x00 \
                                     -IPv6_pl $PayloadDataLength -IPv6_nh 0x11 -IPv6_hl 128 \
                                     -IPv6_payload AdvertisePayload

#
# Ready to capture the Request packet
#
StartCapture CCB $L_Filter
SendPacket AdvertisePacket
ReceiveCcbPacket CCB RequestPacket 10
if { ${CCB.received} == 0} {
    set assert fail
    RecordAssertion $assert $GenericAssertionGuid                \
                    "Dhcp6.Start - No Request Packet sent."	
    
    CleanUpEutEnvironment
    return
}

#
# Build and send Reply packet
#
ParsePacket RequestPacket -t IPv6 -IPv6_src IPV6Src -IPv6_payload IPV6Payload
RemoteIPv6 $IPV6Src
#puts "Remote IP: $IPV6Src"

set DuidType [lrange $IPV6Payload 16 17] 
puts "DuidType : $DuidType\n"

if { $DuidType != "0x00 0x04"} {
    set TransId_and_ClientId [lrange $IPV6Payload 9 29]
} else {
    #
    # New DHCP6 DUID-UUID type
    #
    set TransId_and_ClientId [lrange $IPV6Payload 9 33]
}
#puts "Transaction ID and Client Id: $TransId_and_ClientId"

set ReplyPayloadData [CreateDHCP6ReplyPayloadData $IPV6Src $LocalIP \
                         $TransId_and_ClientId]

if { $DuidType != "0x00 0x04"} {
    set PayloadDataLength 179
} else {
    #
    # New DHCP6 DUID-UUID type
    #
    set PayloadDataLength 183
}
CreatePayload ReplyPayload List $PayloadDataLength $ReplyPayloadData

#
# Create Reply packet
#
CreatePacket ReplyPacket -t IPv6 -IPv6_ver 0x06 -IPv6_tc 0x00 -IPv6_fl 0x00 \
                                     -IPv6_pl $PayloadDataLength -IPv6_nh 0x11 -IPv6_hl 128 \
                                     -IPv6_payload ReplyPayload

SendPacket ReplyPacket

#
# Get ACK of Start()
#
GetAck

#
# Check point: Call Decline().
#              The user returns EFI_ABORTED at Dhcp6SendDecline event.
#              EFI_ABORTED should be returned.
#
UINT32                                   R_AddressCount
EFI_IPv6_ADDRESS                         R_Addresses
SetVar R_AddressCount                    1
#
# This address is assgined to this child.
#
SetIpv6Address R_Addresses               "2000::14da:d837:147:527d"

Dhcp6->Decline  "@R_AddressCount, &@R_Addresses, &@R_Status"
GetAck

set assert [VerifyReturnStatus R_Status $EFI_ABORTED]
RecordAssertion $assert $Dhcp6DeclineConf5AssertionGuid001       \
                "Dhcp6.Decline - The user returns error from callback function."  \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_ABORTED"

CleanUpEutEnvironment

