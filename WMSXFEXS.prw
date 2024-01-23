#INCLUDE "PROTHEUS.CH"
#INCLUDE "FWMVCDEF.CH"

User Function WMSXFEXS()

Local aArea    := GetArea()
Local aLibDCF  := PARAMIXB[1] //ID CDF
Local aRet     := {.T., 0, {}}
Local nX       := 0
Local cProduto := CriaVar("B1_COD", .F.)
Local cEndOri  := CriaVar("BE_LOCALIZ", .F.)
Local cEndDes  := CriaVar("BE_LOCALIZ", .F.)
Local cServB1  := SuperGetMV("PC_SRVPRB1",.F.,"010")
Local cServB2  := SuperGetMV("PC_SRVPRB2",.F.,"011")
Local cEndRec  := PADR(SuperGetMV("PC_ENDNFT",.F.,"REC"), TAMSX3("BE_LOCALIZ")[1])
Local cSrvREQOP:= SuperGetMV("PC_SRVRQOP",.F.,"006")
Local cLocPrdOP:= PADR(SuperGetMV("PC_LOCRQOP",.F.,"08"), TAMSX3("BE_LOCAL")[1])
Local cEndPrdOP:= PADR(SuperGetMV("PC_ENDRQOP",.F.,"UND"), TAMSX3("BE_LOCALIZ")[1])
Local cEndPAUND:= PADR(SuperGetMV("PC_ENDPAOP",.F.,"PRODUCAO"), TAMSX3("BE_LOCALIZ")[1])
Local cCodZon  := CriaVar("B5_CODZON", .F.)
Local cLocDes  := CriaVar("B1_LOCPAD", .F.)
Local cIDDAG   := CriaVar("DCF_ID", .F.)
Local cIDDCF   := CriaVar("DCF_ID", .F.)
Local aRecD12  := {}
Local lContinua := .T.
For nX := 1 To Len(aLibDCF)
	cIDDCF := aLibDCF[nX]
	lContinua := .F.
	dbSelectArea("DCR")
	dbSetOrder(3)
	If dbSeek(xFilial()+cIDDCF)
		cIDDAG := DCR->DCR_IDORI
		dbSelectArea("D12")
		dbSetOrder(4)
		dbSeek(xFilial()+cIDDAG)
		While !Eof() .and. xFilial()+cIDDAG == D12->(D12_FILIAL+D12_IDDCF)
			If D12->D12_STATUS == "4"
				lContinua := .T.
				Exit
			Endif
			dbSkip()
		End
	Endif
	If lContinua
		cEndDes := D12->D12_ENDDES
		cLocDes := D12->D12_LOCDES
		cUnit   := D12->D12_IDUNIT
		cServic := D12->D12_SERVIC
		cProduto:= D12->D12_PRODUT
		aRet[1] := .T.
		aRet[2]  := D12->(recno())
		If cFilAnt == "010102"
			If D12->D12_ORIGEM == "SD1"
				If cEndDes <> cEndRec
					cEndZon := Posicione("SBE", 1, xFilial("SBE")+cLocDes+cEndRec, "BE_CODZON")
					cCodZon  := Posicione("SB5", 1, xFilial("SB5")+cProduto, "B5_CODZON")
					If cCodZon <> cEndZon
						GerDCH(cProduto, cEndZon)
					Endif
					Processa({|| aRet := AltD12End(aRet[2], cEndRec)}, "Aguarde...","Enviando para Endereço: " + cEndRec, .T. )
				Endif
				If aRet[1]
					dbSelectArea("D12")
					dbGoto(aRet[2])
					If Alltrim(D12->D12_ENDDES) == Alltrim(cEndRec)
						aadd(aRecD12, aRet[2])
					Endif
				Endif
			Endif
		Else
			If cServic == cServB1 .or. cServic == cServB2
				If !Empty(cUnit) .and. D12->D12_ORIGEM == "D0R"
					cEndOri  := D12->D12_ENDORI
					dbSelectArea("SD3")
					dbOrderNickName("D3PALETE")
					If dbSeek(xFilial()+cUnit)
						cProduto := SD3->D3_COD
						cCodZon  := Posicione("SB5", 1, xFilial("SB5")+cProduto, "B5_CODZON")
						dbSelectArea("CYA")
						dbOrderNickName("CYASRV")
						If dbSeek(xFilial()+cServic) .and. !Empty(CYA->CYA_XENDP) .and. cEndDes <> CYA->CYA_XENDP
							cEndDes := CYA->CYA_XENDP
							cEndZon := Posicione("SBE", 1, xFilial("SBE")+cLocDes+cEndDes, "BE_CODZON")
							If cCodZon <> cEndZon
								GerDCH(cProduto, cEndZon)
							Endif
							Processa({|| aRet := AltD12End(aRet[2], cEndDes)}, "Aguarde...","Enviando para Endereço: " + cEndDes, .T. )
						Endif
						If aRet[1]
							aadd(aRecD12, aRet[2])
							dbSelectArea("D12")
							dbGoto(aRet[2])
							cEndZon := Posicione("SBE", 1, xFilial("SBE")+D12->D12_LOCDES+D12->D12_ENDDES, "BE_CODZON")
							If cCodZon <> cEndZon
								GerDCH(cProduto, cEndZon)
							Endif
						Endif
					Endif
				ElseIf D12->D12_ORIGEM == "SC2" .and. cLocDes == cLocPrdOP
					If IsInCallStack( 'U_PC_FECHPA' )
						cEndPrdOP := cEndPAUND
					Endif
					If cEndDes <> cEndPrdOP
						cEndDes := cEndPrdOP
						cCodZon := Posicione("SB5", 1, xFilial("SB5")+cProduto, "B5_CODZON")
						cEndZon := Posicione("SBE", 1, xFilial("SBE")+cLocDes+cEndDes, "BE_CODZON")
						If cCodZon <> cEndZon
							GerDCH(cProduto, cEndZon)
						Endif
						Processa({|| aRet := AltD12End(aRet[2], cEndDes)}, "Aguarde...","Enviando para Endereço: " + cEndDes, .T. )
						If aRet[1]
							aadd(aRecD12, aRet[2])
						Endif
					Else
						aadd(aRecD12, aRet[2])
					Endif
				Endif
			Endif
			If cServic == cSrvREQOP .and. D12->D12_ORIGEM == "DH1"
				dbSelectArea("DH1")
				dbOrderNickName("CIDDCF")
				If DH1->(dbSeek(xFilial()+aLibDCF[nX])) .and. !Empty(DH1->DH1_OP)
					aadd(aRecD12, aRet[2])
				Endif
			Endif
		Endif
	Endif
Next
If Len(aRecD12) > 0
	For nX:=1 to Len(aRecD12)
		dbSelectArea("D12")
		dbGoto(aRecD12[nX])
		Processa({|| u_FinalzD12(aRecD12[nX])}, "Finalizando Serviço...","Aguarde....", .T. )
	Next
Endif
RestArea(aArea)
Return
//-----------------------------------------------------------------------------------------------------
Static Function GerDCH(cProduto, cEndZon)

Local aArea := GetArea()
Local cOrdem := "00"
dbSelectArea("DCH")
dbSetOrder(1)
If !dbSeek(xFilial()+cProduto+cEndZon)
	dbSelectArea("DCH")
	dbSetOrder(2)
	dbSeek(xFilial()+cProduto)
	While !Eof() .and. xFilial()+cProduto == DCH->(DCH_FILIAL+DCH_CODPRO)
		cOrdem := DCH->DCH_ORDEM
		dbSkip()
	End
	cOrdem := Soma1(cOrdem)
	RecLock("DCH", .T.)
	Replace DCH_FILIAL with xFilial("DCH"),;
			DCH_CODPRO with cProduto,;
			DCH_ORDEM with cOrdem,;
			DCH_CODZON with cEndZon
	MsUnLock()
Endif
RestArea(aArea)
Return
//-----------------------------------------------------------------------------------------------------
Static Function AltD12End(nRecD12, cEndDes)

Local aArea := GetArea()
Local oModelEnd, oModelGrid
Local lRet := .T.
Local nNewRecno := 0
Local aErro := {}
Wm332Autom(.T.)
WmsOpc332("6")
WmsAcao332("1")
oModelEnd := FWLoadModel("WMSA332A")
oModelGrid := oModelEnd:GetModel('D12DETAIL')
dbSelectArea("D12")
dbGoto(nRecD12)
oModelEnd:SetOperation(MODEL_OPERATION_UPDATE)
oModelEnd:Activate()
oModelGrid:SetValue('D12_ENDDES',cEndDes)
If oModelEnd:VldData()
	// Se os dados foram validados faz-se a gravação efetiva dos dados (commit)
	oModelEnd:CommitData()
	nNewRecno := D12->(recno())
Else
	aErro := oModelEnd:GetErrorMessage()
	// A estrutura do vetor com erro é:
	// [1] identificador (ID) do formulário de origem
	// [2] identificador (ID) do campo de origem
	// [3] identificador (ID) do formulário de erro
	// [4] identificador (ID) do campo de erro
	// [5] identificador (ID) do erro
	// [6] mensagem do erro
	// [7] mensagem da solução
	// [8] Valor atribuído
	// [9] Valor anterior
	lRet := .F.
	AutoGrLog( "Id do formulário de origem:" + ' [' + AllToChar( aErro[1] ) + ']' )
	AutoGrLog( "Id do campo de origem: " + ' [' + AllToChar( aErro[2] ) + ']' )
	AutoGrLog( "Id do formulário de erro: " + ' [' + AllToChar( aErro[3] ) + ']' )
	AutoGrLog( "Id do campo de erro: " + ' [' + AllToChar( aErro[4] ) + ']' )
	AutoGrLog( "Id do erro: " + ' [' + AllToChar( aErro[5] ) + ']' )
	AutoGrLog( "Mensagem do erro: " + ' [' + AllToChar( aErro[6] ) + ']' )
	AutoGrLog( "Mensagem da solução: " + ' [' + AllToChar( aErro[7] ) + ']' )
	AutoGrLog( "Valor atribuído: " + ' [' + AllToChar( aErro[8] ) + ']' )
	AutoGrLog( "Valor anterior: " + ' [' + AllToChar( aErro[9] ) + ']' )
	If !IsTelnet()
		MostraErro()
	Endif
EndIf
oModelEnd:DeActivate()
RestArea(aArea)
Return({lRet, nNewRecno, aErro})
//--------------------------------------------------------------------------------------------------------------
User Function FinalzD12(nRecno)

Local lRet     := .T.
Local aArea    := GetArea()
Local aAreaD12 := D12->(GetArea())
Local cAcao    := "1"
Local cErro    := ""
dbSelectArea("D12")
dbGoto(nRecno)
If D12->D12_STATUS == "4"
	Wm332Autom(.T.)
	WmsOpc332("4")
	WmsAcao332(cAcao)
	oModelEnd := FWLoadModel("WMSA332A")
	oModelGrid := oModelEnd:GetModel('D12DETAIL')
	dbSelectArea("D12")
	oModelEnd:SetOperation(MODEL_OPERATION_UPDATE)
	oModelEnd:Activate()
	If oModelEnd:VldData()
		// Se os dados foram validados faz-se a gravação efetiva dos dados (commit)
		oModelEnd:CommitData()
	Else
		aErro := oModelEnd:GetErrorMessage()
		// A estrutura do vetor com erro é:
		// [1] identificador (ID) do formulário de origem
		// [2] identificador (ID) do campo de origem
		// [3] identificador (ID) do formulário de erro
		// [4] identificador (ID) do campo de erro
		// [5] identificador (ID) do erro
		// [6] mensagem do erro
		// [7] mensagem da solução
		// [8] Valor atribuído
		// [9] Valor anterior
		AutoGrLog( "Id do formulário de origem:" + ' [' + AllToChar( aErro[1] ) + ']' )
		AutoGrLog( "Id do campo de origem: " + ' [' + AllToChar( aErro[2] ) + ']' )
		AutoGrLog( "Id do formulário de erro: " + ' [' + AllToChar( aErro[3] ) + ']' )
		AutoGrLog( "Id do campo de erro: " + ' [' + AllToChar( aErro[4] ) + ']' )
		AutoGrLog( "Id do erro: " + ' [' + AllToChar( aErro[5] ) + ']' )
		AutoGrLog( "Mensagem do erro: " + ' [' + AllToChar( aErro[6] ) + ']' )
		AutoGrLog( "Mensagem da solução: " + ' [' + AllToChar( aErro[7] ) + ']' )
		AutoGrLog( "Valor atribuído: " + ' [' + AllToChar( aErro[8] ) + ']' )
		AutoGrLog( "Valor anterior: " + ' [' + AllToChar( aErro[9] ) + ']' )
		cErro := aErro[6]
		lRet  := .F.
	//	MostraErro()
	EndIf
	oModelEnd:DeActivate()
Endif
RestArea(aAreaD12)
RestArea(aArea)
Return(lRet)
