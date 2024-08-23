#INCLUDE "PROTHEUS.CH"
#INCLUDE "APVT100.CH"
#Include 'FWMVCDef.ch'

/*/{Protheus.doc} VTSEPPV
Rotina para realizar a separação por Pedido de Venda na Expedição
@type function
@version 1.0
@author Elvis Siqueira
@since 26/04/2024
/*/
//-------------------------------------------------------------------------------------------------------------------------------------------
User Function VTSEPPV

	Local aTela    := {}
	Local cEndCons := PADR(SuperGetMV('MV_XENDDES',.F.," "), FWTamSX3("BE_LOCALIZ")[1]) // Endereço para realizar a separação dos PVs
	
	Private cSrvVSP  := SuperGetMv("PC_EXPSRV",.F.,"003")
	Private cUnitiza := Space(FWTamSX3("Z06_IDUNIT")[1])
	
	aTela := VtSave()
	VTClear()
	
	If !Empty(cEndCons)
		VTPRC01()
	Else
		U_VTSEPPV2()
	Endif
	
	VtRestore(,,,,aTela)

Return
//-------------------------------------------------------------------------------------------------------------------------------------------
Static Function VTPRC01()

	Local lSair       := .F.
	Local cEndder     := PADR(SuperGetMV( 'MV_XENDDES' ,.F.,"PRODUCAO"), FWTamSX3("BE_LOCALIZ")[1]) // Endereço para realizar a separação dos PVs
	Local cPedido     := Space(FWTamSX3("C5_NUM")[1])
	Local aItemPV     := {}
	Local nPos        := 0
	Local nProxLin    := 1
	Local cLoteCtl    := Space(FWTamSX3("B8_LOTECTL")[1])
	Local cProduto    := Space(FWTamSX3("B1_COD")[1])
	Local cCodBar     := Space(250)
	Local cLocal      := Space(FWTamSX3("B1_LOCPAD")[1])
	Local cSeekDCI    := ""
	Local cSeq        := Space(FWTamSX3("Z05_SEQ")[1])
	Local nOrdemFunc  := 0
	Local aFuncoesWMS := {}
	Local lFinal      := .F.
	Local aError      := {}
	Local nId, nY

	// Pesquisa quais funcoes o usuario exerce
	DCD->(DbSetOrder(1)) // DCD_FILIAL+DCD_CODFUN
	If DCD->(MsSeek(xFilial('DCD')+__cUserID, .F.))
		If DCD->DCD_STATUS == '3' // Recurso humano ausente
			WmsMessage("Usuário informado como recurso humano ausente.","WMSV00101")
			Return Nil
		EndIf
	Else
		WmsMessage("Usuário não cadastrado como recurso humano.","WMSV00102")
		Return Nil
	EndIf
	
	// Pesquisa quais funcoes o usuario exerce
	DCI->(DbSetOrder(1)) // DCI_FILIAL+DCI_CODFUN+STR(DCI_ORDFUN,2)+DCI_FUNCAO
	If DCI->(MsSeek(cSeekDCI:=xFilial('DCI')+__cUserID, .F.))
		While !DCI->(Eof()) .And. DCI->DCI_FILIAL+DCI->DCI_CODFUN == cSeekDCI .And. !Empty(DCI->DCI_FUNCAO)
			cDescFunc := Posicione("SRJ",1,xFilial("SRJ")+DCI->DCI_FUNCAO,"RJ_DESC")
			AAdd(aFuncoesWMS, {nOrdemFunc, DCI->DCI_FUNCAO, cDescFunc})
			DCI->(DbSkip())
		EndDo
	EndIf

	// Verifica se há funções
	If Len(aFuncoesWMS) == 0
		WmsMessage("Usuario [VAR01] sem Funcoes Cadastradas.","WMSV00103")
		Return Nil
	EndIf

	While !lSair
		
		cPedido := Space(FWTamSX3("C5_NUM")[1])

		VTCLear()
		VTClearBuffer()

		nProxLin := 1

		WMSVTCabec("Separacao Pedido", .F., .F., .T.)
		@ nProxLin, 00 VTSay PadR("Pedido", VTMaxCol())
		@ nProxLin, 10 VTGet cPedido Valid VlDPedido(@cPedido)
		nProxLin++

		VTRead()
		
		If VtLastKey() == 27
		   lSair := .T.
		   
		   Exit
		EndIf
		
		If Empty(cPedido)
		   Exit
		EndIf
		
		While !lSair
			
			aItemPV := BITEMPV(cPedido)
			
			If Empty(aItemPV)
				Exit
			EndIf 

			For nY := 1 To Len(aItemPV)
				nProxLin := 1

				VtClear()

				WMSVTCabec("Pedido: " + cPedido, .F., .F., .T.)

				nPos := VTaBrowse(1,,,,{"Produto", "Descricao","A Separar", "Qtd. PV", "Separado", "Local"},aItemPV,{15,15,10,10,10,03},,nPos)
				
				If VTLastkey() == 27
				   lSair := .T.

				   Exit
				EndIf
				
				VtClear()

				While !lSair
					lFinal   := .F.
					nProxLin := 1
					cProduto := Space(FWTamSX3("B1_COD")[1])
					cEndder  := Space(FWTamSX3("BE_LOCALIZ")[1])
					cLoteCtl := Space(FWTamSX3("B8_LOTECTL")[1])
					cLocal   := Space(FWTamSX3("B1_LOCPAD")[1])
					cUnitiza := Space(FWTamSX3("Z06_IDUNIT")[1])
					cCodBar  := Space(250)
					nSaldo   := 0
					cSeq     := aItemPV[nY,7]

					VtClear()

					WMSVTCabec("Informe os dados", .F., .F., .T.)
					@ nProxLin++,00 VTSay "Endereco: "
					@ nProxLin++,00 VtGet cEndder Pict "@!" Valid ValEnder(@cEndder)
					@ nProxLin++,00 VTSay "Produto: "
					@ nProxLin++,00 VtGet cCodBar Pict "@!" Valid ValPrdLot(@cProduto,@cLoteCtl,@nSaldo,@cCodBar, @cLocal, cEndder, aItemPV)
					
					VTRead()
					
					If VTLastkey() == 27
						Exit
					EndIf
					
					nProxLin := 1
					cDesc    := Alltrim(Posicione("SB1", 1, xFilial("SB1")+cProduto, "B1_DESC"))
					nQtde    := 0

					VtClear()

					WMSVTCabec("Informe os dados", .F., .F., .T.)
					@ nProxLin++,00 VTSay PadR("Produto: " + cProduto, VTMaxCol())
					@ nProxLin++,00 VTSay PadR(cDesc, VTMaxCol())
					@ nProxLin++,00 VTSay PadR("Lote: " + cLoteCtl, VTMaxCol())
					@ nProxLin++,00 VTSay PadR("Unitizador: " + cUnitiza, VTMaxCol())
					@ nProxLin++,00 VTSay PadR("A Separar: " + Alltrim(Transform(nSaldo, PesqPict("D12","D12_QTDORI"))), VTMaxCol())
					@ nProxLin++,00 VTSay "Quantidade"
					@ nProxLin++,00 VTGet nQtde Pict "@E 999,999.99" Valid VldQuant(cProduto, cLocal, cLoteCtl, cEndder, @nQtde, nSaldo)
					
					VTRead()
					
					If VTLastKey() != 27
						If nQtde > 0
							VTCLear()
							VTClearBuffer()

							nProxLin := 1
							cConf    := "S"
							cQtde    := Alltrim(Transform(nQtde, PesqPict("D14","D14_QTDEST")))

							WMSVTCabec("Separacao", .F., .F., .T.)
							@ nProxLin++,00 VTSay PadR("Produto: " + cProduto, VTMaxCol())
							@ nProxLin++,00 VTSay PadR(cDesc, VTMaxCol())
							@ nProxLin++,00 VTSay PadR("Lote: " + cLoteCtl, VTMaxCol())
							@ nProxLin++,00 VtSay "Quantidade: " VTGet cQtde When .F.
							@ nProxLin++,00 VtSay "Confirma (S/N): " VtGet cConf Pict "@!"

							VTRead()
							
							If VtLastKey() == 27
								Exit
							EndIf
							
							If cConf == "S"
								RecLock("Z06", .T.)
								  Replace Z06_FILIAL with FWxFilial("Z06")
								  Replace Z06_PEDIDO with cPedido
								  Replace Z06_PRODUT with cProduto
								  Replace Z06_LOCAL  with cLocal
								  Replace Z06_LOTECT with cLoteCtl
								  Replace Z06_ENDER  with cEndder
								  Replace Z06_QUANT  with nQtde
								  Replace Z06_DATA 	 with dDataBase
								  Replace Z06_HORA 	 with Time()
								  Replace Z06_SEQ	 with cSeq
								  Replace Z06_IDUNIT with cUnitiza
								  Replace Z06_CODOPE with __cUserID
								Z06->(MsUnLock())

								AtuZ05(cPedido, cProduto, cLocal, cSeq)
							Endif
						
						Endif
					Endif
					Exit
				EndDo

				VTClearBuffer()

				lFinal := u_VerFinSep(,,cPedido)
				
				If lFinal
					aError := {}
					VtClear()
					VtSay(2,0,"Executando Separacao, Aguarde...")
					u_SEPEXP01( , , , @aError,cPedido)
					
					If Empty(aError)
						VtSay(2,0,"Finalizando Separacao, Aguarde...")
						u_FIMEXP01(.F./*lJob*/, 1/*nOpc*/, ""/*cCarga*/, cSeq, cPedido, @aError)

						If Empty(aError)
							VtSay(2,0,"Montando Volume, Aguarde...")
							u_VOLEXP01(.F./*lJob*/, 1/*nOpc*/, /*cCarga*/, cSeq, cPedido, @aError)
						Endif
					Endif
					
					VTClear()
					
					If Empty(aError)
						WMSVTCabec("Separacao", .F., .F., .T.)
						@ 01, 00 VTSay PadR("Finalizada", VTMaxCol())
						@ 02, 00 VTSay "------------------- "
						@ 03, 00 VTSay PadR("Pedido.: "+cPedido, VTMaxCol())
						WMSVTRodPe()
					Else
						WMSVTCabec("Problema Separacao", .F., .F., .T.)
						
						//Imprimir a mensagem de erro completa
						nLinMsg := MLCount(aError[1,1],VTMaxCol())

						For nId := 1 To nLinMsg
							@ nId, 00 VTSay MemoLine(aError[1,1],VTMaxCol(),nId)
						Next

						@ nId++, 00 VTSay "------------------- "
						@ nId++, 00 VTSay PadR("Pedido.: "+cPedido, VTMaxCol())
						@ nId++, 00 VTSay "------------------- "
						WMSVTRodPe()
					Endif
				Endif
			Next
		EndDo
	EndDo
Return

//------------------------------------------------------------------------------------------------------------------------------------------------
Static Function VldQuant(cProduto, cLocal, cLoteCtl, cEndder, nQtde, nSaldo)

	Local lRet      := .T.
	Local cNumSerie := Space(FWTamSX3("D14_NUMSER")[1])
	Local cNumLote  := Space(FWTamSX3("D14_NUMLOT")[1])
	Local nSlD14    := WmsSldD14(cLocal,cEndder,cProduto,cNumSerie,cLoteCtl,cNumLote)
	Local nQtSep    := SldZ06(cLocal,cEndder,cProduto,cLoteCtl)
	Local nDisp     := nSlD14 - nQtSep

	If lRet .and. QtdComp(nQtde) > QtdComp(nSaldo)
		WmsMessage("Quantidade Informada maior que a Quantidade a Separar","QTSMAIOR")
		lRet := .F.
	Endif
	
	If lRet .and. QtdComp(nDisp) < QtdComp(nQtde)
		WmsMessage("Quantidade Informada maior que o saldo no endereco","NOSLDD14")
		lRet := .F.
	Endif
	
	If ! lRet
		nQtde := 0
	Endif

Return(lRet)

//-------------------------------------------
/*/ Função ValEnder

   Função para Validar o Endereço.

  @author Anderson Almeida (TOTVS NE)
  @since  22/08/2024	
/*/
//-------------------------------------------
Static Function ValEnder(cEndder)
  Local lRet := .T.

  If Empty(cEndder)
	 WmsMessage("Endereço é obrigatório.","NENDERPV")

	 lRet := .F.
   else
	 dbSelectArea("SBE")
	 SBE->(dbSetOrder(1))

	 If ! SBE->(dbSeek(FWxFilial("SBE") + PadR("07",FWTamSX3("BE_LOCAL")[1]) + PadR(cEndder,FWTamSX3("BE_LOCALIZ")[1])))
	    WMSMessage("Endereço não existe.","NENDERPV")

		lRet := .F.
	 EndIf
  EndIf
Return lRet

//--------------------------------------------------------------------------------------------------------------------------
Static Function ValPrdLot(cProduto, cLoteCtl, nSaldo, cCodBar, cLocal, cEndder, aItemPV)

	Local lRet      := .T.
	Local nPos      := 0
	Local nSlD14    := 0
	Local cNumSerie := Space(FWTamSX3("D14_NUMSER")[1])
	Local cNumLote  := Space(FWTamSX3("D14_NUMLOT")[1])
	Local nQtSep    := 0
	Local nDisp     := 0

	aCodBar := Strtokarr(cCodBar,"|")
	
	If Len(aCodBar) < 2
	   If ! Empty(aCodBar[1])
	      WmsMessage("QrCode informado invalido. ","NPRODCG")
       EndIf

	   lRet := .F.
	 else
   	   cProduto := aCodBar[1]

	   nPos := aScan(aItemPV, {|x| x[1] == cProduto})

	   If nPos > 0
   	      cLoteCtl := aCodBar[8]
	  	  cLocal   := aItemPV[nPos, 6]
		  nSaldo   := aItemPV[nPos, 3]
		  cUnitiza := IIf(Empty(aCodBar[12]),aCodBar[12],StrZero(Val(aCodBar[12]),FWTamSX3("Z06_IDUNIT")[1]))
		  nSlD14   := WmsSldD14(cLocal,cEndder,cProduto,cNumSerie,cLoteCtl,cNumLote)
		  nQtSep   := SldZ06(cLocal,cEndder,cProduto,cLoteCtl)
		  nDisp    := nSlD14 - nQtSep

		  If nDisp <= 0
		  	 WmsMessage("Sem saldo para o Produto/Lote informado ","NPRODCG")
			 lRet := .F.
		  Endif
	    Else
		  WmsMessage("Produto nao encontrado na Pedido","NPRODCG")
		  lRet := .F.
	   Endif
	EndIf
	
	If !lRet
		cCodBar := Space(250)
	Endif

Return(lRet)

//---------------------------------------------------------------------------------------------------------------------------
Static Function SldZ06(cLocal,cEndder,cProduto,cLoteCtl)

	Local aArea     := GetArea()
	Local cAliasZ06 := GetNextAlias()
	Local nQuant    := 0
	
	BeginSql Alias cAliasZ06
		SELECT SUM(Z06_QUANT) Z06_QUANT
		FROM %table:Z06% Z06
		WHERE Z06.Z06_FILIAL = %xFilial:Z06%
			AND Z06_PRODUT = %Exp:cProduto%
			AND Z06_LOCAL = %Exp:cLocal%
			AND Z06_LOTECT = %Exp:cLoteCtl%
			AND Z06_ENDER = %Exp:cEndder%
			AND Z06.%NotDel%
			AND Z06_IDDCF = ' '
	EndSql
	
	If (cAliasZ06)->(!Eof())
		nQuant := (cAliasZ06)->Z06_QUANT
	Endif
	(cAliasZ06)->(dbCloseArea())
	
	RestArea(aArea)

Return(nQuant)

//--------------------------------------------------------------------------------------------------------------------------
Static Function BITEMPV(cPedido)

	Local aArea     := GetArea()
	Local aZ05Sel   := {}
	Local cAliasZ05 := GetNextAlias()
	
	BeginSql Alias cAliasZ05
		SELECT Z05_SEQ, Z05_PRODUT, Z05_LOCAL, SUM(Z05_QUANT) Z05_QUANT, SUM(Z05_QUJE) Z05_QUJE
		FROM %table:Z05% Z05
		WHERE Z05.Z05_FILIAL = %xFilial:Z05%
			AND Z05.Z05_PEDIDO = %Exp:cPedido%
			AND Z05.Z05_QUANT > Z05.Z05_QUJE
			AND Z05.%NotDel%
		GROUP BY Z05_SEQ, Z05_PRODUT, Z05_LOCAL
		ORDER BY Z05_SEQ, Z05_PRODUT, Z05_LOCAL
	EndSql
	dbSelectArea(cAliasZ05)
	
	While !Eof()
		aadd(aZ05Sel, {(cAliasZ05)->Z05_PRODUT,;
						Alltrim(Posicione("SB1", 1, xFilial("SB1")+(cAliasZ05)->Z05_PRODUT, "B1_DESC")),;
						(cAliasZ05)->(Z05_QUANT-Z05_QUJE),;
						(cAliasZ05)->Z05_QUANT,;
						(cAliasZ05)->Z05_QUJE,;
						(cAliasZ05)->Z05_LOCAL,;
						(cAliasZ05)->Z05_SEQ})
		dbSkip()
	End
	(cAliasZ05)->(dbCloseArea())
	
	RestArea(aArea)

Return(aZ05Sel)

//--------------------------------------------------------------------------------------------------------------------------
Static Function VlDPedido(cPedido)

	Local lRet   := .T.
	Local aArea  := GetArea()
	Local aZ05Sel := {}
	Local cAliasZ05 := GetNextAlias()
	Local cAliasDCF := GetNextAlias()
	Local nPos   := 1
	Local cWhere    := "%"
	
	dbSelectArea("Z05")

	If !Empty(cPedido)
		cWhere += " AND DCF.DCF_DOCTO  = '" + cPedido + "'"
		cWhere += " AND DCF.DCF_ORIGEM = 'SC9'"
	Endif
	cWhere += "%"

	BeginSql Alias cAliasDCF
		SELECT DCF.DCF_DOCTO, DCF.DCF_CODPRO, DCF.DCF_LOCAL, DCF.DCF_QUANT, DCF.DCF_ID, DCF.DCF_SERIE
		FROM %table:DCF% DCF
		WHERE DCF.DCF_FILIAL = %xFilial:DCF%
			%Exp:cWhere%
			AND DCF.%NotDel%
	EndSql
	dbSelectArea(cAliasDCF)
	
	While (cAliasDCF)->(!Eof())
		
		If !Z05->(MSSeek(xFilial("Z05")+Pad("",FWTamSX3("Z05_CARGA")[1])+Pad("",FWTamSX3("Z05_SEQCAR")[1])+;
						 Pad((cAliasDCF)->DCF_DOCTO,FWTamSX3("Z05_PEDIDO")[1])+Pad((cAliasDCF)->DCF_SERIE,FWTamSX3("Z05_SEQ")[1])+;
						 Pad((cAliasDCF)->DCF_CODPRO,FWTamSX3("Z05_PRODUT")[1])+Pad((cAliasDCF)->DCF_LOCAL,FWTamSX3("Z05_LOCAL")[1]) ))
			
			RecLock("Z05",.T.)
				Z05->Z05_FILIAL := xFilial("Z05")
				Z05->Z05_PRODUT := (cAliasDCF)->DCF_CODPRO
				Z05->Z05_LOCAL  := (cAliasDCF)->DCF_LOCAL
				Z05->Z05_QUANT  := (cAliasDCF)->DCF_QUANT
				Z05->Z05_IDDCF  := (cAliasDCF)->DCF_ID
				Z05->Z05_SEQ    := (cAliasDCF)->DCF_SERIE
				Z05->Z05_PEDIDO := (cAliasDCF)->DCF_DOCTO
			Z05->(MsUnLock())

		EndIF 
		
		(cAliasDCF)->(dbSkip())
	End
	(cAliasDCF)->(dbCloseArea())

	cWhere := "%"

	If !Empty(cPedido)
		cWhere += " AND Z05.Z05_PEDIDO = '" + cPedido + "'"
	Endif
	cWhere += "%"
	
	BeginSql Alias cAliasZ05
		SELECT DISTINCT Z05_PEDIDO
		FROM %table:Z05% Z05
		WHERE Z05.Z05_FILIAL = %xFilial:Z05%
			AND Z05.Z05_QUANT > Z05.Z05_QUJE
			AND Z05.%NotDel%
			%Exp:cWhere%
		ORDER BY Z05_PEDIDO
	EndSql
	dbSelectArea(cAliasZ05)
	
	While (cAliasZ05)->(!Eof())
		aadd(aZ05Sel, {(cAliasZ05)->Z05_PEDIDO})
		(cAliasZ05)->(dbSkip())
	End
	
	If Len(aZ05Sel) > 0
		If Len(aZ05Sel) > 1
			VtClear()
			WMSVTCabec("Selecione Pedido", .F., .F., .T.)
			nPos := VTaBrowse(1,,,,{"Pedido"},aZ05Sel,{06},,nPos)
			If !(VTLastkey() == 27)
				cPedido := aZ05Sel[nPos, 1]
			Else
				lRet := .F.
			EndIf
		Else
			cPedido := aZ05Sel[1, 1]
		Endif
	Else
		WmsMessage("Nao encontrado pedido para separacao","NOCFSEP")
		lRet := .F.
	Endif
	(cAliasZ05)->(dbCloseArea())

	RestArea(aArea)
Return(lRet)

//--------------------------------------------------------------------------------------------------------------
Static Function AtuZ05(cPedido, cProduto, cLocal, cSeq)

	Local aArea     := GetArea()
	Local cAliasZ06 := GetNextAlias()
	Local nQuant    := 0
	
	BeginSql Alias cAliasZ06
		SELECT SUM(Z06_QUANT) Z06_QUANT
		FROM %table:Z06% Z06
		WHERE Z06.Z06_FILIAL = %xFilial:Z06%
			AND Z06_PEDIDO = %Exp:cPedido%
			AND Z06_PRODUT = %Exp:cProduto%
			AND Z06_LOCAL = %Exp:cLocal%
			AND Z06.%NotDel%
	EndSql
	
	If (cAliasZ06)->(!Eof())
		nQuant := (cAliasZ06)->Z06_QUANT
		dbSelectArea("Z05")
		Z05->(dbSetOrder(1))
		Z05->(dbSeek(xFilial("Z05")+Pad("",FWTamSX3("Z05_CARGA")[1])+Pad("",FWTamSX3("Z05_SEQCAR")[1])+;
					 Pad(cPedido,FWTamSX3("Z05_PEDIDO")[1])+Pad(cSeq,FWTamSX3("Z05_SEQ")[1])+;
					 Pad(cProduto,FWTamSX3("Z05_PRODUT")[1])+Pad(cLocal,FWTamSX3("Z05_LOCAL")[1]) ))

		While !Eof() .and. xFilial()+cPedido+cProduto+cLocal == Z05->(Z05_FILIAL+Z05_PEDIDO+Z05_PRODUT+Z05_LOCAL)
			nSaldoZ05 := Z05->Z05_QUANT - Z05->Z05_QUJE
			
			If nSaldoZ05 > 0
				If QtdComp(nSaldoZ05) > QtdComp(nQuant)
					RecLock("Z05", .F.)
						Replace Z05_QUJE with nQuant
					MsUnLock()
					Exit
				Else
					RecLock("Z05", .F.)
						Replace Z05_QUJE with Z05->Z05_QUANT
					MsUnLock()
					nQuant -= nSaldoZ05
				Endif
				If nQuant <= 0
					Exit
				Endif
			Endif
			dbSelectArea("Z05")
			dbSkip()
		End

	Endif

	(cAliasZ06)->(dbCloseArea())
	
	RestArea(aArea)

Return

//----------------------------------------------------------------------------------------------
User Function SEPEXP01(cCarga, cSeqCar, cSeq, aError, cPedido)

	Local aArea := GetArea()
	Local aDCF  := {}
	If !IsTelNet()
		Processa( {|lEnd| aDCF := SEPEXP02(cCarga, cSeqCar, cSeq, @aError, cPedido)}, "Aguarde...","Executando Serviço - Separação", .T. )
	Else
		aDCF := SEPEXP02(cCarga, cSeqCar, cSeq, @aError, cPedido)
	Endif
	RestArea(aArea)
Return

//----------------------------------------------------------------------------------------------
User Function VerFinSep(cCarga, cSeq, cPedido)

	Local aArea     := GetArea()
	Local lFim      := .F.
	Local cAliasZ05 := GetNextAlias()
	
	If ValType(cCarga) != "U"
		BeginSql Alias cAliasZ05
			SELECT Z05_CARGA, Z05_SEQ
			FROM %table:Z05% Z05
			WHERE Z05.Z05_FILIAL = %xFilial:Z05%
				AND Z05.Z05_CARGA = %Exp:cCarga%
				AND Z05.Z05_SEQ = %Exp:cSeq%
				AND Z05_QUANT > Z05_QUJE
				AND Z05.%NotDel%
		EndSql
	ElseIF ValType(cPedido) != "U"
		BeginSql Alias cAliasZ05
			SELECT Z05_CARGA, Z05_SEQ
			FROM %table:Z05% Z05
			WHERE Z05.Z05_FILIAL = %xFilial:Z05%
				AND Z05.Z05_PEDIDO = %Exp:cPedido%
				AND Z05_QUANT > Z05_QUJE
				AND Z05.%NotDel%
		EndSql
	EndIF 

	If (cAliasZ05)->(Eof())
		lFim := .T.
	Endif
	(cAliasZ05)->(dbCloseArea())
	
	Restarea(aArea)

Return(lFim)

//----------------------------------------------------------------------------------------------
User Function FIMEXP01(lJob, nOpc, cCarga, cSeq, cPedido, aError)

	Local aArea := GetArea()
	Default cPedido := CriaVar("C5_NUM", .F.)
	If lJob
		STARTJOB("u_FIMEXP02",getenvserver(),.F., cEmpAnt, cFilAnt, lJob, nOpc, cCarga, cSeq, cPedido, __cUserId, @aError)
	Else
		If !IsTelNet()
			Processa( {|lEnd| u_FIMEXP02(cEmpAnt, cFilAnt, lJob, nOpc, cCarga, cSeq, cPedido, __cUserId, @aError)}, "Aguarde...","Finalizando Serviço - Separação", .T. )
		Else
			u_FIMEXP02(cEmpAnt, cFilAnt, lJob, nOpc, cCarga, cSeq, cPedido, __cUserId, @aError)
		Endif
	Endif
	RestArea(aArea)
Return

//---------------------------------------------------------------------------------------------
User Function VOLEXP01(lJob, nOpc, cCarga, cSeq, cPedido, aError)

	Local aArea := GetArea()
	
	If lJob
		u_VOLEXP02(lJob, nOpc, cCarga, cSeq, cPedido, __cUserId, @aError)
	Else
		If !IsTelNet()
			Processa( {|lEnd| u_VOLEXP02(lJob, nOpc, cCarga, cSeq, cPedido, __cUserId, @aError)}, "Aguarde...","Executando Serviço - Separação", .T. )
		Else
			u_VOLEXP02(lJob, nOpc, cCarga, cSeq, cPedido, __cUserId, @aError)
		Endif
	Endif
	
	RestArea(aArea)
Return

//--------------------------------------------------------------------------------------------
User Function FIMEXP02(cEmpSep, cFilSep, lJob, nOpc, cCarga, cSeq, cPedido, cUserSep, aError)

	Local aArea     := {}
	Local cAliasD12 := GetNextAlias()
	Local cWhere    := "%"
	
	Default aError := {}
	
	If lJob
		RpcClearEnv()
		RpcSetEnv(cEmpSep, cFilSep,,,'WMS')
		__cUserId := cUserSep
	Else
		aArea := GetArea()
	Endif
	
	If nOpc == 1
		cWhere += " AND D12.D12_DOC = '" + cPedido + "'"
	Else
		cWhere += " AND D12.D12_CARGA = '" + cCarga + "'"
		cWhere += " AND D12.D12_SERIE = '" + cSeq + "'"
	Endif
	
	cWhere += "%"
	
	BeginSql Alias cAliasD12
		SELECT R_E_C_N_O_ RECD12
		FROM %table:D12% D12
		WHERE D12.D12_FILIAL = %xFilial:D12%
		AND D12_ORIGEM = 'SC9'
		AND D12_STATUS IN ('2', '3', '4')
		AND D12.%NotDel%
		%Exp:cWhere%
	EndSql

	While (cAliasD12)->(!Eof())
		nRecD12 := (cAliasD12)->RECD12
		dbSelectArea("D12")
		dbGoto(nRecD12)
		
		If D12->D12_STATUS <> "4"
			RecLock("D12", .F.)
			Replace D12_STATUS with "4"
			MsunLock()
		Endif
		
		If lJob
			u_FinalzD12(nRecD12) // Finaliza separação
		Else
			If !IsTelNet()
				Processa({|| u_FinalzD12(nRecD12)}, "Finalizando Serviço...","Aguarde....", .T. )
			Else
				u_FinalzD12(nRecD12)
			Endif
		Endif
		(cAliasD12)->(dbSkip())
	End

	(cAliasD12)->(dbCloseArea())
	
	If lJob
		u_VOLEXP01(lJob, nOpc, cCarga, cSeq, cPedido, @aError)		// Montagem de Volume conforme Z06
		RpcClearEnv()
	Else
		RestArea(aArea)
	Endif
Return

//--------------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------------
Static Function SEPEXP02(cCarga, cSeqCar, cSeq, aError, cPedido)

	Local aArea := GetArea()
	Local oOrdSerExe
	Local oRegraConv
	Local aOrdSerExe := {}
	Local cAliasZ05 := GetNextAlias()
	Local cAliasDCF := GetNextAlias()
	Local lContinua := .T.
	Local nI := 1
	Local cEndCons   := PADR(SuperGetMV('MV_XENDDES',.F.," "), FWTamSX3("BE_LOCALIZ")[1]) // Endereço para realizar a separação dos PVs
	
	If !Empty(cEndCons)
		
		lContinua := .F.
		
		If ValType(cCarga) != "U"
			BeginSql Alias cAliasDCF
				SELECT DCF_CODPRO, DCF_LOCAL, DCF_SERIE, SUM(DCF_QUANT) DCF_QUANT
				FROM %table:DCF% DCF
				WHERE DCF.DCF_FILIAL = %xFilial:DCF%
				AND DCF_CARGA = %Exp:cCarga%
				AND DCF_SERIE = %Exp:cSeq%
				AND DCF_ORIGEM = 'SC9'
				AND DCF_STSERV IN ('1', '2')
				AND DCF.%NotDel%
				GROUP BY DCF_CODPRO, DCF_LOCAL, DCF_SERIE
				ORDER BY DCF_CODPRO, DCF_LOCAL
			EndSql
		ElseIF ValType(cPedido) != "U"
			BeginSql Alias cAliasDCF
				SELECT DCF_CODPRO, DCF_LOCAL, DCF_SERIE, SUM(DCF_QUANT) DCF_QUANT
				FROM %table:DCF% DCF
				WHERE DCF.DCF_FILIAL = %xFilial:DCF%
				AND DCF_DOCTO = %Exp:cPedido%
				AND DCF_ORIGEM = 'SC9'
				AND DCF_STSERV IN ('1', '2')
				AND DCF.%NotDel%
				GROUP BY DCF_CODPRO, DCF_LOCAL, DCF_SERIE
				ORDER BY DCF_CODPRO, DCF_LOCAL
			EndSql
		EndIF 

		While (cAliasDCF)->(!Eof())
			
			lContinua := .F.
			cProduto := (cAliasDCF)->DCF_CODPRO
			cLocal   := (cAliasDCF)->DCF_LOCAL
			cSeq     := (cAliasDCF)->DCF_SERIE
			nQuant   := (cAliasDCF)->DCF_QUANT
			
			If ValType(cCarga) != "U"
				BeginSql Alias cAliasZ05
					SELECT SUM(Z05_QUJE) Z05_QUJE
					FROM %table:Z05% Z05
					WHERE Z05.Z05_FILIAL = %xFilial:Z05%
					AND Z05.Z05_CARGA = %Exp:cCarga%
					AND Z05.Z05_SEQCAR = %Exp:cSeqCar%
					AND Z05.Z05_SEQ = %Exp:cSeq%
					AND Z05.Z05_PRODUT = %Exp:cProduto%
					AND Z05.Z05_LOCAL = %Exp:cLocal%
					AND Z05.%NotDel%
				EndSql
			ElseIF ValType(cPedido) != "U"
				BeginSql Alias cAliasZ05
					SELECT SUM(Z05_QUJE) Z05_QUJE
					FROM %table:Z05% Z05
					WHERE Z05.Z05_FILIAL = %xFilial:Z05%
					AND Z05.Z05_PRODUT = %Exp:cProduto%
					AND Z05.Z05_LOCAL = %Exp:cLocal%
					AND Z05.Z05_PEDIDO = %Exp:cPedido%
					AND Z05.Z05_SEQ = %Exp:cSeq%
					AND Z05.%NotDel%
				EndSql
			EndIF

			If QtdComp(nQuant) == QtdComp((cAliasZ05)->Z05_QUJE)
				lContinua := .T.
			Else
				lContinua := .F.
			Endif

			(cAliasZ05)->(dbCloseArea())
			
			If !lContinua
				Exit
			Endif
			
			(cAliasDCF)->(dbSkip())
		End
		
		(cAliasDCF)->(dbCloseArea())
	Endif
	
	If lContinua
		If ValType(cCarga) != "U"
			BeginSql Alias cAliasDCF
				SELECT R_E_C_N_O_ RECDCF
				FROM %table:DCF% DCF
				WHERE DCF.DCF_FILIAL = %xFilial:DCF%
				AND DCF_CARGA = %Exp:cCarga%
				//AND DCF_XSEQ = %Exp:cSeq%
				AND DCF_ORIGEM = 'SC9'
				AND DCF_STSERV IN ('1','2')
				AND DCF.%NotDel%
				ORDER BY DCF_CODPRO, DCF_LOCAL
			EndSql
		ElseIF ValType(cPedido) != "U"
			BeginSql Alias cAliasDCF
				SELECT R_E_C_N_O_ RECDCF
				FROM %table:DCF% DCF
				WHERE DCF.DCF_FILIAL = %xFilial:DCF%
				AND DCF_DOCTO = %Exp:cPedido%
				AND DCF_ORIGEM = 'SC9'
				AND DCF_STSERV IN ('1','2')
				AND DCF.%NotDel%
				ORDER BY DCF_CODPRO, DCF_LOCAL
			EndSql
		EndIF 

		While !(cAliasDCF)->(Eof())
			aAdd( aOrdSerExe,(cAliasDCF)->RECDCF)
			(cAliasDCF)->(dbSkip())
		End
		
		dbSelectArea(cAliasDCF)
		dbCloseArea()
	End
	
	If Len(aOrdSerExe) > 0
		
		oRegraConv := WMSBCCRegraConvocacao():New()
		oOrdSerExe := WMSDTCOrdemServicoExecute():New()
		WMSCTPENDU() // Cria as temporárias - FORA DA TRANSAÇÃO
		ProcRegua(Len(aOrdSerExe))
		oOrdSerExe:SetArrLib(oRegraConv:GetArrLib())

		For nI := 1 To Len(aOrdSerExe)
			oOrdSerExe:GoToDCF(aOrdSerExe[nI])
			If (oOrdSerExe:GetStServ() $ "1|2") .And. Empty(oOrdSerExe:cStRadi)
				IncProc(oOrdSerExe:GetServico()+" - "+If(Empty(oOrdSerExe:GetCarga()),Trim(oOrdSerExe:GetDocto())+"/"+Trim(oOrdSerExe:GetSerie()),Trim(oOrdSerExe:GetCarga()))+"/"+Trim(oOrdSerExe:oProdLote:GetProduto()))
				If !oOrdSerExe:ExecuteDCF()
					aadd(aError, {oOrdSerExe:GetErro()})
				Endif
			EndIf
		Next
		
		If !IsTelNet()
			// Verifica as movimentações liberadas para verificar se há reabastecimentos gerados
			oOrdSerExe:ChkOrdReab()
			// O wms devera avaliar as regras para convocacao do servico e disponibilizar os
			// registros do D12 para convocacao
			oRegraConv:LawExecute()
			// Exibe as mensages de erro na ordem de serviço
			// Aviso
			oOrdSerExe:ShowWarnig()
			//-- Exibe as mensagens de reabastecimento
			
			If SuperGetMV('MV_WMSEMRE',.F.,.T.) .And. !Empty(oOrdSerExe:aWmsReab)
				TmsMsgErr(oOrdSerExe:aWmsReab, "Reabastecimentos pendentes:") //
			EndIf
			
			If Len(oOrdSerExe:GetLogSld()) > 0 .And. (oOrdSerExe:HasLogSld() .Or. SuperGetMV('MV_WMSRLSA',.F.,.F.))
				cMensagem := ""
				// Se a impressão é forçada, não mostra a mensagem de OS não atendida
				If !SuperGetMV('MV_WMSRLSA',.F.,.F.)
					cMensagem := "Existem ordens de serviço de apanhe que não foram totalmente atendidas."+CRLF //
				EndIf
				cMensagem += "Deseja imprimir o relatório de busca de saldo para o apanhe?" //
				If WmsQuestion(cMensagem,"WMSA15003")
					WMSR111(oOrdSerExe:GetLogSld())
				EndIf
			EndIf
			
			If Len(oOrdSerExe:GetLogEnd()) > 0 .And. (oOrdSerExe:HasLogEnd() .Or. SuperGetMV('MV_WMSRLEN',.F.,.F.))
				cMensagem := ""
				// Se a impressão é forçada, não mostra a mensagem de OS não atendida
				If !SuperGetMV('MV_WMSRLEN',.F.,.F.)
					cMensagem := "Existem ordens de serviço de endereçamento que não foram totalmente atendidas."+CRLF //
				EndIf
				cMensagem += "Deseja imprimir o relatório de busca de endereços para a armazenagem?"
				If WmsQuestion(cMensagem,"WMSA15004")
					WMSR121(oOrdSerExe:GetLogEnd())
				EndIf
			EndIf
			
			If Len(oOrdSerExe:GetLogUni()) > 0 .And. (oOrdSerExe:HasLogUni() .Or. SuperGetMV('MV_WMSRLEN',.F.,.F.))
				cMensagem := ""
				// Se a impressão é forçada, não mostra a mensagem de OS não atendida
				If !SuperGetMV('MV_WMSRLEN',.F.,.F.)
					cMensagem := "Existem ordens de serviço de endereçamento unitizado que não foram totalmente atendidas."+CRLF //
				EndIf
				cMensagem += "Deseja imprimir o relatório de busca de endereços para a armazenagem unitizada?" //
				If WmsQuestion(cMensagem,"WMSA15004")
					WMSR125(oOrdSerExe:GetLogUni())
				EndIf
			EndIf
		Endif
		
		// Verifica as movimentações liberadas para verificar se há reabastecimentos gerados
		oOrdSerExe:ChkOrdReab()
		// O wms devera avaliar as regras para convocacao do servico e disponibilizar os
		// registros do D12 para convocacao
		oRegraConv:LawExecute()	

		WMSDTPENDU() // Destroy as temporárias - FORA DA TRANSAÇÃO
		oRegraConv:Destroy()
		oOrdSerExe:Destroy()
	
	ENDIF
	
	RestArea(aArea)

Return(aOrdSerExe)
//-------------------------------------------------------------------------------------------------------------------------------------

User Function VOLEXP02(lJob, nOpc, cCarga, cSeq, cPedido, cUserVol, aError)

	Local aArea       := {}
	Local cAliasZ06   := GetNextAlias()
	Local cAliasDCT   := GetNextAlias()
	Local oMntVolItem
	Local aCodMNT     := {}
	Local nI          := 1
	Local aProd       := {}
	Local aProdutos   := {}
	Local cSubLote    := ""
	Local cWhere      := "%"
	
	Default aError    := {}
	Default cCarga    := Pad("",FWTamSX3("DCS_CARGA")[1])
	Default cSeq      := Pad("",FWTamSX3("Z06_SEQ")[1])
	
	If !lJob
		aArea := GetArea()
	Endif
	
	oMntVolItem := WMSDTCMontagemVolumeItens():New()
	cSubLote    := CriaVar("B8_NUMLOTE", .F.)
	
	If nOpc == 2
		dbSelectArea("DCS")
		dbSetOrder(2)
		dbSeek(xFilial()+cCarga)
		While !Eof() .and. xFilial("DCS")+cCarga == DCS->(DCS_FILIAL+DCS_CARGA)
			If DCS->DCS_QTSEPA > DCS->DCS_QTEMBA
				aadd(aCodMNT, DCS->DCS_CODMNT)
			Endif
			dbSkip()
		End
	Else
		dbSelectArea("DCS")
		dbSetOrder(2)
		dbSeek(xFilial()+cCarga+cPedido)
		While !Eof() .and. xFilial("DCS")+cCarga+cPedido == DCS->(DCS_FILIAL+DCS_CARGA+DCS_PEDIDO)
			If DCS->DCS_QTSEPA > DCS->DCS_QTEMBA
				aadd(aCodMNT, DCS->DCS_CODMNT)
			Endif
			dbSkip()
		End
	Endif

	BeginSql Alias cAliasZ06
		SELECT Z06_VOLUME, Z06_PRODUT, Z06_LOCAL, Z06_LOTECT, SUM(Z06_QUANT) Z06_QUANT 
		FROM %table:Z06% Z06
		WHERE Z06_FILIAL = %xFilial:Z06%
		AND Z06_CARGA = %Exp:cCarga%
		AND Z06_PEDIDO = %Exp:cPedido%
		AND Z06_SEQ = %Exp:cSeq%
		AND Z06_VOLUME <> ' '
		AND Z06.%NotDel%
		GROUP BY Z06_VOLUME, Z06_PRODUT, Z06_LOCAL, Z06_LOTECT
		ORDER BY Z06_VOLUME, Z06_PRODUT, Z06_LOCAL, Z06_LOTECT
	EndSql

	While (cAliasZ06)->(!Eof())
		
		cVolume := (cAliasZ06)->Z06_VOLUME
		
		While (cAliasZ06)->(!Eof()) .and. cVolume == (cAliasZ06)->Z06_VOLUME
			cProduto := (cAliasZ06)->Z06_PRODUT
			cLocal   := (cAliasZ06)->Z06_LOCAL
			cLote    := (cAliasZ06)->Z06_LOTECT
			nQuant   := (cAliasZ06)->Z06_QUANT
			cWhere   := "%"
			
			If nOpc == 2
				cWhere += " AND DCT_CARGA = '" + cCarga + "'"
				cWhere += " AND DCT_CODPRO = '" + cProduto + "'"
				cWhere += " AND DCT_LOTE = '" + cLote + "'"
				//cWhere += " AND DCT_QTSEPA > (DCT_QTEMBA + DCT_XQRAT)"
			Else
				cWhere += " AND DCT_CARGA = '" + cCarga + "'"
				cWhere += " AND DCT_PEDIDO = '" + cPedido + "'"
				cWhere += " AND DCT_CODPRO = '" + cProduto + "'"
				cWhere += " AND DCT_LOTE = '" + cLote + "'"
				//cWhere += " AND DCT_QTSEPA > (DCT_QTEMBA + DCT_XQRAT)"
			Endif
			
			cWhere += "%"
			
			If Len(aCodMNT) > 0
				For nI:=1 to Len(aCodMNT)
					
					BeginSql Alias cAliasDCT
						SELECT R_E_C_N_O_ RECDCT 
						FROM %table:DCT% DCT
						WHERE DCT_FILIAL = %xFilial:DCT%
						AND DCT_CODMNT = %Exp:aCodMNT[nI]%
						AND DCT.%NotDel%
						%Exp:cWhere%
						ORDER BY DCT_PEDIDO
					EndSql
					
					While (cAliasDCT)->(!Eof())
						
						If QtdComp(nQuant) > 0
							nRecDCT  := (cAliasDCT)->RECDCT
							dbSelectArea("DCT")
							dbGoto(nRecDCT)
							nQtdSepa := DCT->DCT_QTSEPA
							nQtdEmba := DCT->DCT_QTEMBA
							nQtRate  := 0 //DCT->DCT_XQRAT
							cPedido  := DCT->DCT_PEDIDO
							cCodMNT  := DCT->DCT_CODMNT
							nDisp    := nQtdSepa - nQtdEmba - nQtRate
							
							While QtdComp(nDisp) > 0
								If QtdComp(nDisp) >= QtdComp(nQuant)
									AAdd(aProd, {cVolume, cPedido, cCodMNT, cProduto, cLote, cSubLote, nQuant, cProduto})
									nDisp -= nQuant
									RecLock("DCT", .F.)
									//Replace DCT_XQRAT with DCT_XQRAT+nQuant
									MsUnLock()
									nQuant := 0
									Exit
								Else
									AAdd(aProd, {cVolume, cPedido, cCodMNT, cProduto, cLote, cSubLote, nDisp, cProduto})
									RecLock("DCT", .F.)
									//Replace DCT_XQRAT with DCT_XQRAT+nDisp
									MsUnLock()
									nQuant -= nDisp
									nDisp := 0
								Endif
							End

						Endif
						(cAliasDCT)->(dbSkip())
					End
					(cAliasDCT)->(dbCloseArea())
				Next
			Endif
			(cAliasZ06)->(dbSkip())
		End
	End

	(cAliasZ06)->(dbCloseArea())
	
	If Len(aProd) > 0
		ASORT(aProd, , , { | x,y | x[1]+x[2] < y[1]+y[2] } )
		
		For nI:=1 to Len(aProd)
			cVolume := aProd[nI,1]
			cPedido := aProd[nI,2]
			cCodMNT := aProd[nI,3]
			aProdutos := {}
			
			While Len(aProd) >= nI .and. cVolume == aProd[nI,1] .and. cPedido == aProd[nI,2]
				cProduto:= aProd[nI,4]
				cLote   := aProd[nI,5]
				cSubLote:= aProd[nI,6]
				nQtdVol := aProd[nI,7]
				dbSelectArea("DCS")
				dbSetOrder(1)
				dbSeek(xFilial()+cCodMNT+cPedido)
				dbSelectArea("DCT")
				dbSetOrder(1)
				If dbSeek(xFilial()+cCodMnt+cCarga+cPedido+cProduto+cProduto+cLote)
					If DCT->DCT_STATUS $ "1/2"
						nSaldo := DCT->DCT_QTORIG - DCT->DCT_QTEMBA
						If QtdComp(nSaldo) >= QtdComp(nQtdVol)
							AAdd(aProdutos, {cProduto, cLote, cSubLote, nQtdVol, cProduto})
						Endif
					Endif
				End
				nI++
			End
			
			nI--
			
			If Len(aProdutos) > 0
				oMntVolItem:oMntVol:SetCodMnt(cCodMnt)
				oMntVolItem:oVolume:SetCodVol(cVolume)
				oMntVolItem:SetCarga(cCarga)
				oMntVolItem:SetPedido(cPedido)
				oMntVolItem:SetCodMnt(cCodMnt)
				If !oMntVolItem:MntPrdVol(aProdutos)
					If !lJob
						If IsTelNet()
							WMSVTAviso("WMSV08102",oMntVolItem:GetErro())
						Else
							WmsMessage(oMntVolItem:GetErro(),"WMSV08102")
						Endif
					Endif
					lContinua := .F.
				Endif
			Endif
		
		Next
	Endif
	
	If !lJob
		RestArea(aArea)
	Endif

Return
