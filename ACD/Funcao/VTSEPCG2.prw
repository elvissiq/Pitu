#INCLUDE "PROTHEUS.CH"
#INCLUDE "APVT100.CH"
#Include 'FWMVCDef.ch'

/*/{Protheus.doc} VTSEPCG2
Rotina para realizar a separação por Carga na Expedição
@type function
@version 1.0
@author Elvis Siqueira
@since 25/04/2024
/*/
//-------------------------------------------------------------------------------------------------------------------------------------------
User Function VTSEPCG2

	Local lSair       := .F.
	Local cCarga      := Space(TamSx3("DAK_COD")[1])
	Local cSeq        := Space(TamSx3("Z05_SEQ")[1])
	Local aItemPV     := {}
	Local nPos        := 0
	Local nProxLin    := 1
	Local cLoteCtl    := Space(TamSx3("B8_LOTECTL")[1])
	Local cProduto    := Space(TamSx3("B1_COD")[1])
	Local cCodBar     := Space(128)
	Local cLocal      := Space(TamSx3("B1_LOCPAD")[1])
	Local cEndder     := Space(TamSx3("D14_ENDER")[1])
	Local cSeekDCI    := ''
	Local nOrdemFunc  := 0
	Local aFuncoesWMS := {}
	Local cVolume  	  := Space(TamSx3("DCU_CODVOL")[1])
	Local nPosD12     := 0
	Local cMensagem   := "Gera Novo Volume ?"
	Local lGeraVol    := .F.
	Local cPedido     := Space(TamSx3("C5_NUM")[1])
	Local cCliente    := Space(TamSx3("A1_COD")[1])
	Local cLoja       := Space(TamSx3("A1_LOJA")[1])
	Local aError 	  := {}
	
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
		cCarga    := Space(TamSx3("DAK_COD")[1])
		lGeraVol  := .F.
		cVolume   := Space(TamSx3("DCU_CODVOL")[1])
		VTCLear()
		VTClearBuffer()
		nProxLin := 1
		WMSVTCabec("Separacao por Carga", .F., .F., .T.)
		@ nProxLin, 00 VTSay PadR("Carga", VTMaxCol())
		@ nProxLin, 10 VTGet cCarga Valid VlDCarga(@cCarga, @cSeq)
		nProxLin++
		VTRead()
		
		If VtLastKey() == 27
			Exit
		EndIf
		
		If Empty(cCarga) .or. Empty(cSeq)
			Exit
		EndIf
		
		While !lSair
			aItemPV  := BITEMPV(cCarga, cSeq)
			
			If Len(aItemPV) > 0
				nProxLin := 1
				VtClear()
				WMSVTCabec("Produtos a Separar", .F., .F., .T.)
				nPos := VTaBrowse(1,,,,{"Local", "Endereco", "Produto", "Descricao", "Lote", "Palete", "Original", "Lido", "Registro" },aItemPV,{03, 15, 10, 30, 10, 10, 10, 10, 10},,nPos)
				
				If VTLastkey() == 27
					Exit
				EndIf
				
				cLocal := aItemPV[1,1]
				VtClear()
				
				If WmsQuestion(cMensagem)
					If !u_PV081Vol(@cVolume)
						Exit
					EndIf
				Else
					If !lGeraVol
						WMSVTAviso("Cancelado", "Necessário geracao do Volume.")
						Exit
					Endif
				Endif
				
				While !lSair
					nProxLin := 1
					cProduto := Space(TamSx3("B1_COD")[1])
					cLoteCtl := Space(TamSx3("B8_LOTECTL")[1])
					cCodBar  := Space(128)
					cEndder  := Space(TamSx3("D14_ENDER")[1])
					nSaldo   := 0
					nPosD12  := 0
					VtClear()
					WMSVTCabec("Código de barras", .F., .F., .T.)
					@ nProxLin++,00 VTSay "Volume: " + cVolume
					@ nProxLin++,00 VTSay "Endereco: "
					@ nProxLin++,00 VtGet cEndder Pict "@!" Valid ValEndDS(cLocal, @cEndder, aItemPV)
					@ nProxLin++,00 VTSay "Codigo Barras: "
					@ nProxLin++,00 VtGet cCodBar Pict "@!" Valid ValPrdLot(@cProduto,@cLoteCtl,@nSaldo,@cCodBar, cLocal, cEndder, aItemPV, @nPosD12)
					VTRead()
					
					If VTLastkey() == 27
						Exit
					EndIf
					
					aRecD12 := aItemPV[nPosD12, 9]
					dbSelectArea("D12")
					dbgoto(aRecD12)
					cProduto := D12->D12_PRODUT
					cLoteCtl := D12->D12_LOTECT
					nSaldo   := D12->D12_QTDORI - D12->D12_QTDLID
					cPedido  := D12->D12_DOC
					cCliente := D12->D12_CLIFOR
					cLoja    := D12->D12_LOJA
					nProxLin := 1
					cDesc    := Alltrim(Posicione("SB1", 1, xFilial("SB1")+cProduto, "B1_DESC"))
					nQtde    := 0
					VtClear()
					WMSVTCabec("Confirme a Quantidade", .F., .F., .T.)
					@ nProxLin++,00 VTSay PadR("Produto: " + cProduto, VTMaxCol())
					@ nProxLin++,00 VTSay PadR(cDesc, VTMaxCol())
					@ nProxLin++,00 VTSay PadR("Lote: " + cLoteCtl, VTMaxCol())
					@ nProxLin++,00 VTSay PadR("A Separar: " + Alltrim(Transform(nSaldo, PesqPict("D12","D12_QTDORI"))), VTMaxCol())
					@ nProxLin++,00 VTSay "Quantidade"
					@ nProxLin++,00 VTGet nQtde Pict "@E 999,999.99" Valid VldQuant(@nQtde, nSaldo)
					VTRead()
					
					If VTLastKey() != 27
						
						If nQtde > 0
							VTCLear()
							VTClearBuffer()
							nProxLin := 1
							cConf    := "S"
							cQtde := Alltrim(Transform(nQtde, PesqPict("D14","D14_QTDEST")))
							WMSVTCabec("Separacao", .F., .F., .T.)
							@ nProxLin++,00 VTSay PadR("Produto: " + cProduto, VTMaxCol())
							@ nProxLin++,00 VTSay PadR(cDesc, VTMaxCol())
							@ nProxLin++,00 VTSay PadR("Lote: " + cLoteCtl, VTMaxCol())
							@ nProxLin++,00 VtSay "Quantidade: "	 VTGet cQtde When .F.
							@ nProxLin++,00 VtSay "Confirma (S/N): " VtGet cConf Pict "@!"
							VTRead()
							
							If VtLastKey() == 27
								Exit
							EndIf
							
							If cConf == "S"
								dbSelectArea("D12")
								RecLock("D12", .F.)
								Replace D12_STATUS with "3"
								MsUnLock()
								dbSelectArea("Z06")
								RecLock("Z06", .T.)
								Replace Z06_FILIAL with xFilial("Z06"),;
										Z06_CARGA with cCarga,;
										Z06_SEQ with cSeq,;
										Z06_PRODUT with cProduto,;
										Z06_LOCAL with cLocal,;
										Z06_LOTECT with cLoteCtl,;
										Z06_ENDER with cEndder,;
										Z06_QUANT with nQtde,;
										Z06_DATA with dDataBase,;
										Z06_HORA with Time(),;
										Z06_VOLUME with cVolume,;
										Z06_CODOPE with __cUserID
								MsUnLock()
								AtuSZ5(cCarga, cSeq, cProduto, cLocal)
							Endif

						Endif
						lGeraVol := .T.
					Endif
					Exit
				End
				
				VTClearBuffer()
				
				If !Empty(cVolume)
					If WmsQuestion("Imprimir Etiqueta Volume?")
						WMSV081Eti(cCarga, cVolume, cPedido, cCliente, cLoja)
					Endif
				Endif
			
			Else
				lFinal := u_VerFinSep(cCarga, cSeq)
				
				If lFinal
					aError := {}
					VTClear()
					VTMsg("Finalizando Separacao...") // Processando
					u_FIMEXP01(cCarga, cSeq, @aError)
					
					If Empty(aError)
						VTClear()
						VTMsg("Montando Volume, Aguarde...")
						u_VOLEXP01(cCarga, cSeq, @aError)
					Endif
					
					VTClear()
					
					If Empty(aError)
						WMSVTCabec("Separacao", .F., .F., .T.)
						@ 01, 00 VTSay PadR("Finalizada", VTMaxCol())
						@ 02, 00 VTSay "------------------- "
						@ 03, 00 VTSay PadR("Carga.:"+cCarga + "/" + cSeq, VTMaxCol())
						WMSVTRodPe()
					Else
						WMSVTCabec("Problema Separacao", .F., .F., .T.)
						@ 01, 00 VTSay PadR("NAO Finalizada", VTMaxCol())
						@ 02, 00 VTSay "------------------- "
						@ 03, 00 VTSay PadR("Ocorreram problemas", VTMaxCol())
						@ 03, 00 VTSay PadR("Carga.:"+cCarga + "/" + cSeq, VTMaxCol())
						WMSVTRodPe()
					Endif
				Endif
				Exit
			Endif
		End
	End

Return

//----------------------------------------------------------
// WMSV081Eti
// Imprime etiqueta volume
//----------------------------------------------------------
Static Function WMSV081Eti(cCarga, cVolume, cPedido, cCliente, cLoja)
	Local lRet      := .T.
	Local aItens    := {}
	Local cAliasZ06 := GetNextAlias()
	Local cLocImp   := Space(TamSX3("CB5_CODIGO")[01])
	Local cImpVol	:= SuperGetMV('PC_IMPVOL', .F., "EXP01")

		// Caminho da impressão
		If Empty(cImpVol)
			VtClear()
			@ 00,00 VtSay "Informe o local"
			@ 01,00 VtSay "de Impressao:"
			@ 02,00 VtGet cLocImp Picture "@!"
			VtRead()
			
			If VtLastkey() == 27
				lRet := .F.
			EndIf
			
			If lRet
				If !CB5SetImp(cLocImp,IsTelNet())
					WMSVTAviso("WMSV08116","Local de impressao invalido!") // 
					lRet := .F.
				EndIf
			EndIf
		
		ElseIf !CB5SetImp(cImpVol,IsTelNet())
			WMSVTAviso("WMSV08117","Local de impressao invalido!") // 
			lRet := .F.
		EndIf
		
		If lRet
			
			BeginSql Alias cAliasZ06
				SELECT Z06_PRODUT, Z06_LOTECT, Z06_QUANT, Z06_CARGA
				FROM %table:Z06% Z06
				WHERE Z06.Z06_FILIAL = %xFilial:Z06%
					AND Z06_VOLUME = %Exp:cVolume%
					AND Z06_CARGA = %Exp:cCarga%
					AND Z06.%NotDel%
			EndSql
			
			If (cAliasZ06)->(!Eof())
				
				Do While (cAliasZ06)->(!Eof())
					(cAliasZ06)->(aAdd(aItens,{Z06_PRODUT,Z06_QUANT,cVolume,Z06_LOTECT," ",Z06_CARGA, cPedido, cCliente, cLoja}))
					(cAliasZ06)->(dbSkip())
				EndDo
				
				WMSR410ETI(aItens,.T.,cLocImp)
				MSCBCLOSEPRINTER()
			Else
				WMSVTAviso("WMSV08151","Não há etiquetas de volume pendentes de impressão! Para re-impressão utilize o monitor de volumes de expedição") // 
			EndIf
			(cAliasZ06)->(dbCloseArea())
		EndIf
		
		If !lRet
			VtKeyboard(Chr(20))
		EndIf

Return

//------------------------------------------------------------------------------------------------------------------------------------------------
Static Function VldQuant(nQtde, nSaldo)

	Local lRet := .T.
	
	If lRet .and. QtdComp(nQtde) > QtdComp(nSaldo)
		WmsMessage("Quantidade Informada maior que a Quantidade a Separar","QTSMAIOR")
		lRet := .F.
	Endif
	
	If !lRet
		nQtde := 0
	Endif

Return(lRet)

//--------------------------------------------------------------------------------------------------------------------------
Static Function ValEndDS(cLocal, cEndder, aItemPV)

	Local lRet := .T.
	Local aArea := GetArea()
	Local nPos := 0
	
	If !Empty(cEndder)
		dbSelectArea("SBE")
		dbSetOrder(1)
		
		If dbSeek(xFilial()+cLocal+cEndder)
			nPos := aScan(aItemPV, {|x| x[2] == cEndder})
			If nPos == 0
				WmsMessage("Endereco Informado nao esta na lista de separacao","NOENDSEP")
				lRet := .F.
			Endif

		Else
			lRet := .F.
		Endif
	Else
		lRet := .F.
	Endif
	
	RestArea(aArea)

Return(lRet)

//--------------------------------------------------------------------------------------------------------------------------
Static Function ValPrdLot(cProduto, cLoteCtl, nSaldo, cCodBar, cLocal, cEndder, aItemPV, nPosD12)
	//{"Endereco", "Produto", "Descricao", "Lote", "Palete", "Original", "Lido", "Registro" }
	Local lRet   := .T.
	Local cBarra := UPPER(Alltrim(cCodBar))
	Local nAT    := AT("Z", cBarra)
	
	If nAT == 0
		nPosD12 := aScan(aItemPV, {|x| Alltrim(x[6]) == cBarra})
		If nPosD12 == 0
			lRet := .F.
			WmsMessage("Produto nao encontrado na carga","NPRODCGID")
		Endif
	Else
		cProduto := Padr(Substr(cBarra, 1, nAT - 1), TAMSX3("B1_COD")[1])
		cLoteCtl := Padr(Substr(cBarra, nAT + 1), TAMSX3("B8_LOTECTL")[1])
		nPosD12 := aScan(aItemPV, {|x| x[3]+x[5] == cProduto+cLoteCtl})
		If nPosD12 == 0
			lRet := .F.
			WmsMessage("Produto nao encontrado na carga","NPRODCGPR")
		Endif
	Endif
	
	If !lRet
		cCodBar := Space(128)
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
User Function VerFinSep(cCarga, cSeq)

	Local aArea     := GetArea()
	Local lFim      := .F.
	Local cAliasZ05 := GetNextAlias()
	
	BeginSql Alias cAliasZ05
		SELECT Z05_CARGA, Z05_SEQ
		FROM %table:Z05% Z05
		WHERE Z05.Z05_FILIAL = %xFilial:Z05%
			AND Z05.Z05_CARGA = %Exp:cCarga%
			AND Z05.Z05_SEQ = %Exp:cSeq%
			AND Z05_QUANT > Z05_QUJE
			AND Z05.%NotDel%
	EndSql
	
	If (cAliasZ05)->(Eof())
		lFim := .T.
	Endif
	(cAliasZ05)->(dbCloseArea())
	
	Restarea(aArea)

Return(lFim)

//--------------------------------------------------------------------------------------------------------------------------
Static Function BITEMPV(cCarga, cSeq, cLocal)

	Local aArea     := GetArea()
	Local aD12Sel   := {}
	Local cAliasD12 := GetNextAlias()
	
	BeginSql Alias cAliasD12
		SELECT D12_LOCORI, D12_PRODUT, D12_LOTECT, D12_IDUNIT, D12_QTDORI, D12_QTDLID, D12_ENDORI, R_E_C_N_O_ D12REC
		FROM %table:D12% D12
		WHERE D12.D12_FILIAL = %xFilial:D12%
			AND D12.D12_CARGA = %Exp:cCarga%
			AND D12.D12_XSEQ = %Exp:cSeq%
			AND D12.D12_STATUS = '4'
			AND D12.D12_ORIGEM = 'SC9'
			AND D12.%NotDel%
		ORDER BY D12_LOCORI, D12_ENDORI, D12_PRODUT, D12_LOTECT
	EndSql
	TcSetField(cAliasD12,'D12_QTDORI','N',TamSX3('D12_QTDORI')[1],TamSX3('D12_QTDORI')[2])
	TcSetField(cAliasD12,'D12_QTDLID','N',TamSX3('D12_QTDLID')[1],TamSX3('D12_QTDLID')[2])
	dbSelectArea(cAliasD12)
	
	While !Eof()
		aadd(aD12Sel, {(cAliasD12)->D12_LOCORI, (cAliasD12)->D12_ENDORI, (cAliasD12)->D12_PRODUT, Alltrim(Posicione("SB1", 1, xFilial("SB1")+(cAliasD12)->D12_PRODUT, "B1_DESC")), (cAliasD12)->D12_LOTECT, (cAliasD12)->D12_IDUNIT, (cAliasD12)->D12_QTDORI, (cAliasD12)->D12_QTDLID, (cAliasD12)->D12REC})
		dbSkip()
	End
	(cAliasD12)->(dbCloseArea())

	RestArea(aArea)
Return(aD12Sel)
//--------------------------------------------------------------------------------------------------------------------------
Static Function VlDCarga(cCarga, cSeq)

	Local lRet      := .T.
	Local aArea     := GetArea()
	Local aD12Sel   := {}
	Local cAliasD12 := GetNextAlias()
	Local nPos      := 1
	
	BeginSql Alias cAliasD12
		SELECT DISTINCT D12_CARGA, D12_XSEQ, D12_CLIFOR, D12_LOJA
		FROM %table:D12% D12
		WHERE D12.D12_FILIAL = %xFilial:D12%
			AND D12.D12_SERVIC = %Exp:cSrvVSP%
			AND D12.D12_STATUS = '4'
			AND D12.D12_ORIGEM = 'SC9'
			AND D12.%NotDel%
		ORDER BY D12_CARGA, D12_XSEQ, D12_CLIFOR, D12_LOJA
	EndSql
	dbSelectArea(cAliasD12)
	
	While !Eof()
		aadd(aD12Sel, {(cAliasD12)->D12_CARGA, (cAliasD12)->D12_XSEQ, Alltrim(Posicione("SA1", 1, xFilial("SA1")+(cAliasD12)->D12_CLIFOR+(cAliasD12)->D12_LOJA, "A1_NREDUZ")), (cAliasD12)->D12_CLIFOR, (cAliasD12)->D12_LOJA})
		dbSkip()
	End
	
	If Len(aD12Sel) > 0
		VtClear()
		WMSVTCabec("Produtos a Separar", .F., .F., .T.)
		nPos := VTaBrowse(1,,,,{"Carga", "Seq", "Nome", "Codigo", "Loja" },aD12Sel,{06, 03, 30, 12, 04},,nPos)
		If !(VTLastkey() == 27)
			cCarga := aD12Sel[nPos, 1]
			cSeq   := aD12Sel[nPos, 2]
		Else
			lRet := .F.
		EndIf
	Else
		WmsMessage("Nao encontrada carga para separacao","NOCFSEP")
		lRet := .F.
	Endif
	(cAliasD12)->(dbCloseArea())

	RestArea(aArea)

Return(lRet)

//--------------------------------------------------------------------------------------------------------------
Static Function AtuSZ5(cCarga, cSeq, cProduto, cLocal)

	Local aArea     := GetArea()
	Local cAliasZ06 := GetNextAlias()
	Local nQuant    := 0
	
	BeginSql Alias cAliasZ06
		SELECT SUM(Z06_QUANT) Z06_QUANT
		FROM %table:Z06% Z06
		WHERE Z06.Z06_FILIAL = %xFilial:Z06%
			AND Z06_CARGA = %Exp:cCarga%
			AND Z06_SEQ = %Exp:cSeq%
			AND Z06_PRODUT = %Exp:cProduto%
			AND Z06_LOCAL = %Exp:cLocal%
			AND Z06.%NotDel%
	EndSql
	
	If (cAliasZ06)->(!Eof())
		nQuant := (cAliasZ06)->Z06_QUANT
		dbSelectArea("Z05")
		dbSetOrder(1)
		dbSeek(xFilial()+cCarga+cSeq+cProduto+cLocal)
		
		While !Eof() .and. xFilial()+cCarga+cSeq+cProduto+cLocal == Z05->(Z05_FILIAL+Z05_CARGA+Z05_SEQ+Z05_PRODUT+Z05_LOCAL)
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
