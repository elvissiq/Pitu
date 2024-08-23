#INCLUDE "PROTHEUS.CH"
#INCLUDE "APVT100.CH"
#Include 'FWMVCDef.ch'

/*/{Protheus.doc} VTSEPCG
Rotina para realizar a separação por Carga na Expedição
@type function
@version 1.0
@author Elvis Siqueira / Anderson
@since 25/04/2024
/*/
//-------------------------------------------------------------------------------------------------------------------------------------------
User Function VTSEPCG
  Local aTela := {}

  Private cSrvVSP  := SuperGetMv("PC_EXPSRV",.F.,"003")
  Private cSeqCar  := ""
  Private cPedido  := ""
  Private cUnitiza := Space(FWTamSX3("Z06_IDUNIT")[1])
	
  aTela := VtSave()

  VTClear()
  VTPRC01()
  VtRestore(,,,,aTela)
Return

//-------------------------------------------------------------------------------------------------------------------------------------------
Static Function VTPRC01()

	Local lSair       := .F.
	Local cEndder     := PADR(SuperGetMV( 'MV_XENDDES' ,.F.,"PRODUCAO"), FWTamSX3("BE_LOCALIZ")[1]) // Endereço para realizar a separação dos PVs
	Local cCarga      := Space(FWTamSX3("DAK_COD")[1])
	Local cSeq        := Space(FWTamSX3("Z05_SEQ")[1])
	Local aItemPV     := {}
	Local nPos        := 0
	Local nProxLin    := 1
	Local cLoteCtl    := Space(FWTamSX3("B8_LOTECTL")[1])
	Local cProduto    := Space(FWTamSX3("B1_COD")[1])
	Local cCodBar     := Space(250)
	Local cLocal      := Space(FWTamSX3("B1_LOCPAD")[1])
	Local cSeekDCI    := ""
	Local nOrdemFunc  := 0
	Local aFuncoesWMS := {}
	Local lFinal      := .F.
	Local aError      := {}

	// Pesquisa quais funcoes o usuario exerce
	DCD->(dbSetOrder(1)) // DCD_FILIAL+DCD_CODFUN

	If DCD->(dbSeek(FWxFilial("DCD") + __cUserID, .F.))
		If DCD->DCD_STATUS == "3" // Recurso humano ausente
			WmsMessage("Usuário informado como recurso humano ausente.","WMSV00101")

			Return
		EndIf
	Else
		WmsMessage("Usuário não cadastrado como recurso humano.","WMSV00102")

		Return
	EndIf
	
	// Pesquisa quais funcoes o usuario exerce
	DCI->(DbSetOrder(1)) // DCI_FILIAL+DCI_CODFUN+STR(DCI_ORDFUN,2)+DCI_FUNCAO

	If DCI->(dbSeek(cSeekDCI := FWxFilial('DCI') + __cUserID, .F.))
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
		cCarga := Space(FWTamSX3("DAK_COD")[1])

		VTCLear()
		VTClearBuffer()

		nProxLin := 1

		WMSVTCabec("Separacao Carga", .F., .F., .T.)
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

				WMSVTCabec("Carga: " + cCarga + "/" + cSeq,.F.,.F.,.T.)

				nPos := VTaBrowse(1,,,,{"Produto","Descricao","A Separar","Qtd. PV","Separado","Local"},aItemPV,{15,15,10,10,10,03},,nPos)
				
				If VTLastkey() == 27
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
					cCodBar  := Space(250)
					nSaldo   := 0

					VtClear()
					WMSVTCabec("Informe o código de barras", .F., .F., .T.)
					@ nProxLin++,00 VTSay "Endereco: "
					@ nProxLin++,00 VtGet cEndder Pict "@!" Valid ValEnder(cEndder)
					@ nProxLin++,00 VTSay "Produto: "
					@ nProxLin++,00 VtGet cCodBar Pict "@!" Valid ValPrdLot(@cProduto,@cLoteCtl,@nSaldo,@cCodBar, @cLocal, cEndder, aItemPV)
					VTRead()
					
					If VTLastkey() == 27
						Exit
					EndIf
					
					nProxLin := 1
					cDesc    := AllTrim(Posicione("SB1",1,FWxFilial("SB1") + cProduto,"B1_DESC"))
					nQtde    := 0
					
					VtClear()
					
					WMSVTCabec("Informe os dados", .F., .F., .T.)
					@ nProxLin++,00 VTSay PadR("Produto: " + cProduto, VTMaxCol())
					@ nProxLin++,00 VTSay PadR(cDesc, VTMaxCol())
					@ nProxLin++,00 VTSay PadR("Lote: " + cLoteCtl, VTMaxCol())
					@ nProxLin++,00 VTSay IIf(Empty(cUnitiza),cUnitiza,PadR("Unitizador: " + cUnitiza, VTMaxCol()))
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

							WMSVTCabec("Separacao",.F.,.F.,.T.)
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
								dbSelectArea("Z06")
								RecLock("Z06", .T.)
								  Replace Z06_FILIAL with FWxFilial("Z06")
								  Replace Z06_CARGA  with cCarga
								  Replace Z06_SEQ    with cSeq
								  Replace Z06_PRODUT with cProduto
								  Replace Z06_LOCAL  with cLocal
							      Replace Z06_LOTECT with cLoteCtl
								  Replace Z06_ENDER  with cEndder
								  Replace Z06_QUANT  with nQtde
							      Replace Z06_DATA   with dDataBase
								  Replace Z06_HORA   with Time()
								  Replace Z06_CODOPE with __cUserID
								  Replace Z06_PEDIDO with cPedido
								  Replace Z06_SEQCAR with cSeqCar
								  Replace Z06_IDUNIT with cUnitiza
								Z06->(MsUnLock())
								AtuZ05(cCarga, cSeq, cProduto, cLocal)
							Endif
						
						Endif
				
					Endif
					Exit
				End

				VTClearBuffer()
				
				lFinal := u_VerFinSep(cCarga, cSeq)
				
				If lFinal
					aError := {}
					VtClear()
					VtSay(2,0,"Executando Separacao. Aguarde...")
					u_SEPEXP01(cCarga, cSeqCar, cSeq, @aError)
					
					If Empty(aError)
						VtSay(2,0,"Finalizando Separacao. Aguarde...")
						u_FIMEXP01(.F., 2, cCarga, cSeq, @aError)
						If Empty(aError)
							VtSay(2,0,"Montando Volume. Aguarde...")
							u_VOLEXP01(.F., 2, cCarga, cSeq, cPedido, @aError)
						Endif
					Endif
					
					VTClear()
					
					If Empty(aError)
						WMSVTCabec("Separacao", .F., .F., .T.)
						@ 01, 00 VTSay PadR("Finalizada", VTMaxCol())
						@ 02, 00 VTSay "------------------- "
						@ 03, 00 VTSay PadR("Carga.: " + cCarga + "/" + cSeq, VTMaxCol())
						WMSVTRodPe()
					Else
						WMSVTCabec("Problema Separacao",.F.,.F.,.T.)
						@ 01, 00 VTSay PadR("NAO Finalizada", VTMaxCol())
						@ 02, 00 VTSay "------------------- "
						@ 03, 00 VTSay PadR("Ocorreram problemas", VTMaxCol())
						@ 03, 00 VTSay PadR("Carga.: " + cCarga + "/" + cSeq, VTMaxCol())
						WMSVTRodPe()
					Endif
				Endif
			
			Else
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
Local cLocImp   := Space(FWTamSX3("CB5_CODIGO")[01])
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
Static Function VldQuant(cProduto, cLocal, cLoteCtl, cEndder, nQtde, nSaldo)

	Local lRet      := .T.
	Local cNumSerie := Space(FWTamSX3("D14_NUMSER")[1])
	Local cNumLote  := Space(FWTamSX3("D14_NUMLOT")[1])
	Local nSlD14    := 0
	Local nQtSep    := 0
	Local nDisp     := 0

	nSlD14 := WmsSldD14(cLocal,cEndder,cProduto,cNumSerie,cLoteCtl,cNumLote)
	nQtSep := SldZ06(cLocal,cEndder,cProduto,cLoteCtl)
	nDisp := nSlD14 - nQtSep
	
	If lRet .and. QtdComp(nQtde) > QtdComp(nSaldo)
		WmsMessage("Quantidade Informada maior que a Quantidade a Separar","QTSMAIOR")
		lRet := .F.
	Endif
	
	If lRet .and. QtdComp(nDisp) < QtdComp(nQtde)
		WmsMessage("Quantidade Informada maior que o saldo no endereco","NOSLDD14")
		lRet := .F.
	Endif
	
	If !lRet
		nQtde := 0
	Endif

Return(lRet)

//--------------------------------------------------------------------------------------------------------------------------
Static Function ValPrdLot(cProduto, cLoteCtl, nSaldo, cCodBar, cLocal, cEndder, aItemPV)

	Local lRet      := .T.
	Local nPos      := 0
	Local nSlD14    := 0
	Local cNumSerie := Space(FWTamSX3("D14_NUMSER")[01])
	Local cNumLote  := Space(FWTamSX3("D14_NUMLOT")[01])
	Local aCodBar   := Strtokarr(cCodBar, "|")
	Local nQtSep    := 0
	Local nDisp     := 0
	
	If Len(aCodBar) < 2
	   If ! Empty(aCodBar[01])
	      WmsMessage("QrCode informado invalido. ","NPRODCG")
       EndIf

	   lRet := .F.
	 else
	   cProduto := aCodBar[01]
	   nPos     := aScan(aItemPV, {|x| x[1] == cProduto})

   	   If nPos > 0
	      cLoteCtl := aCodBar[08]
		  cUnitiza := aCodBar[12]
		  cLocal   := aItemPV[nPos, 6]
		  nSaldo   := aItemPV[nPos, 3]
		  nSlD14   := WmsSldD14(cLocal,cEndder,cProduto,cNumSerie,cLoteCtl,cNumLote)
		  nQtSep   := SldZ06(cLocal,cEndder,cProduto,cLoteCtl)
		  nDisp    := nSlD14 - nQtSep

		  If nDisp <= 0
		  	 WmsMessage("Sem saldo para o Produto/Lote informado","NPRODCG")
			 lRet := .F.
		  Endif
	    Else
		  WmsMessage("Produto nao encontrado na Pedido","NPRODCG")
		  lRet := .F.
	   EndIf
	EndIf
	
	If ! lRet
	    cCodBar := Space(250)
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
	 WmsMessage("Endereço é obrigatório.","NENDERCG")

	 lRet := .F.
   else
	 dbSelectArea("SBE")
	 SBE->(dbSetOrder(1))

	 If ! SBE->(dbSeek(FWxFilial("SBE") + PadR("07",FWTamSX3("BE_LOCAL")[1]) + PadR(cEndder,FWTamSX3("BE_LOCALIZ")[1])))
	    WMSMessage("Endereço não existe.","NENDERCG")

		lRet := .F.
	 EndIf
  EndIf
Return lRet

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
Static Function BITEMPV(cCarga, cSeq)

	Local aArea     := GetArea()
	Local aZ05Sel   := {}
	Local cAliasZ05 := GetNextAlias()
	
	BeginSql Alias cAliasZ05
		SELECT Z05_PRODUT, Z05_LOCAL, SUM(Z05_QUANT) Z05_QUANT, SUM(Z05_QUJE) Z05_QUJE
		FROM %table:Z05% Z05
		WHERE Z05.Z05_FILIAL = %xFilial:Z05%
			AND Z05.Z05_CARGA = %Exp:cCarga%
			AND Z05.Z05_SEQ = %Exp:cSeq%
			AND Z05.Z05_QUANT > Z05.Z05_QUJE
			AND Z05.%NotDel%
		GROUP BY Z05_PRODUT, Z05_LOCAL
		ORDER BY Z05_PRODUT, Z05_LOCAL
	EndSql
	dbSelectArea(cAliasZ05)
	
	While !Eof()
		aadd(aZ05Sel, {(cAliasZ05)->Z05_PRODUT, Alltrim(Posicione("SB1", 1, xFilial("SB1")+(cAliasZ05)->Z05_PRODUT, "B1_DESC")), (cAliasZ05)->(Z05_QUANT-Z05_QUJE), (cAliasZ05)->Z05_QUANT, (cAliasZ05)->Z05_QUJE, (cAliasZ05)->Z05_LOCAL})
		dbSkip()
	End
	(cAliasZ05)->(dbCloseArea())
	
	RestArea(aArea)

Return(aZ05Sel)

//--------------------------------------------------------------------------------------------------------------------------
Static Function VlDCarga(cCarga, cSeq)

	Local lRet      := .T.
	Local aArea     := GetArea()
	Local aZ05Sel   := {}
	Local cAliasDCF := GetNextAlias()
	Local cAliasZ05 := GetNextAlias()
	Local nPos      := 1
	Local cWhere    := "%"

	If ! Empty(cCarga)
		cWhere += " AND DCF.DCF_CARGA  = '" + cCarga + "'"
		cWhere += " AND DCF.DCF_ORIGEM = 'SC9'"
	Endif

	cWhere += "%"

	BeginSql Alias cAliasDCF
		SELECT DCF.DCF_DOCTO, DCF.DCF_CODPRO, DCF.DCF_LOCAL, DCF.DCF_QUANT, DCF.DCF_ID,
		       DCF.DCF_SERIE, DCF_SEQUEN
		FROM %table:DCF% DCF
		WHERE DCF.DCF_FILIAL = %xFilial:DCF%
			%Exp:cWhere%
			AND DCF.%NotDel%
	EndSql

    dbSelectArea("Z05")
    Z05->(dbSetOrder(1))

	cSeqCar := (cAliasDCF)->DCF_SEQUEN
	cPedido := AllTrim((cAliasDCF)->DCF_DOCTO)
	
	While ! (cAliasDCF)->(Eof())
		If ! Z05->(dbSeek(FWxFilial("Z05") + cCarga +;
		                  Pad((cAliasDCF)->DCF_SEQUEN,FWTamSX3("Z05_SEQCAR")[1]) +;
						  Pad((cAliasDCF)->DCF_DOCTO,FWTamSX3("Z05_PEDIDO")[1]) +;
						  Pad((cAliasDCF)->DCF_SERIE,FWTamSX3("Z05_SEQ")[1]) +;
						  Pad((cAliasDCF)->DCF_CODPRO,FWTamSX3("Z05_PRODUT")[1]) +;
						  Pad((cAliasDCF)->DCF_LOCAL,FWTamSX3("Z05_LOCAL")[1])))
			
			RecLock("Z05",.T.)
				Z05->Z05_FILIAL := xFilial("Z05")
				Z05->Z05_PRODUT := (cAliasDCF)->DCF_CODPRO
				Z05->Z05_LOCAL  := (cAliasDCF)->DCF_LOCAL
				Z05->Z05_QUANT  := (cAliasDCF)->DCF_QUANT
				Z05->Z05_IDDCF  := (cAliasDCF)->DCF_ID
				Z05->Z05_SEQ    := (cAliasDCF)->DCF_SERIE
				Z05->Z05_CARGA  := cCarga
				Z05->Z05_SEQCAR := (cAliasDCF)->DCF_SEQUEN
				Z05->Z05_PEDIDO := (cAliasDCF)->DCF_DOCTO
			Z05->(MsUnLock())
		EndIF 
		
		(cAliasDCF)->(dbSkip())
	End
	(cAliasDCF)->(dbCloseArea())

	cWhere := "%"	

	If ! Empty(cCarga)
		cWhere += " AND Z05.Z05_CARGA = '" + cCarga + "'"
	EndIf

	cWhere += "%"
	
	BeginSql Alias cAliasZ05
		SELECT DISTINCT Z05_CARGA, Z05_SEQ, DAK_CAMINH, DAK_DATA
		FROM %table:Z05% Z05, %table:DAK% DAK
		WHERE Z05.Z05_FILIAL = %xFilial:Z05%
			AND Z05.Z05_QUANT > Z05.Z05_QUJE
			AND Z05.%NotDel%
			AND DAK.DAK_FILIAL = %xFilial:DAK%
			AND DAK.DAK_COD = Z05.Z05_CARGA
			AND DAK_FEZNF <> '1'
			AND DAK.%NotDel%
			%Exp:cWhere%
		ORDER BY Z05_CARGA, Z05_SEQ
	EndSql
	TcSetField(cAliasZ05,'DAK_DATA','D',8,0)
	dbSelectArea(cAliasZ05)
	
	While !(cAliasZ05)->(Eof())
		aAdd(aZ05Sel, {(cAliasZ05)->Z05_CARGA, (cAliasZ05)->Z05_SEQ, (cAliasZ05)->DAK_CAMINH, Dtoc((cAliasZ05)->DAK_DATA)})
		
		(cAliasZ05)->(dbSkip())
	End
	
	If Len(aZ05Sel) > 0
		If Len(aZ05Sel) > 1
			VtClear()
			WMSVTCabec("Selecione Carga", .F., .F., .T.)
			nPos := VTaBrowse(1,,,,{"Carga", "Seq", "Placa", "Dt.Emissao"},aZ05Sel,{06, 03, 08, 08},,nPos)
			If !(VTLastkey() == 27)
				cCarga := aZ05Sel[nPos, 1]
				cSeq   := aZ05Sel[nPos, 2]
			Else
				lRet := .F.
			EndIf
		Else
			cCarga := aZ05Sel[1, 1]
			cSeq   := aZ05Sel[1, 2]
		Endif
	Else
		WmsMessage("Nao encontrada carga para separacao","NOCFSEP")
		lRet := .F.
	Endif
	(cAliasZ05)->(dbCloseArea())

	RestArea(aArea)
Return(lRet)

//--------------------------------------------------------------------------------------------------------------
Static Function AtuZ05(cCarga, cSeq, cProduto, cLocal)

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
	
	If ! (cAliasZ06)->(Eof())
		nQuant := (cAliasZ06)->Z06_QUANT
		dbSelectArea("Z05")
		Z05->(dbSetOrder(1))
		Z05->(dbSeek(FWxFilial("Z05") + cCarga + PadR(cSeqCar,FWTamSX3("Z05_SEQCAR")[1]) +;
		             cPedido + cSeq + cProduto + cLocal))
		
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
