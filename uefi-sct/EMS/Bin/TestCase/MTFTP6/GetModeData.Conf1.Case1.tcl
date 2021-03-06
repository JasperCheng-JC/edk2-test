# 
#  Copyright 2006 - 2010 Unified EFI, Inc.<BR> 
#  Copyright (c) 2010, Intel Corporation. All rights reserved.<BR>
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
CaseGuid          13014C8C-FE1E-4a8c-A35A-D5E655522EDA
CaseName          GetModeData.Conf1.Case1
CaseCategory      MTFTP6
CaseDescription   {Test the GetModeData Conformance of MTFTP6 -     \
                   Invoke GetModeData() when Mtftp6ModeData is NULL.\
                   EFI_INVALID_PARAMETER should be returned.}
################################################################################

Include MTFTP6/include/Mtftp6.inc.tcl

#
# Begin log ...
#
BeginLog

BeginScope _MTFTP6_GETMODEDATA_CONFORMANCE1_CASE1_

#
# Parameter Definition
# R_ represents "Remote EFI Side Parameter"
# L_ represents "Local OS Side Parameter"
#
UINTN                            R_Status
UINTN                            R_Handle

Mtftp6ServiceBinding->CreateChild "&@R_Handle, &@R_Status"
GetAck
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                   \
                "Mtftp6SB.CreateChild - Create Child "                    \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"
SetVar     [subst $ENTS_CUR_CHILD]  @R_Handle

#
# check point: Call GetModeData function when the Mtftp6ModeData is NULL.\
#              EFI_INVALID_PARAMETER should be returned.
#
Mtftp6->GetModeData "NULL, &@R_Status"
GetAck
set assert [VerifyReturnStatus R_Status $EFI_INVALID_PARAMETER]
RecordAssertion $assert $Mtftp6GetModeDataConf1AssertionGuid001           \
                "Mtftp6.GetModeData -conf- Call GetModeData when Mtftp6ModeData is NULL"  \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_INVALID_PARAMETER"

#
# Destroy Child 
#
Mtftp6ServiceBinding->DestroyChild "@R_Handle, &@R_Status"
GetAck
set assert [VerifyReturnStatus R_Status $EFI_SUCCESS]
RecordAssertion $assert $GenericAssertionGuid                  \
                "Mtftp6SB.DestroyChild - Destroy Child "                  \
                "ReturnStatus - $R_Status, ExpectedStatus - $EFI_SUCCESS"

EndScope _MTFTP6_GETMODEDATA_CONFORMANCE1_CASE1_

#
# End Log
#
EndLog