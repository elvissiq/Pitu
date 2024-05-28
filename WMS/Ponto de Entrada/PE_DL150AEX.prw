#INCLUDE "PROTHEUS.CH"
#INCLUDE "FWMVCDEF.CH"

User Function DL150AEX()

	Local aArea     := GetArea()
	Local aLibDCF   := PARAMIXB[1] //ID CDF
	Local cEndDest  := SuperGetMV("MV_XENDDES",.F.,"PRODUCAO")
	Local lContinua := .T.
	Local aRecD12   := {}
	Local nX, cIDDAG, cIDDCF

	If ValType(aLibDCF) != "A"
		Return
	EndIF 
	
	For nX := 1 To Len(aLibDCF)
		cIDDCF := aLibDCF[nX]
		lContinua := .F.
		dbSelectArea("DCR")
		dbSetOrder(3)
		If MsSeek(xFilial()+cIDDCF)
			cIDDAG := DCR->DCR_IDORI
			dbSelectArea("D12")
			dbSetOrder(4)
			MsSeek(xFilial()+cIDDAG)
			While !Eof() .and. xFilial()+cIDDAG == D12->(D12_FILIAL+D12_IDDCF)
				If D12->D12_STATUS == "4"
					lContinua := .T.
					Exit
				Endif
				dbSkip()
			End
		Endif
		
		If lContinua

			aRet[1] := .T.
			aRet[2] := D12->(recno())
			
			If D12->D12_ORIGEM == "SC2"
			
				AltD12End(aRet[2], cEndDest)
			
				If aRet[1]
					aadd(aRecD12, aRet[2])
				Endif
			
			Endif
		Endif
	
		If cServic == cSrvREQOP .and. D12->D12_ORIGEM == "DH1"
			dbSelectArea("DH1")
			dbOrderNickName("CIDDCF")
			If DH1->(MsSeek(xFilial()+aLibDCF[nX])) .and. !Empty(DH1->DH1_OP)
				aadd(aRecD12, aRet[2])
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

Static Function AltD12End(nRecD12, cEndDest)

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
	oModelGrid:SetValue('D12_ENDDES',cEndDest)
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
